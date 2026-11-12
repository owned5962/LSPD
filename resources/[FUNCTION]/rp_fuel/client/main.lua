local isOpen = false
local isRefueling = false
local isPurchasePending = false
local currentVehicle = 0
local currentNetId = 0
local previousEngineState = false
local createdBlips = {}

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

RegisterNetEvent('rp_fuel:client:settings', function(price, consumptionMultiplier)
    FuelConfig.PricePerLitre = math.max(1, math.min(1000, tonumber(price) or FuelConfig.PricePerLitre or 6))
    FuelConfig.ConsumptionMultiplier = math.max(0.1, math.min(20.0, tonumber(consumptionMultiplier) or FuelConfig.ConsumptionMultiplier or 2.5))
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('rp_fuel:server:requestSettings')
end)

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    local stations = {}
    local function addStation(x, y, z)
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        if not x or not y or not z then return end
        for _, existing in ipairs(stations) do
            if #(vector3(existing.x, existing.y, existing.z) - vector3(x, y, z)) < 2.0 then
                return
            end
        end
        stations[#stations + 1] = { x = x, y = y, z = z }
    end

    -- Keep every configured vanilla station, then merge any additional SQL
    -- locations without replacing the base list with a partial database result.
    for _, station in ipairs(FuelConfig.Stations or {}) do
        addStation(station.x, station.y, station.z)
    end
    for _, location in ipairs(locations) do
        if location.location_type == 'gas_station' then
            addStation(location.x, location.y, location.z)
        end
    end
    FuelConfig.Stations = stations
end)

local function nearestStation(coords, radius)
    local best, bestDistance
    for _, station in ipairs(FuelConfig.Stations) do
        local distance = #(coords - vector3(station.x, station.y, station.z))
        if distance <= radius and (not bestDistance or distance < bestDistance) then
            best, bestDistance = station, distance
        end
    end
    return best, bestDistance
end

-- GTA V pump props used across the vanilla and older gas stations.
local PumpModels = {
    'prop_gas_pump_1a',
    'prop_gas_pump_1b',
    'prop_gas_pump_1c',
    'prop_gas_pump_1d',
    'prop_vintage_pump',
    'prop_gas_pump_old2',
    'prop_gas_pump_old3',
    'prop_gas_pump_old4'
}

local PumpModelHashes = {}
for _, model in ipairs(PumpModels) do
    PumpModelHashes[#PumpModelHashes + 1] = joaat(model)
end

local function nearestPump(coords, searchRadius)
    searchRadius = tonumber(searchRadius) or 4.5
    local best, bestDistance
    for _, modelHash in ipairs(PumpModelHashes) do
        local pump = GetClosestObjectOfType(
            coords.x, coords.y, coords.z, searchRadius, modelHash, false, false, false
        )
        if pump ~= 0 and DoesEntityExist(pump) then
            local pumpCoords = GetEntityCoords(pump)
            -- Ignore decorative or unrelated pump props outside registered stations.
            if nearestStation(pumpCoords, FuelConfig.StationRadius) then
                local distance = #(coords - pumpCoords)
                if not bestDistance or distance < bestDistance then
                    best, bestDistance = pump, distance
                end
            end
        end
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

local function setVehicleAfterRefuel(restoreEngine)
    if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) then
        FreezeEntityPosition(currentVehicle, false)
        if restoreEngine then
            SetVehicleEngineOn(currentVehicle, previousEngineState, true, true)
        end
    end
    isRefueling = false
end

local function closeFuelUI()
    if isRefueling then return end
    isOpen = false
    isPurchasePending = false
    currentVehicle = 0
    currentNetId = 0
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeFuel' })
end

local function openFuelUI(vehicle)
    if isOpen or isRefueling or vehicle == 0 then return end
    if not NetworkGetEntityIsNetworked(vehicle) then
        notify('Ce véhicule ne possède pas encore de réseau. Réessayez.', 'error')
        return
    end

    currentVehicle = vehicle
    currentNetId = NetworkGetNetworkIdFromEntity(vehicle)
    if currentNetId == 0 then
        currentVehicle, currentNetId = 0, 0
        notify('Véhicule non synchronisé. Réessayez.', 'error')
        return
    end

    local currentFuel = tonumber(Entity(vehicle).state.rpFuel) or GetVehicleFuelLevel(vehicle)
    currentFuel = math.max(0, math.min(100, currentFuel))
    isOpen = true
    exports['rp_ui']:HideTextUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openFuel',
        fuel = math.floor(currentFuel + 0.5),
        maxLitres = math.max(0, math.floor(100 - currentFuel)),
        price = FuelConfig.PricePerLitre,
        millisecondsPerLitre = FuelConfig.MillisecondsPerLitre,
        baseFillMilliseconds = FuelConfig.BaseFillMilliseconds,
        vehicle = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    })
end

RegisterNUICallback('close', function(_, cb)
    if isRefueling or isPurchasePending then
        cb({ ok = false, reason = 'refueling' })
        return
    end
    closeFuelUI()
    cb({ ok = true })
end)

