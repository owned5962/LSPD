local playerInventories = {}
local transferLocks = {}

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
            return
        end
        print(('[rp_inventory] Invalid saved inventory for character %s; restoring defaults'):format(player.charId))
    end

    playerInventories[player.source] = normalizeInventory(DEFAULT_INVENTORY)
    saveInventory(player)
end

RegisterNetEvent('rp_inventory:requestData', function()
    local src = source
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
    local player = exports['rp_core']:GetPlayerFromId(src)
    local inventory = playerInventories[src]
    if not player or not inventory or type(itemName) ~= 'string' then return end

    local itemDef = Config.DefaultItems[itemName]
    if not itemDef then return end
    for index, item in ipairs(inventory) do
        if item.name == itemName and item.count > 0 then
            if item.count > 1 then item.count = item.count - 1 else table.remove(inventory, index) end
            saveInventory(player)
            if itemDef.type == 'food' then
                notify(src, 'success', ('Vous mangez : %s (+%d faim)'):format(itemDef.label, itemDef.hunger or 20))
            elseif itemDef.type == 'drink' then
                notify(src, 'success', ('Vous buvez : %s (+%d soif)'):format(itemDef.label, itemDef.thirst or 25))
            elseif itemDef.type == 'medical' then
                notify(src, 'success', ('Vous utilisez : %s (+%d PV)'):format(itemDef.label, itemDef.heal or 50))
            else
                notify(src, 'info', 'Objet utilisé : ' .. itemDef.label)
            end
            sendInventory(src, player)
            return
        end
    end
    notify(src, 'error', 'Cet objet n’est pas dans votre inventaire.')
end)

RegisterNetEvent('rp_inventory:giveItem', function(rawTargetId, itemName, rawCount)
    local src = source
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
    if not player or type(itemName) ~= 'string' or not count or count % 1 ~= 0 or count < 1 or count > 100 then return end
    -- Ground drops are deliberately rejected until a server-owned pickup entity flow is installed.
    notify(src, 'error', 'Le dépôt au sol est temporairement désactivé.')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if player then saveInventory(player) end
    playerInventories[src] = nil
end)
