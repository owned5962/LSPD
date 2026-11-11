local playerInventories = {}
local transferLocks = {}
local inventoryCharacterIds = {}

local DEFAULT_INVENTORY = {
    { name = 'id_card', count = 1 },
    { name = 'driver_license', count = 1 },
    { name = 'phone', count = 1 },
    { name = 'bread', count = 2 },
    { name = 'burger_bleeder', count = 2 },
    { name = 'water', count = 3 },
    { name = 'soda_ecola', count = 2 },
    { name = 'coffee', count = 1 }
}

local function notify(src, kind, message)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function normalizeInventory(raw)
    local normalized = {}
    if type(raw) ~= 'table' then return normalized end
    for _, saved in ipairs(raw) do
        local name = type(saved) == 'table' and saved.name
        local count = type(saved) == 'table' and tonumber(saved.count)
        local definition = name and Config.DefaultItems[name]
        if definition and count and count % 1 == 0 and count > 0 and count <= 10000 then
            normalized[#normalized + 1] = {
                name = name, count = count,
                label = definition.label, weight = definition.weight
            }
        end
    end
    return normalized
end

local function saveInventory(player)
    if not player or not player.charId or not playerInventories[player.source] then return false end
    local ok, err = pcall(function()
        MySQL.update.await([[
            INSERT INTO player_inventories (character_id, items)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE items = VALUES(items)
        ]], { player.charId, json.encode(playerInventories[player.source]) })
    end)
    if not ok then
        print(('[rp_inventory] Save failed for character %s: %s'):format(player.charId, tostring(err)))
        return false
    end
    return true
end

local function getInventoryWeight(inventory)
    local weight = 0.0
    for _, item in ipairs(inventory) do
        weight = weight + (item.weight * item.count)
    end
    return weight
end

local function sendInventory(src, player)
    local inventory = playerInventories[src]
    if not inventory then return end
    TriggerClientEvent('rp_inventory:receiveData', src, {
        inventory = inventory,
        currentWeight = getInventoryWeight(inventory),
        cash = player.cash or 0,
        bank = player.bank or 0
    })
end

local function loadInventory(player)
    local row = MySQL.single.await('SELECT items FROM player_inventories WHERE character_id = ?', { player.charId })
    if row and row.items then
        local ok, decoded = pcall(json.decode, row.items)
        if ok then
            playerInventories[player.source] = normalizeInventory(decoded)
            inventoryCharacterIds[player.source] = player.charId
            return
        end
        print(('[rp_inventory] Invalid saved inventory for character %s; restoring defaults'):format(player.charId))
    end

    playerInventories[player.source] = normalizeInventory(DEFAULT_INVENTORY)
    inventoryCharacterIds[player.source] = player.charId
    saveInventory(player)
end

RegisterNetEvent('rp_inventory:requestData', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:request_data', 2000) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then return end
    if not playerInventories[src] then
        local ok, err = pcall(loadInventory, player)
        if not ok then
            print(('[rp_inventory] Load failed for character %s: %s'):format(player.charId, tostring(err)))
            notify(src, 'error', 'Impossible de charger votre inventaire. Réessayez plus tard.')
            return
        end
    end
    sendInventory(src, player)
end)