RegisterNUICallback('purchase', function(data, cb)
    local litres = type(data) == 'table' and tonumber(data.litres) or nil
    local payment = type(data) == 'table' and data.payment or nil
    if not isOpen or isRefueling or currentVehicle == 0 or not DoesEntityExist(currentVehicle)
        or not litres or litres % 1 ~= 0 or litres < 1 or litres > 100 then
        cb({ ok = false })
        return
    end
    isPurchasePending = true
    TriggerServerEvent('rp_fuel:server:purchase', currentNetId, litres, payment)
    cb({ ok = true })
end)

RegisterNetEvent('rp_fuel:client:fuelingStarted', function(netId, durationMs, litres, amount, account)
    if not isOpen or tonumber(netId) ~= currentNetId or currentVehicle == 0
        or not DoesEntityExist(currentVehicle) then return end

    isPurchasePending = false
    isRefueling = true
    previousEngineState = GetIsVehicleEngineRunning(currentVehicle)
    SetVehicleEngineOn(currentVehicle, false, true, true)
    FreezeEntityPosition(currentVehicle, true)
    SendNUIMessage({
        action = 'fuelingStarted',
        durationMs = tonumber(durationMs) or 0,
        litres = tonumber(litres) or 0,
        amount = tonumber(amount) or 0,
        account = account == 'cash' and 'Espèces' or 'Compte bancaire'
    })
    notify('Ravitaillement commencé. Ne déplacez pas le véhicule.', 'info')
end)

RegisterNetEvent('rp_fuel:client:purchaseResult', function(success, message, netId, fuel)
    if not success then
        isPurchasePending = false
        if isRefueling then
            setVehicleAfterRefuel(true)
            SendNUIMessage({ action = 'fuelingCancelled', message = message or 'Ravitaillement annulé.' })
        else
            SendNUIMessage({ action = 'purchaseFailed', message = message or 'Paiement refusé.' })
        end
        notify(message or 'Paiement refusé.', 'error')
        return
    end
    if tonumber(netId) ~= currentNetId then return end
    isPurchasePending = false

    local vehicle = NetworkGetEntityFromNetworkId(currentNetId)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetVehicleFuelLevel(vehicle, tonumber(fuel) or 100.0)
    end
    setVehicleAfterRefuel(true)
    SendNUIMessage({ action = 'fuelPurchased', fuel = fuel, message = message })
    notify(message or 'Ravitaillement terminé.', 'success')
    SetTimeout(2500, function()
        if isOpen and not isRefueling then closeFuelUI() end
    end)
end)

RegisterNetEvent('rp_fuel:client:setFuel', function(netId, fuel)
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetVehicleFuelLevel(vehicle, tonumber(fuel) or 100.0)
    end
end)

CreateThread(function()
    -- The server simulates consumption and owns rpFuel. Clients only mirror the
    -- replicated value into the local vehicle native for the dashboard/gameplay.
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local serverFuel = tonumber(Entity(vehicle).state.rpFuel)
            if serverFuel and serverFuel >= 0 and serverFuel <= 100 then
                SetVehicleFuelLevel(vehicle, serverFuel)
            end
        end
    end
end)

CreateThread(function()
    local prompt = false
    while true do
        local waitTime = 700
        if not isOpen and not isRefueling then
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local vehicle = findVehicle(ped)
            local pump, pumpDistance = nearestPump(playerCoords, 1.0)

            -- When the player is seated, the ped position is the vehicle centre.
            -- Search from both positions so pumps on either side of the car work.
            if vehicle ~= 0 then
                local vehicleCoords = GetEntityCoords(vehicle)
                local vehiclePump, vehiclePumpDistance = nearestPump(vehicleCoords, 1.0)
                if vehiclePumpDistance and (not pumpDistance or vehiclePumpDistance < pumpDistance) then
                    pump, pumpDistance = vehiclePump, vehiclePumpDistance
                end
            end

            if pump and pumpDistance then
                local pumpCoords = GetEntityCoords(pump)
                local vehicleNearPump = vehicle ~= 0
                    and #(GetEntityCoords(vehicle) - pumpCoords) <= 8.0
                    and #(playerCoords - GetEntityCoords(vehicle)) <= FuelConfig.VehiclePlayerRadius

                if vehicleNearPump and #(playerCoords - pumpCoords) <= 1.0 then
                    waitTime = 0
                    if not prompt then
                        exports['rp_ui']:ShowTextUI('[E] Faire le plein · '
                            .. math.floor(GetVehicleFuelLevel(vehicle)) .. '%')
                        prompt = true
                    end
                    if IsControlJustReleased(0, 38) then
                        openFuelUI(vehicle)
                        prompt = false
                    end
                elseif prompt then
                    exports['rp_ui']:HideTextUI()
                    prompt = false
                end
            elseif prompt then
                exports['rp_ui']:HideTextUI()
                prompt = false
            end
        else
            waitTime = 500
            if prompt then
                exports['rp_ui']:HideTextUI()
                prompt = false
            end
        end
        Wait(waitTime)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    isOpen, isRefueling, isPurchasePending = false, false, false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeFuel' })
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isRefueling then setVehicleAfterRefuel(true) end
    SetNuiFocus(false, false)
    exports['rp_ui']:HideTextUI()
    for _, blip in ipairs(createdBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
