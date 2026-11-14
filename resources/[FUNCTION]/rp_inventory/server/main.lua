local playerInventories = {}
local transferLocks = {}
local inventoryCharacterIds = {}
local inventoryLoadLocks = {}

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

local function sendInventory(src, player, open)
    local inventory = playerInventories[src]
    if not inventory then return end
    local payload = {
        inventory = inventory,
        currentWeight = getInventoryWeight(inventory),
        cash = player.cash or 0,
        bank = player.bank or 0
    }
    if open then
        TriggerClientEvent('rp_inventory:receiveData', src, payload)
    else
        TriggerClientEvent('rp_inventory:updateData', src, payload)
    end
end

local function loadInventory(player)
    if not player or not tonumber(player.source) or not tonumber(player.charId) then
        error('Cannot load inventory without a registered character')
    end

    local src, charId = tonumber(player.source), tonumber(player.charId)
    if playerInventories[src] and inventoryCharacterIds[src] == charId then return true end

    while inventoryLoadLocks[src] do
        local activePlayer = exports['rp_core']:GetPlayerFromId(src)
        if not activePlayer or tonumber(activePlayer.charId) ~= charId then
            error('Character changed or disconnected while inventory was loading')
        end
        if playerInventories[src] and inventoryCharacterIds[src] == charId then return true end
        Wait(50)
    end

    inventoryLoadLocks[src] = charId
    local ok, err = pcall(function()
        local row = MySQL.single.await(
            'SELECT items FROM player_inventories WHERE character_id = ?', { charId })
        local inventory
        local restoredSavedInventory = false

        if row and row.items then
            local decodedOk, decoded = pcall(json.decode, row.items)
            if decodedOk and type(decoded) == 'table' then
                inventory = normalizeInventory(decoded)
                restoredSavedInventory = true
            else
                print(('[rp_inventory] Invalid saved inventory for character %s; restoring defaults')
                    :format(charId))
            end
        end

        inventory = inventory or normalizeInventory(DEFAULT_INVENTORY)
        local activePlayer = exports['rp_core']:GetPlayerFromId(src)
        if not activePlayer or tonumber(activePlayer.charId) ~= charId then
            error('Character changed or disconnected before inventory load completed')
        end

        playerInventories[src] = inventory
        inventoryCharacterIds[src] = charId
        if not restoredSavedInventory then
            if not saveInventory(activePlayer) then
                playerInventories[src] = nil
                inventoryCharacterIds[src] = nil
                error('Default inventory could not be persisted')
            end
        end
    end)
    if inventoryLoadLocks[src] == charId then inventoryLoadLocks[src] = nil end
    if not ok then error(err) end
    return true
end

-- Trusted server-side snapshot API for anticheat/admin tools.
-- Returns a detached copy so callers cannot mutate the live inventory cache.
local function GetPlayerInventory(source)
    local src = tonumber(source)
    if not src then return nil end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then return nil end

    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok, err = pcall(loadInventory, player)
        if not ok then
            print(('[rp_inventory] Snapshot load failed for character %s: %s'):format(player.charId, tostring(err)))
            return nil
        end
    end

    local snapshot = {}
    for _, item in ipairs(normalizeInventory(playerInventories[src])) do
        snapshot[#snapshot + 1] = {
            name = item.name,
            label = item.label or item.name,
            count = item.count,
            weight = item.weight
        }
    end
    return snapshot
end

exports('GetPlayerInventory', GetPlayerInventory)

-- Warm the inventory cache as soon as rp_core publishes a fully loaded character.
-- This removes the first-open race and gives every gameplay resource one consistent
-- character-keyed inventory snapshot.
local function WarmPlayerInventory(source, player)
    local src = tonumber(source)
    if not src or not player or tonumber(player.source) ~= src or not tonumber(player.charId) then return end
    CreateThread(function()
        local ok, err = pcall(loadInventory, player)
        if not ok then
            print(('[rp_inventory] Preload failed for character %s: %s')
                :format(tostring(player.charId), tostring(err)))
        end
    end)
end

AddEventHandler('rp_core:server:playerLoaded', WarmPlayerInventory)

AddEventHandler('rp_core:server:playerUnloaded', function(source, player)
    local src = tonumber(source)
    if not src then return end
    if player and playerInventories[src] and inventoryCharacterIds[src] == tonumber(player.charId) then
        if not saveInventory(player) then
            print(('[rp_inventory] Unload save failed for character %s.')
                :format(tostring(player.charId)))
        end
    end
    playerInventories[src] = nil
    inventoryCharacterIds[src] = nil
    inventoryLoadLocks[src] = nil
    transferLocks[src] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(0)
        local ok, players = pcall(function() return exports['rp_core']:GetAllPlayers() end)
        if not ok or type(players) ~= 'table' then return end
        for src, player in pairs(players) do
            WarmPlayerInventory(src, player)
        end
    end)
end)

-- Commande chat serveur : /openinventory (alias /inv).
-- Elle déclenche le toggle sur le client concerné, sans dépendre de l'exécution
-- des commandes locales par le chat.
local function OpenInventoryCommand(src)
    if src and src > 0 then
        TriggerClientEvent('rp_inventory:client:toggle', src)
    end
end