RegisterNetEvent('rp_inventory:useItem', function(itemName)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:use_item', 1000) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local inventory = playerInventories[src]
    if not player or not inventory or type(itemName) ~= 'string' then return end
    if transferLocks[src] then
        notify(src, 'error', 'Un transfert est en cours. Réessayez.')
        return
    end

    local itemDef = Config.DefaultItems[itemName]
    if not itemDef or (itemDef.type ~= 'food' and itemDef.type ~= 'drink' and itemDef.type ~= 'medical') then
        notify(src, 'error', 'Cet objet ne peut pas être utilisé.')
        return
    end

    local itemIndex
    for index, item in ipairs(inventory) do
        if item.name == itemName and item.count > 0 then itemIndex = index break end
    end
    if not itemIndex then
        notify(src, 'error', 'Cet objet n’est pas dans votre inventaire.')
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 or IsEntityDead(ped) then
        notify(src, 'error', 'Vous ne pouvez pas utiliser cet objet dans cet état.')
        return
    end
    if itemDef.type == 'medical' then
        local currentHealth, maxHealth = GetEntityHealth(ped), GetEntityMaxHealth(ped)
        if not itemDef.heal or currentHealth >= maxHealth then
            notify(src, 'error', 'Vous n’avez pas besoin de soins.')
            return
        end
    end

    local metadata = {}
    for key, value in pairs(player.metadata or {}) do metadata[key] = value end
    metadata.hunger = math.max(0, math.min(100, tonumber(metadata.hunger) or 100))
    metadata.thirst = math.max(0, math.min(100, tonumber(metadata.thirst) or 100))
    if itemDef.hunger then metadata.hunger = math.min(100, metadata.hunger + itemDef.hunger) end
    if itemDef.thirst then metadata.thirst = math.min(100, metadata.thirst + itemDef.thirst) end
    if itemDef.type ~= 'medical' and metadata.hunger == (player.metadata.hunger or 100)
        and metadata.thirst == (player.metadata.thirst or 100) then
        notify(src, 'error', 'Votre faim ou votre soif est déjà satisfaite.')
        return
    end

    local updatedInventory = normalizeInventory(inventory)
    local updatedIndex
    for index, item in ipairs(updatedInventory) do
        if item.name == itemName then updatedIndex = index break end
    end
    if not updatedIndex then return end
    if updatedInventory[updatedIndex].count <= 1 then
        table.remove(updatedInventory, updatedIndex)
    else
        updatedInventory[updatedIndex].count = updatedInventory[updatedIndex].count - 1
    end

    if not exports['rp_core']:AcquireCharacterLock({ player.charId }) then
        notify(src, 'error', 'Une sauvegarde de votre personnage est en cours. Réessayez.')
        return
    end
    transferLocks[src] = true
    local persisted, persistError = pcall(function()
        local ok = MySQL.transaction.await({
            {
                query = 'UPDATE player_inventories SET items = ? WHERE character_id = ?',
                values = { json.encode(updatedInventory), player.charId }
            },
            {
                query = 'UPDATE characters SET metadata = ? WHERE id = ? AND identifier = ?',
                values = { json.encode(metadata), player.charId, player.identifier }
            }
        })
        if not ok then error('Item use transaction rejected') end
    end)
    transferLocks[src] = nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId })
    if not persisted then
        print(('[rp_inventory] Item use failed for character %s: %s'):format(player.charId, tostring(persistError)))
        notify(src, 'error', 'Impossible d’utiliser cet objet : sauvegarde indisponible.')
        return
    end

    playerInventories[src] = updatedInventory
    player.metadata = metadata
    TriggerClientEvent('rp_core:client:updateNeeds', src, metadata.hunger, metadata.thirst)
    if itemDef.type == 'medical' then
        TriggerClientEvent('rp_inventory:applyMedicalItem', src, itemDef.heal)
    end
    sendInventory(src, player)
    notify(src, 'success', itemDef.label .. ' utilisé.')
end)

