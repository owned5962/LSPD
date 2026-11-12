local pendingSpawns = {}
local actionLocks = {}

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(src)
end

local function getGarage(src, garageId)
    if type(garageId) ~= 'string' then return nil end
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    for _, garage in ipairs(Config.Garages) do
        if garage.id == garageId and #(coords - garage.coords) <= Config.ServerInteractionDistance then
            return garage
        end
    end
    return nil
end

local function validProps(rawProps, expectedModel, expectedPlate)
    if type(rawProps) ~= 'table' then return nil end
    local props = {
        model = expectedModel,
        plate = expectedPlate,
        engineHealth = math.max(-4000.0, math.min(1000.0, tonumber(rawProps.engineHealth) or 1000.0)),
        bodyHealth = math.max(0.0, math.min(1000.0, tonumber(rawProps.bodyHealth) or 1000.0)),
        fuelLevel = math.max(0.0, math.min(100.0, tonumber(rawProps.fuelLevel) or 100.0)),
        dirtLevel = math.max(0.0, math.min(15.0, tonumber(rawProps.dirtLevel) or 0.0)),
        primaryColor = math.max(0, math.min(160, math.floor(tonumber(rawProps.primaryColor) or 0))),
        secondaryColor = math.max(0, math.min(160, math.floor(tonumber(rawProps.secondaryColor) or 0))),
        pearlescentColor = math.max(0, math.min(160, math.floor(tonumber(rawProps.pearlescentColor) or 0))),
        wheelColor = math.max(0, math.min(160, math.floor(tonumber(rawProps.wheelColor) or 0))),
        wheelType = math.max(0, math.min(12, math.floor(tonumber(rawProps.wheelType) or 0))),
        windowTint = math.max(0, math.min(6, math.floor(tonumber(rawProps.windowTint) or 0))),
        plateIndex = math.max(0, math.min(5, math.floor(tonumber(rawProps.plateIndex) or 0))),
        mods = {}
    }

    if type(rawProps.mods) == 'table' then
        for modType = 0, 49 do
            local value = tonumber(rawProps.mods[tostring(modType)] or rawProps.mods[modType])
            if value and value % 1 == 0 then
                props.mods[tostring(modType)] = math.max(-1, math.min(100, value))
            end
        end
    end

    for _, key in ipairs({ 'turbo', 'xenon', 'tyreSmoke', 'bulletProofTyres' }) do
        if rawProps[key] ~= nil then props[key] = rawProps[key] == true end
    end

    for _, key in ipairs({ 'neonEnabled' }) do
        if type(rawProps[key]) == 'table' then
            props[key] = {}
            for i = 1, 4 do props[key][i] = rawProps[key][i] == true end
        end
    end

    if type(rawProps.neonColor) == 'table' then
        props.neonColor = {}
        for i = 1, 3 do props.neonColor[i] = math.max(0, math.min(255, math.floor(tonumber(rawProps.neonColor[i]) or 0))) end
    end
    if type(rawProps.customPrimaryColor) == 'table' and #rawProps.customPrimaryColor >= 3 then
        props.customPrimaryColor = {}
        for i = 1, 3 do props.customPrimaryColor[i] = math.max(0, math.min(255, math.floor(tonumber(rawProps.customPrimaryColor[i]) or 0))) end
    end
    if type(rawProps.customSecondaryColor) == 'table' and #rawProps.customSecondaryColor >= 3 then
        props.customSecondaryColor = {}
        for i = 1, 3 do props.customSecondaryColor[i] = math.max(0, math.min(255, math.floor(tonumber(rawProps.customSecondaryColor[i]) or 0))) end
    end
    if type(rawProps.livery) == 'number' then props.livery = math.max(-1, math.min(100, math.floor(rawProps.livery))) end
    if type(rawProps.modLivery) == 'number' then props.modLivery = math.max(-1, math.min(100, math.floor(rawProps.modLivery))) end

    return props
end

local function lockAction(src, action)
    local key = ('%s:%s'):format(src, action)
    local now = GetGameTimer()
    if actionLocks[key] and now - actionLocks[key] < Config.ActionCooldown then return false end
    actionLocks[key] = now
    return true
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS rp_owned_vehicles (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                character_id BIGINT UNSIGNED NOT NULL,
                identifier VARCHAR(80) NOT NULL,
                plate VARCHAR(12) NOT NULL,
                model VARCHAR(60) NOT NULL,
                label VARCHAR(120) NOT NULL,
                price INT UNSIGNED NOT NULL,
                dealership VARCHAR(80) NOT NULL,
                stored TINYINT(1) NOT NULL DEFAULT 0,
                vehicle_props LONGTEXT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_rp_owned_vehicles_plate (plate),
                KEY idx_rp_owned_vehicles_character (character_id),
                KEY idx_rp_owned_vehicles_identifier (identifier)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end)
    if not ok then
        print(('[rp_garages] SQL initialization failed: %s'):format(tostring(err)))
    else
        print('[rp_garages] Personal garage registry ready.')
    end
end)