RegisterCommand('openinventory', OpenInventoryCommand, false)
RegisterCommand('inv', OpenInventoryCommand, false)

RegisterNetEvent('rp_inventory:requestData', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:request_data', 1000) then
        TriggerClientEvent('rp_inventory:requestFailed', src, 'Patientez un instant avant de rouvrir votre inventaire.')
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then
        TriggerClientEvent('rp_inventory:requestFailed', src, 'Votre personnage n’est pas encore chargé. Réessayez après être entré en ville.')
        return
    end
    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok, err = pcall(loadInventory, player)
        if not ok then
            print(('[rp_inventory] Load failed for character %s: %s'):format(player.charId, tostring(err)))
            notify(src, 'error', 'Impossible de charger votre inventaire. Réessayez plus tard.')
            TriggerClientEvent('rp_inventory:requestFailed', src, 'Le chargement de l’inventaire a échoué. Consultez la console serveur.')
            return
        end
    end
    sendInventory(src, player, true)
end)

local WEAPON_ITEM_PATTERN = [[^WEAPON_[A-Z0-9_]+$]]

local function useWeaponItem(src, player, inventory, itemName, itemDef)
    local weaponName = tostring(itemDef.weapon or '')
    if not weaponName:match(WEAPON_ITEM_PATTERN) then
        notify(src, 'error', 'Définition d’arme invalide.')
        return
    end
    local allowedOk, allowed = pcall(function()
        return exports['rp_anticheat']:IsWeaponAllowed(weaponName)
    end)
    if not allowedOk or allowed ~= true then
        notify(src, 'error', 'Cette arme est désactivée par la politique du serveur.')
        return
    end
    local itemCount = 0
    for _, entry in ipairs(inventory) do
        if entry.name == itemName then itemCount = tonumber(entry.count) or 0; break end
    end
    if itemCount < 1 then notify(src, 'error', 'Cette arme n’est pas dans votre inventaire.'); return end
    local ped = GetPlayerPed(src)
    if ped == 0 or IsEntityDead(ped) then
        notify(src, 'error', 'Vous ne pouvez pas équiper une arme dans cet état.')
        return
    end
    local metadata = {}
    for key, value in pairs(player.metadata or {}) do metadata[key] = value end
    metadata.weapons = type(metadata.weapons) == 'table' and metadata.weapons or {}
    for _, entry in ipairs(metadata.weapons) do
        if type(entry) == 'table' and entry.name == weaponName then
            notify(src, 'error', 'Vous possédez déjà cette arme.')
            return
        end
    end
    local ammo = weaponName == 'WEAPON_SMG' and 30 or 0
    metadata.weapons[#metadata.weapons + 1] = { name = weaponName, ammo = ammo }
    local updatedInventory = normalizeInventory(inventory)
    for index, entry in ipairs(updatedInventory) do
        if entry.name == itemName then
            if entry.count <= 1 then table.remove(updatedInventory, index)
            else entry.count = entry.count - 1 end
            break
        end
    end
    if not exports['rp_core']:AcquireCharacterLock({ player.charId }) then
        notify(src, 'error', 'Une sauvegarde de votre personnage est en cours. Réessayez.')
        return
    end
    transferLocks[src] = true
    local persisted, persistError = pcall(function()
        local ok = MySQL.transaction.await({
            { query = 'INSERT INTO player_inventories (character_id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)', values = { player.charId, json.encode(updatedInventory) } },
            { query = 'UPDATE characters SET metadata = ? WHERE id = ? AND identifier = ?', values = { json.encode(metadata), player.charId, player.identifier } }
        })
        if not ok then error('Weapon item transaction rejected') end
    end)
    transferLocks[src] = nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId })
    if not persisted then
        print(('[rp_inventory] Weapon item use failed for character %s: %s'):format(player.charId, tostring(persistError)))
        notify(src, 'error', 'Impossible d’équiper cette arme : sauvegarde indisponible.')
        return
    end
    playerInventories[src] = updatedInventory
    player.metadata = metadata
    TriggerClientEvent('rp_inventory:client:giveWeapon', src, weaponName, ammo)
    sendInventory(src, player)
    notify(src, 'success', itemDef.label .. ' équipé et sauvegardé.')
