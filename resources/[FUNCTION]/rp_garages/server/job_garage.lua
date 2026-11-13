local garages = {}
local activeVehicles = {}
local requestLocks = {}

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(src)
end

local function getGarageForPlayer(src)
    local player = getPlayer(src)
    if not player or type(player.job) ~= 'string' then return nil, player end
    local garage = garages[player.job]
    if not garage then return nil, player end
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil, player end
    local coords = GetEntityCoords(ped)
    if #(coords - garage.coords) > 6.0 then return nil, player end
    return garage, player
end

local function loadGarages()
    local rows = MySQL.query.await('SELECT job, x, y, z, spawn_x, spawn_y, spawn_z, spawn_heading, vehicles FROM rp_creator_job_garages') or {}
    local loaded = {}
    for _, row in ipairs(rows) do
        local ok, vehicles = pcall(json.decode, row.vehicles or '[]')
        if ok and type(vehicles) == 'table' and #vehicles <= 20 then
            loaded[row.job] = {
                job = row.job,
                coords = vector3(tonumber(row.x), tonumber(row.y), tonumber(row.z)),
                spawn = vector4(tonumber(row.spawn_x), tonumber(row.spawn_y), tonumber(row.spawn_z), tonumber(row.spawn_heading) or 0.0),
                vehicles = vehicles
            }
        end
    end
    garages = loaded
    print(('[rp_garages] %d garage(s) métier chargé(s).'):format(#rows))
end

MySQL.ready(function()
    CreateThread(function()
        for attempt = 1, 10 do
            local ok, err = pcall(loadGarages)
            if ok then return end
            print(('[rp_garages] Attente des garages Creator (%d/10): %s'):format(attempt, tostring(err)))
            Wait(3000)
        end
        print('[rp_garages] ERREUR: garages métiers indisponibles après 10 tentatives.')
    end)
end)

RegisterNetEvent('rp_garages:server:requestJobFleet', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'garages:job_fleet', 900) then return end
    local now = GetGameTimer()
    if requestLocks[src] and now - requestLocks[src] < 700 then return end
    requestLocks[src] = now

    local garage, player = getGarageForPlayer(src)
    if not garage or not player then
        notify(src, 'Aucun garage métier ici ou accès refusé.', 'error')
        return
    end
    if activeVehicles[src] then
        local entity = NetworkGetEntityFromNetworkId(activeVehicles[src].netId)
        if entity ~= 0 and DoesEntityExist(entity) then
            notify(src, 'Tu as déjà un véhicule de service sorti.', 'warning')
            return
        end
        activeVehicles[src] = nil
    end

    local available = {}
    local grade = tonumber(player.jobGrade) or 0
    for _, entry in ipairs(garage.vehicles) do
        local minGrade = tonumber(entry.minGrade) or 0
        if type(entry.model) == 'string' and type(entry.label) == 'string' and grade >= minGrade then
            available[#available + 1] = { model = entry.model, label = entry.label, minGrade = minGrade }
        end
    end
    if #available == 0 then
        notify(src, 'Aucun véhicule disponible pour ton grade.', 'warning')
        return
    end
    TriggerClientEvent('rp_garages:client:jobFleet', src, {
        job = garage.job, vehicles = available, spawn = {
            x = garage.spawn.x, y = garage.spawn.y, z = garage.spawn.z, w = garage.spawn.w
        }
    })
end)

RegisterNetEvent('rp_garages:server:spawnJobVehicle', function(rawModel)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'garages:spawn_job_vehicle', 1800) then return end
    local garage, player = getGarageForPlayer(src)
    if not garage or not player or type(rawModel) ~= 'string' or #rawModel < 3 or #rawModel > 50 then
        notify(src, 'Sortie du véhicule de service refusée.', 'error')
        return
    end
    if activeVehicles[src] then
        notify(src, 'Tu as déjà un véhicule de service sorti.', 'warning')
        return
    end

    local permitted = false
    local grade = tonumber(player.jobGrade) or 0
    for _, entry in ipairs(garage.vehicles) do
        if entry.model == rawModel and grade >= (tonumber(entry.minGrade) or 0) then permitted = true break end
    end
    if not permitted then
        notify(src, 'Ce véhicule n’est pas autorisé pour ton métier ou ton grade.', 'error')
        return
    end

    local spawn = garage.spawn
    if IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.5) then
        notify(src, 'La sortie du garage est bloquée.', 'error')
        return
    end
    local hash = GetHashKey(rawModel)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) or not IsModelAVehicle(hash) then
        notify(src, 'Modèle de véhicule invalide. Contacte un administrateur.', 'error')
        return
    end

    local vehicle = CreateVehicleServerSetter(hash, 'automobile', spawn.x, spawn.y, spawn.z, spawn.w)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(src, 'Le serveur n’a pas pu créer le véhicule.', 'error')
        return
    end
    local plate = ('SV%05d'):format((tonumber(src) * 997 + GetGameTimer()) % 100000)
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetEntityOrphanMode(vehicle, 2)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    activeVehicles[src] = { netId = netId, entity = vehicle, job = garage.job, model = rawModel, plate = plate }
    TriggerClientEvent('rp_garages:client:jobVehicleSpawned', src, netId)
    notify(src, 'Véhicule de service sorti.', 'success')
end)

RegisterNetEvent('rp_garages:server:storeJobVehicle', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'garages:store_job_vehicle', 1800) then return end
    local garage, player = getGarageForPlayer(src)
    local active = activeVehicles[src]
    if not garage or not player or not active or active.job ~= player.job then
        notify(src, 'Aucun véhicule de service à ranger ici.', 'error')
        return
    end
    local ped = GetPlayerPed(src)
    local vehicle = active.entity
    if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or NetworkGetNetworkIdFromEntity(vehicle) ~= active.netId
        or GetEntityModel(vehicle) ~= GetHashKey(active.model)
        or GetVehicleNumberPlateText(vehicle):sub(1, 7) ~= active.plate:sub(1, 7) then
        notify(src, 'Tu dois être au volant de ton véhicule de service.', 'error')
        return
    end
    DeleteEntity(vehicle)
    activeVehicles[src] = nil
    TriggerClientEvent('rp_garages:client:jobVehicleStored', src)
    notify(src, 'Véhicule de service rangé.', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local active = activeVehicles[src]
    if active and active.entity and DoesEntityExist(active.entity) then DeleteEntity(active.entity) end
    activeVehicles[src] = nil
    requestLocks[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, active in pairs(activeVehicles) do
        if active.entity and DoesEntityExist(active.entity) then DeleteEntity(active.entity) end
        activeVehicles[src] = nil
    end
end)

RegisterNetEvent('rp_garages:server:requestJobGarageMarker', function()
    local src = source
    local player = getPlayer(src)
    local garage = player and garages[player.job]
    if not garage then
        TriggerClientEvent('rp_garages:client:setJobGarage', src, nil)
        return
    end
    TriggerClientEvent('rp_garages:client:setJobGarage', src, {
        coords = { x = garage.coords.x, y = garage.coords.y, z = garage.coords.z }
    })
end)

RegisterNetEvent('rp_garages:server:reloadJobGarages', function()
    local src = source
    if src ~= 0 then return end
    local ok, err = pcall(loadGarages)
    if not ok then print('[rp_garages] Garage refresh failed: ' .. tostring(err)) end
end)