RegisterNetEvent('rp_garages:server:open', function(garageId)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'garages:open', 900) then return end
    local garage = getGarage(src, garageId)
    local player = getPlayer(src)
    if not garage or not player then
        notify(src, 'Accès au garage refusé : rapproche-toi de l’entrée.', 'error')
        return
    end

    local rows = MySQL.query.await([[
        SELECT id, plate, model, label, price, stored, vehicle_props
        FROM rp_owned_vehicles
        WHERE character_id = ? AND identifier = ?
        ORDER BY id DESC
    ]], { player.charId, player.identifier }) or {}

    local vehicles = {}
    for _, row in ipairs(rows) do
        local props
        if type(row.vehicle_props) == 'string' and row.vehicle_props ~= '' then
            local decodedOk, decoded = pcall(json.decode, row.vehicle_props)
            if decodedOk and type(decoded) == 'table' then props = decoded end
        end
        vehicles[#vehicles + 1] = {
            id = tonumber(row.id),
            plate = tostring(row.plate),
            model = tostring(row.model),
            label = tostring(row.label),
            stored = tonumber(row.stored) == 1,
            fuel = props and tonumber(props.fuelLevel) or 100,
            engine = props and tonumber(props.engineHealth) or 1000
        }
    end

    TriggerClientEvent('rp_garages:client:open', src, {
        garage = garage.id,
        label = garage.label,
        vehicles = vehicles
    })
end)

RegisterNetEvent('rp_garages:server:store', function(garageId, rawNetId, rawProps)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'garages:store', 1800) or not lockAction(src, 'store') then return end
    local garage = getGarage(src, garageId)
    local player = getPlayer(src)
    local netId = tonumber(rawNetId)
    if not garage or not player or not netId or netId < 1 or netId % 1 ~= 0 then
        notify(src, 'Rangement refusé : demande invalide.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2
        or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or #(GetEntityCoords(ped) - garage.coords) > Config.ServerInteractionDistance then
        notify(src, 'Tu dois être conducteur du véhicule près du garage.', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if type(plate) ~= 'string' then return end
    plate = plate:gsub('%s+$', '')
    local owned = MySQL.single.await([[
        SELECT id, model, stored FROM rp_owned_vehicles
        WHERE plate = ? AND character_id = ? AND identifier = ? LIMIT 1
    ]], { plate, player.charId, player.identifier })
    if not owned then
        notify(src, 'Ce véhicule ne t’appartient pas.', 'error')
        return
    end
    if GetEntityModel(vehicle) ~= GetHashKey(tostring(owned.model)) then
        notify(src, 'Le modèle du véhicule ne correspond pas à son enregistrement.', 'error')
        return
    end
    if tonumber(owned.stored) == 1 then
        notify(src, 'Ce véhicule est déjà rangé.', 'error')
        return
    end

    local props = validProps(rawProps, tostring(owned.model), plate)
    if not props then
        notify(src, 'Impossible de sauvegarder les caractéristiques du véhicule.', 'error')
        return
    end

    local ok, affected = pcall(MySQL.update.await,
        'UPDATE rp_owned_vehicles SET stored = 1, vehicle_props = ? WHERE id = ? AND character_id = ? AND stored = 0',
        { json.encode(props), owned.id, player.charId })
    if not ok or tonumber(affected) ~= 1 then
        notify(src, 'Erreur SQL : le véhicule n’a pas été rangé.', 'error')
        return
    end

    DeleteEntity(vehicle)
    TriggerClientEvent('rp_garages:client:stored', src, plate)
end)

RegisterNetEvent('rp_garages:server:retrieve', function(garageId, rawVehicleId)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'garages:retrieve', 1800) or not lockAction(src, 'retrieve') then return end
    local garage = getGarage(src, garageId)
    local player = getPlayer(src)
    local vehicleId = tonumber(rawVehicleId)
    if not garage or not player or not vehicleId or vehicleId < 1 or vehicleId % 1 ~= 0 then
        notify(src, 'Sortie du véhicule refusée.', 'error')
        return
    end
    if pendingSpawns[src] then
        notify(src, 'Une sortie de véhicule est déjà en cours.', 'warning')
        return
    end

    local row = MySQL.single.await([[
        SELECT id, plate, model, label, stored, vehicle_props
        FROM rp_owned_vehicles
        WHERE id = ? AND character_id = ? AND identifier = ? LIMIT 1
    ]], { vehicleId, player.charId, player.identifier })
    if not row or tonumber(row.stored) ~= 1 then
        notify(src, 'Ce véhicule est déjà sorti ou ne t’appartient pas.', 'error')
        return
    end

    local spawn = garage.spawn
    local spawnCoords = vector3(spawn.x, spawn.y, spawn.z)
    if IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, Config.SpawnClearDistance) then
        notify(src, 'La sortie du garage est bloquée. Libère la place.', 'error')
        return
    end

    local props = {}
    if type(row.vehicle_props) == 'string' and row.vehicle_props ~= '' then
        local ok, decoded = pcall(json.decode, row.vehicle_props)
        if ok and type(decoded) == 'table' then props = decoded end
    end
    props = validProps(props, tostring(row.model), tostring(row.plate)) or {
        model = tostring(row.model), plate = tostring(row.plate),
        engineHealth = 1000.0, bodyHealth = 1000.0, fuelLevel = 100.0, mods = {}
    }

    local ok, affected = pcall(MySQL.update.await,
        'UPDATE rp_owned_vehicles SET stored = 0 WHERE id = ? AND character_id = ? AND stored = 1',
        { row.id, player.charId })
    if not ok or tonumber(affected) ~= 1 then
        notify(src, 'Impossible de réserver ce véhicule pour sa sortie.', 'error')
        return
    end

    pendingSpawns[src] = { id = tonumber(row.id), charId = player.charId, plate = tostring(row.plate), model = tostring(row.model), spawn = spawnCoords, createdAt = os.time() }
    TriggerClientEvent('rp_garages:client:spawn', src, {
        garage = garage.id,
        vehicleId = tonumber(row.id),
        model = tostring(row.model),
        plate = tostring(row.plate),
        spawn = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w },
        props = props
    })