end
RegisterNetEvent('rp_inventory:useItem', function(itemName)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:use_item', 1000) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then return end
    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok = pcall(loadInventory, player)
        if not ok then notify(src, 'error', 'Impossible de charger votre inventaire.'); return end
    end
    local inventory = playerInventories[src]
    if not inventory or type(itemName) ~= 'string' then return end
    if transferLocks[src] then
        notify(src, 'error', 'Un transfert est en cours. Réessayez.')
        return
    end

    local itemDef = Config.DefaultItems[itemName]
    if itemDef and itemDef.type == 'weapon' then
        useWeaponItem(src, player, inventory, itemName, itemDef)
        return
    end
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
                query = [[
                    INSERT INTO player_inventories (character_id, items) VALUES (?, ?)
                    ON DUPLICATE KEY UPDATE items = VALUES(items)
                ]],
                values = { player.charId, json.encode(updatedInventory) }
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
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId) then
        notify(src, 'error', 'Ce joueur n’est pas dans votre instance.')
        return
    end

    local function ensureInventory(targetSource, targetPlayer)
        if not playerInventories[targetSource] or inventoryCharacterIds[targetSource] ~= targetPlayer.charId then
            local ok, err = pcall(loadInventory, targetPlayer)
            if not ok then
                print(('[rp_inventory] Load failed for character %s: %s'):format(targetPlayer.charId, tostring(err)))
                return false
            end
        end
        return true
    end
    if not ensureInventory(src, player) or not ensureInventory(targetId, target) then
        notify(src, 'error', 'Impossible de charger un des inventaires.')
        return
    end

    local definition = Config.DefaultItems[itemName]
    local sourceInventory, targetInventory = playerInventories[src], playerInventories[targetId]
    if not definition or not sourceInventory or not targetInventory then
        notify(src, 'error', 'Inventaire indisponible ou objet invalide.')
        return
    end

    local sourceItem
    for _, item in ipairs(sourceInventory) do
        if item.name == itemName then sourceItem = item break end
    end
    if not sourceItem or sourceItem.count < count then
        notify(src, 'error', 'Quantité insuffisante.')
        return
    end

    local sourcePed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if sourcePed == 0 or targetPed == 0
        or #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) > 3.0 then
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
    if not exports['rp_core']:AcquireCharacterLock({ player.charId, target.charId }) then
        notify(src, 'error', 'Une sauvegarde est en cours. Réessayez.')
        return
    end

    transferLocks[src], transferLocks[targetId] = true, true
    local sourceNew = normalizeInventory(sourceInventory)
    local targetNew = normalizeInventory(targetInventory)
    for index, item in ipairs(sourceNew) do
        if item.name == itemName then
            if item.count <= count then table.remove(sourceNew, index)
            else item.count = item.count - count end
            break
        end
    end
    local existing
    for _, item in ipairs(targetNew) do
        if item.name == itemName then existing = item break end
    end
    if existing then existing.count = existing.count + count
    else
        targetNew[#targetNew + 1] = {
            name = itemName, count = count, label = definition.label, weight = definition.weight
        }
    end

    local persisted, persistError = pcall(function()
        local ok = MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO player_inventories (character_id, items) VALUES (?, ?)
                    ON DUPLICATE KEY UPDATE items = VALUES(items)
                ]],
                values = { player.charId, json.encode(sourceNew) }
            },
            {
                query = [[
                    INSERT INTO player_inventories (character_id, items) VALUES (?, ?)
                    ON DUPLICATE KEY UPDATE items = VALUES(items)
                ]],
                values = { target.charId, json.encode(targetNew) }
            }
        })
        if not ok then error('Inventory transfer transaction rejected') end
    end)

    transferLocks[src], transferLocks[targetId] = nil, nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId, target.charId })
    if not persisted then
        print(('[rp_inventory] Atomic transfer failed (%s -> %s): %s'):format(player.charId, target.charId, tostring(persistError)))
        notify(src, 'error', 'Le transfert a échoué. Aucun objet n’a été transféré.')
        return
    end

    playerInventories[src], playerInventories[targetId] = sourceNew, targetNew
    notify(src, 'success', ('Vous avez donné %dx %s.'):format(count, definition.label))
    notify(targetId, 'success', ('Vous avez reçu %dx %s.'):format(count, definition.label))
    sendInventory(src, player)
    sendInventory(targetId, target)
end)

-- Les objets au sol sont des entités réseau créées et contrôlées par le serveur.
local groundDrops = {}
local dropLocks = {}
local nextDropId = 0
local DROP_MODEL = GetHashKey('prop_cs_cardbox_01')

local function buildDropSnapshot(bucket)
    local snapshot = {}
    for id, drop in pairs(groundDrops) do
        if drop.bucket == bucket then
            snapshot[#snapshot + 1] = {
                id = id, x = drop.x, y = drop.y, z = drop.z,
                label = drop.label, count = drop.count
            }
        end
    end
    return snapshot
end

local function syncDrops(target)
    if target then
        TriggerClientEvent('rp_inventory:client:syncDrops', target,
            buildDropSnapshot(GetPlayerRoutingBucket(target)))
        return
    end
    for _, rawSource in ipairs(GetPlayers()) do
        local targetId = tonumber(rawSource)
        TriggerClientEvent('rp_inventory:client:syncDrops', targetId,
            buildDropSnapshot(GetPlayerRoutingBucket(targetId)))
    end
end

local function spawnSavedDrop(row)
    local id = tostring(row.id)
    local object = CreateObjectNoOffset(DROP_MODEL, tonumber(row.x), tonumber(row.y), tonumber(row.z), true, true, false)
    if not object or object == 0 or not DoesEntityExist(object) then
        print(('[rp_inventory] Could not recreate ground drop %s; database row retained for retry.'):format(id))
        return false
    end
    SetEntityHeading(object, tonumber(row.heading) or 0.0)
    FreezeEntityPosition(object, true)
    local definition = Config.DefaultItems[row.item_name]
    if not definition then
        DeleteEntity(object)
        print(('[rp_inventory] Unknown item %s in ground drop %s; row retained.'):format(tostring(row.item_name), id))
        return false
    end
    groundDrops[id] = {
        entity = object,
        x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z),
        heading = tonumber(row.heading) or 0.0,
        label = definition.label, count = tonumber(row.count),
        itemName = row.item_name, bucket = tonumber(row.routing_bucket) or 0
    }
    return true
