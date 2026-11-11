local stolen = {}
local loot = {
    { item = 'rubber', min = 1, max = 3, weight = 35 },
    { item = 'scrap_metal', min = 1, max = 3, weight = 30 },
    { item = 'copper_wire', min = 1, max = 2, weight = 18 },
    { item = 'electronic_parts', min = 1, max = 2, weight = 12 },
    { item = 'car_battery', min = 1, max = 1, weight = 5 }
}
local function chooseLoot()
    local roll, total = math.random(1, 100), 0
    for _, entry in ipairs(loot) do total = total + entry.weight; if roll <= total then return entry end end
    return loot[1]
end

RegisterNetEvent('rp_vehicle_loot:server:stealTire', function(rawNetId, rawWheel)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'vehicle:steal_tire', 12000) then return end
    local netId, wheel = tonumber(rawNetId), tonumber(rawWheel)
    if not netId or netId < 1 or not wheel or wheel % 1 ~= 0 or wheel < 0 or wheel > 3 then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(src)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if GetEntitySpeed(vehicle) > 0.5 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 4.0 then
        TriggerClientEvent('rp_core:client:notify', src, 'Le véhicule doit être immobilisé et à proximité.', 'error'); return
    end
    for _, rawId in ipairs(GetPlayers()) do
        local otherPed = GetPlayerPed(tonumber(rawId))
        if otherPed ~= 0 and GetVehiclePedIsIn(otherPed, false) == vehicle then
            TriggerClientEvent('rp_core:client:notify', src, 'Impossible de démonter un pneu avec quelqu’un dans le véhicule.', 'error'); return
        end
    end
    local key = tostring(netId)
    stolen[key] = stolen[key] or {}
    if stolen[key][wheel] then
        TriggerClientEvent('rp_core:client:notify', src, 'Ce pneu a déjà été démonté.', 'warning'); return
    end
    stolen[key][wheel] = true
    local reward = chooseLoot()
    local count = math.random(reward.min, reward.max)
    if not exports['rp_inventory']:AddItem(src, reward.item, count) then
        stolen[key][wheel] = nil
        TriggerClientEvent('rp_core:client:notify', src, 'Inventaire plein : aucun objet récupéré.', 'error'); return
    end
    TriggerClientEvent('rp_vehicle_loot:client:success', -1, netId, wheel)
    TriggerClientEvent('rp_core:client:notify', src, ('Butin récupéré : %s x%d.'):format(reward.item, count), 'success')
end)

AddEventHandler('entityRemoved', function(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId then stolen[tostring(netId)] = nil end
end)