end)

RegisterNetEvent('rp_garages:server:spawned', function(rawNetId, rawVehicleId)
    local src = source
    local pending = pendingSpawns[src]
    local netId = tonumber(rawNetId)
    local vehicleId = tonumber(rawVehicleId)
    if not pending or pending.id ~= vehicleId or not netId or netId < 1 or netId % 1 ~= 0
        or os.time() - pending.createdAt > Config.SpawnTimeout then
        if pending then
            MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
            pendingSpawns[src] = nil
        end
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2
        or NetworkGetEntityOwner(entity) ~= src
        or GetVehicleNumberPlateText(entity):gsub('%s+
        MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
        pendingSpawns[src] = nil
        TriggerClientEvent('rp_garages:client:spawnFailed', src, 'Le véhicule n’a pas été validé. Réessaie.')
        return
    end

    pendingSpawns[src] = nil
    TriggerClientEvent('rp_garages:client:spawnConfirmed', src, netId)
end)

RegisterNetEvent('rp_garages:server:spawnFailed', function(rawVehicleId)
    local src = source
    local pending = pendingSpawns[src]
    local vehicleId = tonumber(rawVehicleId)
    if not pending or pending.id ~= vehicleId then return end
    MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
    pendingSpawns[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    local pending = pendingSpawns[src]
    if pending then
        MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
        pendingSpawns[src] = nil
    end
    for key in pairs(actionLocks) do
        if key:match('^' .. src .. ':') then actionLocks[key] = nil end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, pending in pairs(pendingSpawns) do
            if now - pending.createdAt > Config.SpawnTimeout then
                MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
                pendingSpawns[src] = nil
                notify(src, 'La sortie du véhicule a expiré. Il a été remis dans le garage.', 'error')
            end
        end
    end
end)

exports('GetStoredVehicles', function(characterId)
    characterId = tonumber(characterId)
    if not characterId then return {} end
    return MySQL.query.await(
        'SELECT id, plate, model, label, stored FROM rp_owned_vehicles WHERE character_id = ? ORDER BY id DESC',
        { characterId }
    ) or {}
end)
, '') ~= pending.plate
        or GetEntityModel(entity) ~= GetHashKey(pending.model)
        or #(GetEntityCoords(entity) - pending.spawn) > 8.0 then
        MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
        pendingSpawns[src] = nil
        TriggerClientEvent('rp_garages:client:spawnFailed', src, 'Le véhicule n’a pas été validé. Réessaie.')
        return
    end

    pendingSpawns[src] = nil
    TriggerClientEvent('rp_garages:client:spawnConfirmed', src, netId)
end)

RegisterNetEvent('rp_garages:server:spawnFailed', function(rawVehicleId)
    local src = source
    local pending = pendingSpawns[src]
    local vehicleId = tonumber(rawVehicleId)
    if not pending or pending.id ~= vehicleId then return end
    MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
    pendingSpawns[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    local pending = pendingSpawns[src]
    if pending then
        MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
        pendingSpawns[src] = nil
    end
    for key in pairs(actionLocks) do
        if key:match('^' .. src .. ':') then actionLocks[key] = nil end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, pending in pairs(pendingSpawns) do
            if now - pending.createdAt > Config.SpawnTimeout then
                MySQL.update.await('UPDATE rp_owned_vehicles SET stored = 1 WHERE id = ? AND character_id = ?', { pending.id, pending.charId })
                pendingSpawns[src] = nil
                notify(src, 'La sortie du véhicule a expiré. Il a été remis dans le garage.', 'error')
            end
        end
    end
end)

exports('GetStoredVehicles', function(characterId)
    characterId = tonumber(characterId)
    if not characterId then return {} end
    return MySQL.query.await(
        'SELECT id, plate, model, label, stored FROM rp_owned_vehicles WHERE character_id = ? ORDER BY id DESC',
        { characterId }
    ) or {}
end)
