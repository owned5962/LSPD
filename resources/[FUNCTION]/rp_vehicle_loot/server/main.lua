local stolen = {}
local pendingSteals = {}
local TIRE_ACTION_DURATION_MS = 6500
local TIRE_ACTION_TIMEOUT_MS = 60000
local MAX_PLAYER_DISTANCE = 4.0
local MAX_VEHICLE_MOVEMENT = 2.0

local loot = {
    { item = 'rubber', min = 1, max = 3, weight = 35 },
    { item = 'scrap_metal', min = 1, max = 3, weight = 30 },
    { item = 'copper_wire', min = 1, max = 2, weight = 18 },
    { item = 'electronic_parts', min = 1, max = 2, weight = 12 },
    { item = 'car_battery', min = 1, max = 1, weight = 5 }
}

local function notify(src, message, kind)
    if GetPlayerName(src) then
        TriggerClientEvent('rp_core:client:notify', src, message, kind or 'error')
    end
end

local function chooseLoot()
    local roll, total = math.random(1, 100), 0
    for _, entry in ipairs(loot) do
        total = total + entry.weight
        if roll <= total then return entry end
    end
    return loot[1]
end

local function parseTarget(rawNetId, rawWheel)
    local netId, wheel = tonumber(rawNetId), tonumber(rawWheel)
    if not netId or netId < 1 or netId % 1 ~= 0
        or not wheel or wheel % 1 ~= 0 or wheel < 0 or wheel > 3 then
        return nil, nil
    end
    return netId, wheel
end

local function getValidScene(src, netId)
    local ped = GetPlayerPed(src)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not ped or ped == 0 or not DoesEntityExist(ped)
        or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil, nil
    end

    if GetVehiclePedIsIn(ped, false) ~= 0
        or GetEntitySpeed(vehicle) > 0.5
        or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > MAX_PLAYER_DISTANCE then
        return nil, nil
    end

    for _, rawId in ipairs(GetPlayers()) do
        local otherPed = GetPlayerPed(tonumber(rawId))
        if otherPed ~= 0 and GetVehiclePedIsIn(otherPed, false) == vehicle then
            return nil, nil
        end
    end

    return ped, vehicle
end

local function wheelAlreadyStolen(netId, wheel)
    local wheels = stolen[tostring(netId)]
    return wheels and wheels[wheel] == true
end

RegisterNetEvent('rp_vehicle_loot:server:startTire', function(rawNetId, rawWheel)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'vehicle:steal_tire_start', 1000) then return end

    local netId, wheel = parseTarget(rawNetId, rawWheel)
    if not netId then
        notify(src, 'Cible de démontage invalide.')
        return
    end

    if pendingSteals[src] then
        notify(src, 'Vous avez déjà un démontage en cours.', 'warning')
        return
    end

    local player = exports['rp_core']:GetPlayerFromId(src)
    local ped, vehicle = getValidScene(src, netId)
    if not player or not player.charId or not ped or not vehicle then
        notify(src, 'Rapprochez-vous d’un véhicule immobilisé et vide.')
        return
    end

    -- The repair kit is a reusable tool; its possession is verified from the
    -- server inventory cache, never from a client-supplied item name.
    local inventory = exports['rp_inventory']:GetPlayerInventory(src)
    local hasRepairKit = false
    for _, item in ipairs(type(inventory) == 'table' and inventory or {}) do
        if item.name == 'repairkit' and (tonumber(item.count) or 0) > 0 then
            hasRepairKit = true
            break
        end
    end
    if not hasRepairKit then
        notify(src, 'Vous devez posséder un kit de réparation pour démonter un pneu.')
        return
    end

    if wheelAlreadyStolen(netId, wheel) then
        notify(src, 'Ce pneu a déjà été démonté.', 'warning')
        return
    end

    pendingSteals[src] = {
        netId = netId,
        wheel = wheel,
        charId = player.charId,
        vehicle = vehicle,
        startedAt = GetGameTimer(),
        vehicleStartCoords = GetEntityCoords(vehicle)
    }
end)

RegisterNetEvent('rp_vehicle_loot:server:cancelTire', function(rawNetId, rawWheel)
    local src = source
    local pending = pendingSteals[src]
    local netId, wheel = parseTarget(rawNetId, rawWheel)
    if pending and netId == pending.netId and wheel == pending.wheel then
        pendingSteals[src] = nil
    end
end)

RegisterNetEvent('rp_vehicle_loot:server:completeTire', function(rawNetId, rawWheel)
    local src = source
    local netId, wheel = parseTarget(rawNetId, rawWheel)
    local pending = pendingSteals[src]

    if not pending or not netId or pending.netId ~= netId or pending.wheel ~= wheel then
        notify(src, 'Aucun démontage valide n’est en cours.')
        return
    end

    local elapsed = GetGameTimer() - pending.startedAt
    if elapsed < TIRE_ACTION_DURATION_MS or elapsed > TIRE_ACTION_TIMEOUT_MS then
        pendingSteals[src] = nil
        notify(src, 'Délai de démontage invalide. Recommencez.')
        return
    end

    if not exports['rp_core']:CanPerformAction(src, 'vehicle:steal_tire', 12000) then
        pendingSteals[src] = nil
        return
    end

    local player = exports['rp_core']:GetPlayerFromId(src)
    local ped, vehicle = getValidScene(src, netId)
    if not player or player.charId ~= pending.charId or not ped or vehicle ~= pending.vehicle
        or #(GetEntityCoords(vehicle) - pending.vehicleStartCoords) > MAX_VEHICLE_MOVEMENT then
        pendingSteals[src] = nil
        notify(src, 'Le démontage a été interrompu : vous ou le véhicule avez bougé.')
        return
    end

    if wheelAlreadyStolen(netId, wheel) then
        pendingSteals[src] = nil
        notify(src, 'Ce pneu a déjà été démonté.', 'warning')
        return
    end

    pendingSteals[src] = nil
    stolen[tostring(netId)] = stolen[tostring(netId)] or {}
    stolen[tostring(netId)][wheel] = true

    local reward = chooseLoot()
    local count = math.random(reward.min, reward.max)
    if not exports['rp_inventory']:AddItem(src, reward.item, count) then
        stolen[tostring(netId)][wheel] = nil
        notify(src, 'Inventaire plein : aucun objet récupéré.')
        return
    end

    TriggerClientEvent('rp_vehicle_loot:client:success', -1, netId, wheel)
    notify(src, ('Butin récupéré : %s x%d.'):format(reward.item, count), 'success')
end)

AddEventHandler('playerDropped', function()
    pendingSteals[source] = nil
end)

AddEventHandler('entityRemoved', function(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId > 0 then
        stolen[tostring(netId)] = nil
        for src, pending in pairs(pendingSteals) do
            if pending.netId == netId then pendingSteals[src] = nil end
        end
    end
end)