end

CreateThread(function()
    Wait(1000)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT id, item_name, count, x, y, z, heading, routing_bucket FROM player_inventory_drops')
    if not ok then
        print(('[rp_inventory] Ground drop restoration failed: %s'):format(tostring(rows)))
        return
    end
    for index, row in ipairs(rows or {}) do
        spawnSavedDrop(row)
        -- Yield periodically so a large persisted drop list cannot monopolize
        -- the server thread during resource startup.
        if index % 15 == 0 then Wait(0) end
    end
    syncDrops()
end)

RegisterNetEvent('rp_inventory:server:requestDrops', function()
    syncDrops(source)
end)

RegisterNetEvent('rp_inventory:dropItem', function(itemName, rawCount)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:drop_item', 1000) then return end

    local count = tonumber(rawCount)
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or type(itemName) ~= 'string' or not count
        or count % 1 ~= 0 or count < 1 or count > 100 then return end
    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok, err = pcall(loadInventory, player)
        if not ok then
            print(('[rp_inventory] Drop inventory load failed for %s: %s'):format(player.charId, tostring(err)))
            notify(src, 'error', 'Impossible de charger votre inventaire.')
            return
        end
    end

    local definition = Config.DefaultItems[itemName]
    local inventory = playerInventories[src]
    local itemIndex, item
    for i, entry in ipairs(inventory or {}) do
        if entry.name == itemName then itemIndex, item = i, entry break end
    end
    if not definition or not item or item.count < count then
        notify(src, 'error', 'Vous ne possédez pas cette quantité.')
        return
    end
    if transferLocks[src] then
        notify(src, 'error', 'Une opération est déjà en cours.')
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local dropX, dropY, dropZ = coords.x + forward.x * 0.8, coords.y + forward.y * 0.8, coords.z - 0.85
    local heading = GetEntityHeading(ped)
    local object = CreateObjectNoOffset(DROP_MODEL, dropX, dropY, dropZ, true, true, false)
    if not object or object == 0 or not DoesEntityExist(object) then
        notify(src, 'error', 'Impossible de créer le paquet au sol. Aucun objet retiré.')
        return
    end
    SetEntityHeading(object, heading)
    FreezeEntityPosition(object, true)

    local updated = normalizeInventory(inventory)
    local updatedIndex
    for i, entry in ipairs(updated) do
        if entry.name == itemName then updatedIndex = i break end
    end
    if not updatedIndex then
        DeleteEntity(object)
        return
    end
    if updated[updatedIndex].count <= count then table.remove(updated, updatedIndex)
    else updated[updatedIndex].count = updated[updatedIndex].count - count end

    if not exports['rp_core']:AcquireCharacterLock({ player.charId }) then
        DeleteEntity(object)
        notify(src, 'error', 'Une sauvegarde de votre personnage est en cours. Réessayez.')
        return
    end
    transferLocks[src] = true
    nextDropId = nextDropId + 1
    local dropId = ('%d-%d-%d-%d'):format(os.time(), GetGameTimer(), src, nextDropId)
    local persisted, persistError = pcall(function()
        local ok = MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO player_inventories (character_id, items) VALUES (?, ?)
                    ON DUPLICATE KEY UPDATE items = VALUES(items)
                ]],
                values = { player.charId, json.encode(updated) }
            },
            {
                query = [[
                    INSERT INTO player_inventory_drops
                        (id, item_name, count, x, y, z, heading, routing_bucket)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ]],
                values = {
                    dropId, itemName, count, dropX, dropY, dropZ, heading,
                    GetPlayerRoutingBucket(src)
                }
            }
        })
        if not ok then error('Ground drop transaction rejected') end
    end)
    transferLocks[src] = nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId })
    if not persisted then
        DeleteEntity(object)
        print(('[rp_inventory] Drop transaction failed for character %s: %s'):format(player.charId, tostring(persistError)))
        notify(src, 'error', 'Sauvegarde impossible : objet conservé dans votre inventaire.')
        return
    end

    playerInventories[src] = updated
    groundDrops[dropId] = {
        entity = object, x = dropX, y = dropY, z = dropZ, heading = heading,
        label = definition.label, count = count, itemName = itemName,
        bucket = GetPlayerRoutingBucket(src)
    }
    sendInventory(src, player)
    notify(src, 'success', ('Vous avez déposé %dx %s.'):format(count, definition.label))
    syncDrops()
end)

