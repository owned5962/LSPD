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

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    local stations = {}
    for _, location in ipairs(locations) do
        if location.location_type == 'gas_station' then
            stations[#stations + 1] = {
                x = tonumber(location.x), y = tonumber(location.y), z = tonumber(location.z)
            }
        end
    end
    if #stations > 0 then FuelConfig.Stations = stations end
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
    'prop_gas_pump_old3'
}

local PumpModelHashes = {}
for _, model in ipairs(PumpModels) do
    PumpModelHashes[#PumpModelHashes + 1] = joaat(model)
end

local function nearestPump(coords)
    local best, bestDistance
    for _, modelHash in ipairs(PumpModelHashes) do
        local pump = GetClosestObjectOfType(
            coords.x, coords.y, coords.z, 2.25, modelHash, false, false, false
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

    local currentFuel = math.max(0, math.min(100, GetVehicleFuelLevel(vehicle)))
    Entity(vehicle).state:set('rpFuel', currentFuel, true)
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
    TriggerServerEvent('rp_fuel:server:purchase', currentNetId, litres, payment,
        GetVehicleFuelLevel(currentVehicle))
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
        Entity(vehicle).state:set('rpFuel', tonumber(fuel) or 100.0, true)
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
    local lastFuelTick = GetGameTimer()
    local lastStateSync = 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and not isRefueling then
            local now = GetGameTimer()
            local elapsed = math.max(0, math.min(5000, now - lastFuelTick)) / 1000.0
            lastFuelTick = now
            local fuel = math.max(0.0, GetVehicleFuelLevel(vehicle))
            local consumption = GetEntitySpeed(vehicle) * 0.00022 * elapsed
            if consumption > 0 and fuel > 0 then
                SetVehicleFuelLevel(vehicle, math.max(0.0, fuel - consumption))
            end
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
        if not isOpen and not isRefueling then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local pump, pumpDistance = nearestPump(coords)
            if pump and pumpDistance and pumpDistance <= 2.0 then
                local vehicle = findVehicle(ped)
                local vehicleNearPump = vehicle ~= 0
                    and #(GetEntityCoords(vehicle) - GetEntityCoords(pump)) <= 12.0
                    and #(GetEntityCoords(vehicle) - coords) <= 15.0

                if vehicleNearPump then
                    waitTime = 0
                    exports['rp_ui']:ShowTextUI('[E] Faire le plein · '
                        .. math.floor(GetVehicleFuelLevel(vehicle)) .. '%')
                    prompt = true
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