RegisterNetEvent('rp_inventory:giveItem', function(rawTargetId, itemName, rawCount)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:give_item', 1500) then return end
    local targetId, count = tonumber(rawTargetId), tonumber(rawCount)
    local player = exports['rp_core']:GetPlayerFromId(src)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)
    if not player or not target or targetId == src or type(itemName) ~= 'string'
        or not count or count % 1 ~= 0 or count < 1 or count > 100 then return end
    local definition = Config.DefaultItems[itemName]
    if not playerInventories[targetId] then
        local ok, err = pcall(loadInventory, target)
        if not ok then
            print(('[rp_inventory] Target load failed for character %s: %s'):format(target.charId, tostring(err)))
            notify(src, 'error', 'Impossible de charger l’inventaire du destinataire.')
            return
        end
    end
    local sourceInventory, targetInventory = playerInventories[src], playerInventories[targetId]
    if not definition or not sourceInventory or not targetInventory then
        notify(src, 'error', 'Inventaire indisponible ou objet invalide.')
        return
    end
    local sourceIndex, sourceItem
    for index, item in ipairs(sourceInventory) do
        if item.name == itemName then sourceIndex, sourceItem = index, item break end
    end
    if not sourceItem or sourceItem.count < count then
        notify(src, 'error', 'Quantité insuffisante.')
        return
    end
    local sourcePed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if sourcePed == 0 or targetPed == 0 or #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) > 3.0 then
        notify(src, 'error', 'Le joueur est trop éloigné.')
        return
    end
    if getInventoryWeight(targetInventory) + definition.weight * count > Config.MaxWeight then
        notify(src, 'error', 'Le joueur ne peut pas porter cette charge.')
        return
    end

    if transferLocks[src] or transferLocks[targetId] then
        notify(src, 'error', 'Un transfert est déjà en cours.')
        return
    end
    transferLocks[src], transferLocks[targetId] = true, true

    local sourceNew = normalizeInventory(sourceInventory)
    local targetNew = normalizeInventory(targetInventory)
    local newSourceItem
    for index, item in ipairs(sourceNew) do
        if item.name == itemName then newSourceItem = item; if item.count <= count then table.remove(sourceNew, index) else item.count = item.count - count end; break end
    end
    local existing
    for _, item in ipairs(targetNew) do if item.name == itemName then existing = item break end end
    if existing then existing.count = existing.count + count
    else targetNew[#targetNew + 1] = { name = itemName, count = count, label = definition.label, weight = definition.weight } end

    local persisted, persistError = pcall(function()
        -- Ensure both rows exist before the atomic two-row update.
        if not saveInventory(player) or not saveInventory(target) then
            error('Unable to prepare inventory rows')
        end
        local ok = MySQL.transaction.await({
            {
                query = 'UPDATE player_inventories SET items = ? WHERE character_id = ?',
                values = { json.encode(sourceNew), player.charId }
            },
            {
                query = 'UPDATE player_inventories SET items = ? WHERE character_id = ?',
                values = { json.encode(targetNew), target.charId }
            }
        })
        if not ok then error('Inventory transaction rejected') end
    end)
    transferLocks[src], transferLocks[targetId] = nil, nil
    if not persisted then
        print(('[rp_inventory] Atomic transfer failed (%s -> %s): %s'):format(player.charId, target.charId, tostring(persistError)))
        notify(src, 'error', 'Le transfert a échoué. Aucun objet n’a été transféré.')
        return
    end

    playerInventories[src], playerInventories[targetId] = sourceNew, targetNew
    notify(src, 'success', 'Objet transféré.')
    notify(targetId, 'success', 'Vous avez reçu ' .. count .. ' x ' .. definition.label .. '.')
    sendInventory(src, player)
    sendInventory(targetId, target)
end)

RegisterNetEvent('rp_inventory:dropItem', function(itemName, rawCount)
    local src = source
    local count = tonumber(rawCount)
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or not playerInventories[src] or type(itemName) ~= 'string' or not count or count % 1 ~= 0 or count < 1 or count > 100 then return end
    -- Ground drops are deliberately rejected until a server-owned pickup entity flow is installed.
    notify(src, 'error', 'Le dépôt au sol est temporairement désactivé.')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    local charId = inventoryCharacterIds[src]
    if charId and playerInventories[src] then
        local ok, err = pcall(MySQL.update.await,
            'INSERT INTO player_inventories (character_id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
            { charId, json.encode(playerInventories[src]) }
        )
        if not ok then print(('[rp_inventory] Disconnect save failed for character %s: %s'):format(charId, tostring(err))) end
    end
    playerInventories[src] = nil
    inventoryCharacterIds[src] = nil
    transferLocks[src] = nil
end)