RegisterNetEvent('rp_inventory:server:pickupDrop', function(rawDropId)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:pickup_drop', 1000) then return end
    local dropId = type(rawDropId) == 'string' and rawDropId or tostring(rawDropId or '')
    local drop = dropId ~= '' and groundDrops[dropId]
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not drop or not player then return end
    if drop.bucket ~= GetPlayerRoutingBucket(src) then return end

    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(drop.entity) then
        groundDrops[dropId] = nil
        syncDrops()
        return
    end
    if #(GetEntityCoords(ped) - GetEntityCoords(drop.entity)) > 2.2 then
        notify(src, 'error', 'Vous êtes trop loin de cet objet.')
        return
    end
    if transferLocks[src] or dropLocks[dropId] then
        notify(src, 'error', 'Cet objet est déjà en cours de récupération.')
        return
    end
    dropLocks[dropId] = true

    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok = pcall(loadInventory, player)
        if not ok then
            dropLocks[dropId] = nil
            notify(src, 'error', 'Impossible de charger votre inventaire.')
            return
        end
    end
    local definition = Config.DefaultItems[drop.itemName]
    if not definition then dropLocks[dropId] = nil; return end
    local updated = normalizeInventory(playerInventories[src])
    if getInventoryWeight(updated) + definition.weight * drop.count > Config.MaxWeight then
        dropLocks[dropId] = nil
        notify(src, 'error', 'Votre inventaire est trop lourd.')
        return
    end
    local found = false
    for _, entry in ipairs(updated) do
        if entry.name == drop.itemName then entry.count = entry.count + drop.count; found = true; break end
    end
    if not found then
        updated[#updated + 1] = {
            name = drop.itemName, count = drop.count,
            label = definition.label, weight = definition.weight
        }
    end

    if not exports['rp_core']:AcquireCharacterLock({ player.charId }) then
        dropLocks[dropId] = nil
        notify(src, 'error', 'Une sauvegarde de votre personnage est en cours. Réessayez.')
        return
    end
    transferLocks[src] = true
    local persisted, persistError = pcall(function()
        local ok = MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO player_inventories (character_id, items) VALUES (?, ?)
                    ON DUPLICATE KEY UPDATE items = VALUES(items)
                ]],
                values = { player.charId, json.encode(updated) }
            },
            {
                query = 'DELETE FROM player_inventory_drops WHERE id = ?',
                values = { dropId }
            }
        })
        if not ok then error('Ground pickup transaction rejected') end
    end)
    transferLocks[src] = nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId })
    dropLocks[dropId] = nil
    if not persisted then
        print(('[rp_inventory] Pickup save failed for character %s: %s'):format(player.charId, tostring(persistError)))
        notify(src, 'error', 'Sauvegarde impossible : l’objet reste au sol.')
        return
    end

    playerInventories[src] = updated
    groundDrops[dropId] = nil
    DeleteEntity(drop.entity)
    TriggerClientEvent('rp_inventory:client:removeDrop', -1, dropId)
    sendInventory(src, player)
    notify(src, 'success', ('Vous avez récupéré %dx %s.'):format(drop.count, definition.label))
end)

RegisterNetEvent('rp_inventory:server:requestWeapons', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:request_weapons', 2000) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or type(player.metadata) ~= 'table' then return end

    local weapons = {}
    for _, entry in ipairs(type(player.metadata.weapons) == 'table' and player.metadata.weapons or {}) do
        if type(entry) == 'table' and type(entry.name) == 'string'
            and entry.name:match('^WEAPON_[A-Z0-9_]+$') then
            local allowedOk, allowed = pcall(function()
                return exports['rp_anticheat']:IsWeaponAllowed(entry.name)
            end)
            if allowedOk and allowed == true then
                local ammo = tonumber(entry.ammo) or 0
                if ammo == ammo then
                    weapons[#weapons + 1] = {
                        name = entry.name,
                        ammo = math.max(0, math.min(9999, math.floor(ammo)))
                    }
                end
            end
        end
    end
    TriggerClientEvent('rp_inventory:client:restoreWeapons', src, weapons)
end)

-- Cache cleanup and persistence are handled by rp_core:server:playerUnloaded.


