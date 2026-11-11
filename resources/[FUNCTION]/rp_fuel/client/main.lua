local isOpen = false
local currentVehicle = 0
local currentNetId = 0
local PRICE_PER_LITRE = 6

local Stations = {
    { x = -724.6, y = -935.2, z = 8.9 }, { x = -70.2, y = -1761.8, z = 29.5 },
    { x = 265.0, y = -1261.3, z = 29.3 }, { x = 819.6, y = -1028.2, z = 26.4 },
    { x = 1208.3, y = -1402.3, z = 35.2 }, { x = 1181.4, y = -330.8, z = 69.3 },
    { x = 620.8, y = 269.1, z = 103.0 }, { x = 2581.0, y = 362.0, z = 108.5 },
    { x = 2005.0, y = 3774.0, z = 32.2 }, { x = 1687.2, y = 4929.2, z = 42.1 },
    { x = 1701.3, y = 6416.0, z = 32.8 }, { x = 179.9, y = 6602.8, z = 31.9 },
    { x = -2555.5, y = 2334.0, z = 33.1 }, { x = -2096.2, y = -320.3, z = 13.2 },
    { x = -1437.6, y = -276.7, z = 46.2 }, { x = -1800.1, y = 803.5, z = 138.5 }
}

CreateThread(function()
    for _, station in ipairs(Stations) do
        local blip = AddBlipForCoord(station.x, station.y, station.z)
        SetBlipSprite(blip, 361); SetBlipDisplay(blip, 4); SetBlipScale(blip, 0.65)
        SetBlipColour(blip, 5); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Station-service'); EndTextCommandSetBlipName(blip)
    end
end)

local function nearestStation(coords, radius)
    local best, bestDistance
    for _, station in ipairs(Stations) do
        local distance = #(coords - vector3(station.x, station.y, station.z))
        if distance <= radius and (not bestDistance or distance < bestDistance) then best, bestDistance = station, distance end
    end
    return best, bestDistance
end

local function findVehicle(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 12.0, 0, 70)
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    return vehicle
end

local function openFuelUI(vehicle)
    if isOpen or vehicle == 0 then return end
    currentVehicle = vehicle
    currentNetId = NetworkGetNetworkIdFromEntity(vehicle)
    if currentNetId == 0 then
        TriggerEvent('rp_core:client:notify', 'Véhicule non synchronisé. Réessayez.', 'error')
        return
    end
    local currentFuel = math.max(0, math.min(100, GetVehicleFuelLevel(vehicle)))
    Entity(vehicle).state:set('rpFuel', currentFuel, true)
    isOpen = true
    exports['rp_ui']:HideTextUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openFuel',
        fuel = math.floor(currentFuel + 0.5),
        maxLitres = math.max(0, math.floor(100 - currentFuel)),
        price = PRICE_PER_LITRE,
        vehicle = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    })
end

local function closeFuelUI()
    isOpen = false
    currentVehicle = 0
    currentNetId = 0
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeFuel' })
end

RegisterNUICallback('close', function(_, cb) closeFuelUI(); cb({ ok = true }) end)
RegisterNUICallback('purchase', function(data, cb)
    local litres = tonumber(data.litres)
    if not isOpen or not litres or litres % 1 ~= 0 or litres < 1 or litres > 100 then
        cb({ ok = false }); return
    end
    TriggerServerEvent('rp_fuel:server:purchase', currentNetId, litres, data.payment, GetVehicleFuelLevel(currentVehicle))
    cb({ ok = true })
end)

RegisterNetEvent('rp_fuel:client:purchaseResult', function(success, message, netId, fuel)
    if success and tonumber(netId) == currentNetId then
        local vehicle = NetworkGetEntityFromNetworkId(currentNetId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then SetVehicleFuelLevel(vehicle, tonumber(fuel) or 100.0) end
        SendNUIMessage({ action = 'fuelPurchased', fuel = fuel, message = message })
        TriggerEvent('rp_core:client:notify', message, 'success')
        closeFuelUI()
    else
        TriggerEvent('rp_core:client:notify', message or 'Paiement refusé.', 'error')
    end
end)

RegisterNetEvent('rp_fuel:client:setFuel', function(netId, fuel)
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then SetVehicleFuelLevel(vehicle, tonumber(fuel) or 100.0) end
end)

CreateThread(function()
    local lastFuelTick = GetGameTimer()
    local lastStateSync = 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local now = GetGameTimer()
            local elapsed = math.max(0, math.min(5000, now - lastFuelTick)) / 1000.0
            lastFuelTick = now
            local fuel = math.max(0.0, GetVehicleFuelLevel(vehicle))
            local consumption = GetEntitySpeed(vehicle) * 0.00022 * elapsed
            if consumption > 0 and fuel > 0 then SetVehicleFuelLevel(vehicle, math.max(0.0, fuel - consumption)) end
            if now - lastStateSync >= 5000 then
                Entity(vehicle).state:set('rpFuel', GetVehicleFuelLevel(vehicle), true)
                lastStateSync = now
            end
        else
            lastFuelTick = GetGameTimer()
        end
    end
end)

CreateThread(function()
    local prompt = false
    while true do
        local waitTime = 700
        if not isOpen then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local station = nearestStation(coords, 18.0)
            if station then
                local vehicle = findVehicle(ped)
                if vehicle ~= 0 and #(GetEntityCoords(vehicle) - coords) <= 15.0 then
                    waitTime = 250
                    exports['rp_ui']:ShowTextUI('[E] Faire le plein · ' .. math.floor(GetVehicleFuelLevel(vehicle)) .. '%')
                    prompt = true
                    if IsControlJustReleased(0, 38) then openFuelUI(vehicle); prompt = false end
                elseif prompt then
                    exports['rp_ui']:HideTextUI(); prompt = false
                end
            elseif prompt then
                exports['rp_ui']:HideTextUI(); prompt = false
            end
        else
            waitTime = 500
        end
        Wait(waitTime)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    exports['rp_ui']:HideTextUI()
end)