-- Server-only inventory grant API for trusted gameplay resources (e.g. vehicle salvage).
local function AddItem(source, itemName, rawCount)
    local src = tonumber(source)
    local count = tonumber(rawCount)
    local player = src and exports['rp_core']:GetPlayerFromId(src)
    if not player or type(itemName) ~= 'string' or not count or count % 1 ~= 0 or count < 1 or count > 20 then return false end
    local definition = Config.DefaultItems[itemName]
    if not definition then return false end
    if not playerInventories[src] then
        local ok = pcall(loadInventory, player)
        if not ok then return false end
    end
    local current = normalizeInventory(playerInventories[src])
    if getInventoryWeight(current) + definition.weight * count > Config.MaxWeight then
        notify(src, 'error', 'Inventaire trop lourd : le butin a été laissé sur place.')
        return false
    end
    local found = false
    for _, item in ipairs(current) do
        if item.name == itemName then item.count = item.count + count; found = true; break end
    end
    if not found then current[#current + 1] = { name = itemName, count = count, label = definition.label, weight = definition.weight } end
    local ok = pcall(function()
        MySQL.insert.await('INSERT INTO player_inventories (character_id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
            { player.charId, json.encode(current) })
    end)
    if not ok then return false end
    playerInventories[src] = current
    sendInventory(src, player)
    return true
end

exports('AddItem', AddItem)


-- Trusted staff API for the creator tablet. The caller must authorize the staff role
-- before invoking this export; item names and quantities are validated here as well.
local function AdminSetItem(source, itemName, operation, rawCount)
    local src, count = tonumber(source), tonumber(rawCount)
    local player = src and exports['rp_core']:GetPlayerFromId(src)
    if not player or type(itemName) ~= 'string' or not Config.DefaultItems[itemName]
        or (operation ~= 'add' and operation ~= 'remove')
        or not count or count % 1 ~= 0 or count < 1 or count > 1000 then
        return false
    end

    if not playerInventories[src] then
        local ok = pcall(loadInventory, player)
        if not ok then return false end
    end

    local inventory = normalizeInventory(playerInventories[src])
    local definition = Config.DefaultItems[itemName]
    local foundIndex, currentCount
    for index, item in ipairs(inventory) do
        if item.name == itemName then foundIndex, currentCount = index, item.count; break end
    end
    currentCount = currentCount or 0
    local nextCount = operation == 'add' and (currentCount + count) or (currentCount - count)
    if nextCount < 0 or nextCount > 10000 then return false end

    if nextCount == 0 then
        if foundIndex then table.remove(inventory, foundIndex) end
    elseif foundIndex then
        inventory[foundIndex].count = nextCount
    else
        inventory[#inventory + 1] = { name = itemName, count = nextCount, label = definition.label, weight = definition.weight }
    end

    if getInventoryWeight(inventory) > Config.MaxWeight then return false end
    local ok, err = pcall(function()
        MySQL.update.await(
            'INSERT INTO player_inventories (character_id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
            { player.charId, json.encode(inventory) }
        )
    end)
    if not ok then
        print(('[rp_inventory] Admin inventory update failed for character %s: %s'):format(player.charId, tostring(err)))
        return false
    end

    playerInventories[src] = inventory
    sendInventory(src, player)
    notify(src, 'success', ('Inventaire modifié : %s x%d.'):format(definition.label, count))
    return true
end

local function GetItemCatalog()
    local catalog = {}
    for name, definition in pairs(Config.DefaultItems) do
        catalog[#catalog + 1] = {
            name = name,
            label = definition.label or name,
            weight = tonumber(definition.weight) or 0
        }
    end
    table.sort(catalog, function(a, b) return a.label < b.label end)
    return catalog
end

exports('AdminSetItem', AdminSetItem)
exports('GetItemCatalog', GetItemCatalog)