-- Server-only inventory grant API for trusted gameplay resources (e.g. vehicle salvage).
local function AddItem(source, itemName, rawCount)
    local src = tonumber(source)
    local count = tonumber(rawCount)
    local player = src and exports['rp_core']:GetPlayerFromId(src)
    if not player or type(itemName) ~= 'string' or not count or count % 1 ~= 0 or count < 1 or count > 20 then return false end
    local definition = Config.DefaultItems[itemName]
    if not definition or transferLocks[src] then return false end

    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok = pcall(loadInventory, player)
        if not ok then return false end
    end
    local activePlayer = exports['rp_core']:GetPlayerFromId(src)
    if not activePlayer or tonumber(activePlayer.charId) ~= tonumber(player.charId)
        or inventoryCharacterIds[src] ~= player.charId then return false end

    if not exports['rp_core']:AcquireCharacterLock({ player.charId }) then return false end
    transferLocks[src] = true
    local current = normalizeInventory(playerInventories[src])
    if getInventoryWeight(current) + definition.weight * count > Config.MaxWeight then
        transferLocks[src] = nil
        exports['rp_core']:ReleaseCharacterLock({ player.charId })
        notify(src, 'error', 'Inventaire trop lourd : le butin a été laissé sur place.')
        return false
    end
    local found = false
    for _, item in ipairs(current) do
        if item.name == itemName then item.count = item.count + count; found = true; break end
    end
    if not found then current[#current + 1] = { name = itemName, count = count, label = definition.label, weight = definition.weight } end

    local ok, err = pcall(function()
        MySQL.update.await(
            'INSERT INTO player_inventories (character_id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
            { player.charId, json.encode(current) }
        )
    end)
    transferLocks[src] = nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId })
    if not ok then
        print(('[rp_inventory] AddItem failed for character %s: %s'):format(player.charId, tostring(err)))
        return false
    end
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
        or not count or count % 1 ~= 0 or count < 1 or count > 1000
        or transferLocks[src] then
        return false
    end

    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok = pcall(loadInventory, player)
        if not ok then return false end
    end
    local activePlayer = exports['rp_core']:GetPlayerFromId(src)
    if not activePlayer or tonumber(activePlayer.charId) ~= tonumber(player.charId)
        or inventoryCharacterIds[src] ~= player.charId then return false end
    if not exports['rp_core']:AcquireCharacterLock({ player.charId }) then return false end

    transferLocks[src] = true
    local inventory = normalizeInventory(playerInventories[src])
    local definition = Config.DefaultItems[itemName]
    local foundIndex, currentCount
    for index, item in ipairs(inventory) do
        if item.name == itemName then foundIndex, currentCount = index, item.count; break end
    end
    currentCount = currentCount or 0
    local nextCount = operation == 'add' and (currentCount + count) or (currentCount - count)
    if nextCount < 0 or nextCount > 10000 then
        transferLocks[src] = nil
        exports['rp_core']:ReleaseCharacterLock({ player.charId })
        return false
    end

    if nextCount == 0 then
        if foundIndex then table.remove(inventory, foundIndex) end
    elseif foundIndex then
        inventory[foundIndex].count = nextCount
    else
        inventory[#inventory + 1] = { name = itemName, count = nextCount, label = definition.label, weight = definition.weight }
    end

    if getInventoryWeight(inventory) > Config.MaxWeight then
        transferLocks[src] = nil
        exports['rp_core']:ReleaseCharacterLock({ player.charId })
        return false
    end
    local ok, err = pcall(function()
        MySQL.update.await(
            'INSERT INTO player_inventories (character_id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
            { player.charId, json.encode(inventory) }
        )
    end)
    transferLocks[src] = nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId })
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
            weight = tonumber(definition.weight) or 0,
            type = definition.type or 'item'
        }
    end
    table.sort(catalog, function(a, b) return a.label < b.label end)
    return catalog
end

exports('AdminSetItem', AdminSetItem)
exports('GetItemCatalog', GetItemCatalog)


-- Shared job lockers and grade-restricted armories.
local jobStorageConfigs = {}
local jobStorageLocks = {}

local function loadJobStorageConfigs()
    local rows = MySQL.query.await('SELECT job, x, y, z, stash_enabled, armory_enabled, armory_items FROM rp_creator_job_storage') or {}
    local loaded = {}
    for _, row in ipairs(rows) do
        local ok, allowed = pcall(json.decode, row.armory_items or '[]')
        if ok and type(allowed) == 'table' then
            local weapons = {}
            for _, entry in ipairs(allowed) do
                local minimum = type(entry) == 'table' and tonumber(entry.minGrade) or nil
                if type(entry) == 'table' and type(entry.name) == 'string'
                    and Config.DefaultItems[entry.name] and Config.DefaultItems[entry.name].type == 'weapon'
                    and minimum and minimum % 1 == 0 and minimum >= 0 and minimum <= 4 then
                    weapons[entry.name] = minimum
                end
            end
            local x, y, z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
            if type(row.job) == 'string' and #row.job > 0 and #row.job <= 64
                and x and y and z and x == x and y == y and z == z then
                loaded[row.job] = {
                    job = row.job, coords = vector3(x, y, z),
                    stashEnabled = tonumber(row.stash_enabled) == 1,
                    armoryEnabled = tonumber(row.armory_enabled) == 1,
                    armoryItems = weapons
                }
            else
                print(('[rp_inventory] Ignoring invalid job storage configuration for job %s'):format(tostring(row.job)))
            end
        end
    end
    jobStorageConfigs = loaded
    print(('[rp_inventory] %d coffre(s)/armurerie(s) métier chargé(s).'):format(#rows))
end

MySQL.ready(function()
    CreateThread(function()
        local ok, err = pcall(function()
            MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_creator_job_storage (
                job VARCHAR(64) NOT NULL PRIMARY KEY,
                x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
                stash_enabled TINYINT(1) NOT NULL DEFAULT 1,
                armory_enabled TINYINT(1) NOT NULL DEFAULT 1,
                armory_items LONGTEXT NOT NULL,
                updated_by VARCHAR(80) NOT NULL,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
            MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_job_storage_items (
                job VARCHAR(64) NOT NULL,
                storage_type ENUM('stash','armory') NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                count INT UNSIGNED NOT NULL DEFAULT 0,
                PRIMARY KEY (job, storage_type, item_name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
            MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_job_storage_logs (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
                job VARCHAR(64) NOT NULL,
                storage_type VARCHAR(16) NOT NULL,
                character_id INT NOT NULL,
                player_name VARCHAR(128) NOT NULL,
                direction VARCHAR(16) NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                item_count INT UNSIGNED NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                KEY idx_job_storage_logs_job_created (job, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
            loadJobStorageConfigs()
        end)
        if not ok then print('[rp_inventory] Job storage initialization failed: ' .. tostring(err)) end
    end)
end)

RegisterNetEvent('rp_inventory:server:reloadJobStorageConfigs', function()
    if source ~= 0 then return end
    local ok, err = pcall(loadJobStorageConfigs)
    if not ok then print('[rp_inventory] Job storage reload failed: ' .. tostring(err)) end
end)

local function getJobStorageAccess(src, storageType)
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or type(player.job) ~= 'string' then return nil end
    local config = jobStorageConfigs[player.job]
    if not config then return nil end
    if storageType == 'stash' and not config.stashEnabled then return nil end
    if storageType == 'armory' and not config.armoryEnabled then return nil end
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) or #(GetEntityCoords(ped) - config.coords) > 3.5 then return nil end
    return player, config
end

local function getStorageItems(job, storageType, config, grade)
    local rows = MySQL.query.await(
        'SELECT item_name, count FROM rp_job_storage_items WHERE job = ? AND storage_type = ? AND count > 0 ORDER BY item_name ASC',
        { job, storageType }) or {}
    local result = {}
    for _, row in ipairs(rows) do
        local def = Config.DefaultItems[row.item_name]
        local typeAllowed = (storageType == 'stash' and def and def.type ~= 'weapon')
            or (storageType == 'armory' and def and def.type == 'weapon')
        local gradeAllowed = storageType ~= 'armory'
            or (config and config.armoryItems[row.item_name] ~= nil
                and (tonumber(grade) or 0) >= config.armoryItems[row.item_name])
        if typeAllowed and gradeAllowed then
            result[#result + 1] = { name = row.item_name, label = def.label or row.item_name, count = tonumber(row.count) or 0 }
        end
    end
    return result
end

local function sendJobStorageData(src, storageType)
    local player, config = getJobStorageAccess(src, storageType)
    if not player or not config then
        notify(src, 'error', 'Accès au coffre métier refusé ou trop éloigné.')
        return false
    end
    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local ok = pcall(loadInventory, player)
        if not ok then notify(src, 'error', 'Inventaire indisponible.'); return false end
    end
    local storageItems = getStorageItems(player.job, storageType, config, player.jobGrade)
    local inventory = {}
    for _, item in ipairs(normalizeInventory(playerInventories[src])) do
        local def = Config.DefaultItems[item.name]
        local allowed = (storageType == 'stash' and def and def.type ~= 'weapon')
            or (storageType == 'armory' and def and def.type == 'weapon'
                and config.armoryItems[item.name] ~= nil
                and (tonumber(player.jobGrade) or 0) >= config.armoryItems[item.name])
        if allowed then
            inventory[#inventory + 1] = { name = item.name, label = item.label or item.name, count = item.count }
        end
    end
    TriggerClientEvent('rp_inventory:client:jobStorageData', src, {
        job = player.job, storageType = storageType, storageItems = storageItems,
        inventoryItems = inventory
    })
    return true
end

RegisterNetEvent('rp_inventory:server:requestJobStorageMarker', function()
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    local config = player and jobStorageConfigs[player.job]
    if not config then
        TriggerClientEvent('rp_inventory:client:jobStorageMarker', src, nil)
        return
    end
    TriggerClientEvent('rp_inventory:client:jobStorageMarker', src, {
        x = config.coords.x, y = config.coords.y, z = config.coords.z,
        stashEnabled = config.stashEnabled, armoryEnabled = config.armoryEnabled
    })
end)

RegisterNetEvent('rp_inventory:server:openJobStorage', function(storageType)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:open_job_storage', 900) then return end
    if storageType ~= 'stash' and storageType ~= 'armory' then return end
    sendJobStorageData(src, storageType)
end)

RegisterNetEvent('rp_inventory:server:transferJobStorage', function(storageType, direction, itemName, rawCount)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'inventory:transfer_job_storage', 700) then return end
    if (storageType ~= 'stash' and storageType ~= 'armory')
        or (direction ~= 'deposit' and direction ~= 'withdraw')
        or type(itemName) ~= 'string' or #itemName > 64 then return end
    local count = tonumber(rawCount)
    if not count or count % 1 ~= 0 or count < 1 or count > 20 then return end

    local player, config = getJobStorageAccess(src, storageType)
    local definition = Config.DefaultItems[itemName]
    if not player or not config or not definition then
        notify(src, 'error', 'Objet ou accès au coffre invalide.')
        return
    end
    local lockedJob = player.job
    if storageType == 'stash' and definition.type == 'weapon' then
        notify(src, 'error', 'Les armes doivent passer par l’armurerie et ses restrictions de grade.')
        return
    end
    if storageType == 'armory' then
        local minimum = config.armoryItems[itemName]
        if definition.type ~= 'weapon' or minimum == nil or (tonumber(player.jobGrade) or 0) < minimum then
            notify(src, 'error', 'Cette arme n’est pas autorisée pour ton grade.')
            return
        end
        if direction == 'withdraw' then
            local allowedOk, allowed = pcall(function()
                return exports['rp_anticheat']:IsWeaponAllowed(definition.weapon)
            end)
            if not allowedOk or allowed ~= true then
                notify(src, 'error', 'Cette arme est désactivée par la politique du serveur.')
                return
            end
        end
    end
    if transferLocks[src] or jobStorageLocks[lockedJob] then
        notify(src, 'error', 'Une opération sur ce coffre est déjà en cours.')
        return
    end

    if not playerInventories[src] or inventoryCharacterIds[src] ~= player.charId then
        local loaded = pcall(loadInventory, player)
        if not loaded then notify(src, 'error', 'Inventaire indisponible.'); return end
    end

    -- Recheck after inventory loading, then hold both character and job locks
    -- before reading the shared stock so simultaneous transfers cannot duplicate it.
    player, config = getJobStorageAccess(src, storageType)
    if not player or player.job ~= lockedJob or transferLocks[src] or jobStorageLocks[lockedJob] then
        notify(src, 'error', 'Ton métier ou le coffre est indisponible. Réessaie.')
        return
    end
    jobStorageLocks[lockedJob] = src
    if not exports['rp_core']:AcquireCharacterLock({ player.charId }) then
        jobStorageLocks[lockedJob] = nil
        notify(src, 'error', 'Sauvegarde du personnage en cours. Réessaie.')
        return
    end
    transferLocks[src] = true

    local updatedInventory
    local failureMessage
    local persisted, persistError = pcall(function()
        local currentPlayer, currentConfig = getJobStorageAccess(src, storageType)
        if not currentPlayer or tonumber(currentPlayer.charId) ~= tonumber(player.charId)
            or currentPlayer.job ~= lockedJob then
            failureMessage = 'Ton métier ou ton accès au coffre a changé. Réessaie.'
            error('Job storage access changed')
        end
        player, config = currentPlayer, currentConfig
        if storageType == 'armory' then
            local minimum = config.armoryItems[itemName]
            if definition.type ~= 'weapon' or minimum == nil or (tonumber(player.jobGrade) or 0) < minimum then
                failureMessage = 'Cette arme n’est plus autorisée pour ton grade.'
                error('Armory permission changed')
            end
        end
        local inventory = normalizeInventory(playerInventories[src])
        local playerIndex, playerCount
        for index, entry in ipairs(inventory) do
            if entry.name == itemName then playerIndex, playerCount = index, entry.count; break end
        end
        playerCount = playerCount or 0
        local storageRow = MySQL.single.await(
            'SELECT count FROM rp_job_storage_items WHERE job = ? AND storage_type = ? AND item_name = ?',
            { lockedJob, storageType, itemName })
        local storageCount = storageRow and tonumber(storageRow.count) or 0
        local nextPlayerCount, nextStorageCount
        if direction == 'deposit' then
            if playerCount < count then
                failureMessage = 'Quantité insuffisante dans ton inventaire.'
                error('Not enough player items')
            end
            nextPlayerCount, nextStorageCount = playerCount - count, storageCount + count
        else
            if storageCount < count then
                failureMessage = 'Quantité insuffisante dans le coffre.'
                error('Not enough storage items')
            end
            nextPlayerCount, nextStorageCount = playerCount + count, storageCount - count
        end
        if nextStorageCount > 10000 then
            failureMessage = 'Capacité de stockage atteinte.'
            error('Job storage item capacity exceeded')
        end

        local updated = normalizeInventory(inventory)
        if direction == 'deposit' then
            if nextPlayerCount == 0 then
                if playerIndex then table.remove(updated, playerIndex) end
            elseif playerIndex then
                updated[playerIndex].count = nextPlayerCount
            end
        else
            local found = false
            for _, entry in ipairs(updated) do
                if entry.name == itemName then entry.count = nextPlayerCount; found = true; break end
            end
            if not found then updated[#updated + 1] = {
                name = itemName, count = count, label = definition.label, weight = definition.weight
            } end
        end
        if getInventoryWeight(updated) > Config.MaxWeight then
            failureMessage = 'Ton inventaire est trop lourd pour récupérer cet objet.'
            error('Player inventory weight exceeded')
        end

        local queries = {
            { query = 'INSERT INTO player_inventories (character_id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
                values = { player.charId, json.encode(updated) } },
            { query = [[INSERT INTO rp_job_storage_items (job, storage_type, item_name, count)
                VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE count = VALUES(count)]],
                values = { lockedJob, storageType, itemName, nextStorageCount } },
            { query = 'INSERT INTO rp_job_storage_logs (job, storage_type, character_id, player_name, direction, item_name, item_count) VALUES (?, ?, ?, ?, ?, ?, ?)',
                values = { lockedJob, storageType, player.charId, (GetPlayerName(src) or 'Inconnu'):sub(1, 128),
                    direction, itemName, count } },
            { query = 'DELETE FROM rp_job_storage_items WHERE job = ? AND storage_type = ? AND item_name = ? AND count = 0',
                values = { lockedJob, storageType, itemName } }
        }
        if not MySQL.transaction.await(queries) then error('Job storage transaction rejected') end
        updatedInventory = updated
    end)

    transferLocks[src] = nil
    jobStorageLocks[lockedJob] = nil
    exports['rp_core']:ReleaseCharacterLock({ player.charId })
    if not persisted then
        if failureMessage then
            notify(src, 'error', failureMessage)
        else
            print(('[rp_inventory] Job storage transfer failed for character %s: %s'):format(player.charId, tostring(persistError)))
            notify(src, 'error', 'La transaction a échoué. Aucun transfert confirmé.')
        end
        return
    end

    playerInventories[src] = updatedInventory
    sendInventory(src, player)
    notify(src, 'success', direction == 'deposit' and 'Objet déposé.' or 'Objet récupéré.')
    sendJobStorageData(src, storageType)
end)
