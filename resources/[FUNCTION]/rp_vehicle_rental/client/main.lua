local rentalPeds = {}
local rentalTablets = {}
local activeRental = nil
local tabletOpen = false
local promptVisible = false

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

local function loadModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function createRentalPeds()
    local hash = loadModel(Config.PedModel)
    local tabletHash = loadModel('prop_cs_tablet')
    if not hash or not tabletHash then
        print('[rp_vehicle_rental] Impossible de charger le modèle du PNJ.')
        return
    end
    for key, location in pairs(Config.Locations) do
        local p = location.ped
        local ped = CreatePed(4, hash, p.x, p.y, p.z - 1.0, p.w, false, true)
        if ped and ped ~= 0 then
            SetEntityAsMissionEntity(ped, true, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedCanRagdoll(ped, false)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
            local tablet = CreateObject(tabletHash, p.x, p.y, p.z, false, false, false)
            if tablet and tablet ~= 0 then
                SetEntityCollision(tablet, false, false)
                AttachEntityToEntity(tablet, ped, GetPedBoneIndex(ped, 57005),
                    0.12, 0.02, -0.02, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
                rentalTablets[key] = tablet
            end
            rentalPeds[key] = ped
        end
    end
    SetModelAsNoLongerNeeded(hash)
    SetModelAsNoLongerNeeded(tabletHash)
end

local function drawTimer(seconds)
    local minutes = math.floor(math.max(0, seconds) / 60)
    local remaining = math.max(0, seconds) % 60
    local text = ('LOCATION  %02d:%02d'):format(minutes, remaining)
    DrawRect(0.91, 0.955, 0.14, 0.035, 8, 13, 22, 185)
    SetTextFont(4)
    SetTextScale(0.34, 0.34)
    SetTextColour(255, 255, 255, 245)
    SetTextOutline()
    SetTextRightJustify(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.975, 0.94)
end

local function openTablet(isRenewal, vehicles, price, maxHours, label, locationKey)
    if tabletOpen then return end
    tabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        renewal = isRenewal == true,
        vehicles = vehicles or {},
        price = price or Config.PricePerTenMinutes,
        maxHours = maxHours or Config.MaxHours,
        vehicleLabel = label or '',
        location = locationKey
    })
end

RegisterNetEvent('rp_vehicle_rental:client:openTablet', function(isRenewal, vehicles, price, maxHours, label, locationKey)
    openTablet(isRenewal, vehicles, price, maxHours, label, locationKey)
end)

RegisterNetEvent('rp_vehicle_rental:client:spawnRental', function(data)
    local hash = loadModel(data.model)
    if not hash then
        TriggerServerEvent('rp_vehicle_rental:server:spawnFailed')
        notify('Le véhicule n’a pas pu être chargé. Contactez un membre du staff.', 'error')
        return
    end
    local p = data.location
    local vehicle = CreateVehicle(hash, p.x, p.y, p.z, p.w, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        TriggerServerEvent('rp_vehicle_rental:server:spawnFailed')
        notify('Impossible de sortir le véhicule de location.', 'error')
        return
    end
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleDoorsLocked(vehicle, 1)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    activeRental = {
        vehicle = vehicle,
        netId = netId,
        expiresAt = GetGameTimer() + (tonumber(data.minutes) or 60) * 60000
    }
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('rp_vehicle_rental:server:registerVehicle', netId)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
end)

RegisterNetEvent('rp_vehicle_rental:client:renewalRequired', function(graceSeconds, label, price, maxHours)
    if not activeRental then
        TriggerServerEvent('rp_vehicle_rental:server:decline')
        return
    end
    activeRental.graceUntil = GetGameTimer() + (tonumber(graceSeconds) or 60) * 1000
    openTablet(true, {}, price, maxHours, label, nil)
    notify('Votre location est terminée. Prolongez ou rendez le véhicule dans le délai affiché.', 'warning')
end)

RegisterNetEvent('rp_vehicle_rental:client:renewed', function(expiresAt, minutes)
    if activeRental then
        activeRental.expiresAt = GetGameTimer() + (tonumber(minutes) or 60) * 60000
        activeRental.graceUntil = nil
    end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

RegisterNetEvent('rp_vehicle_rental:client:forceReturn', function(netId, reason)
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    local vehicle = activeRental and activeRental.vehicle or (netId and NetToVeh(netId))
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local ped = PlayerPedId()
        if IsPedInVehicle(ped, vehicle, false) then
            TaskLeaveVehicle(ped, vehicle, 16)
            local deadline = GetGameTimer() + 5000
            while IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do Wait(50) end
        end
        local controlDeadline = GetGameTimer() + 2500
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < controlDeadline do
            NetworkRequestControlOfEntity(vehicle)
            Wait(50)
        end
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)
        SetVehicleEngineOn(vehicle, false, true, true)
    end
    activeRental = nil
    notify(reason or 'Location terminée. Le véhicule a été verrouillé.', 'warning')
end)

RegisterNUICallback('rent', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('rp_vehicle_rental:server:rent', data.location, data.model, tonumber(data.minutes))
    end
    cb({ ok = true })
end)

RegisterNUICallback('renew', function(data, cb)
    TriggerServerEvent('rp_vehicle_rental:server:renew', tonumber(data.minutes))
    cb({ ok = true })
end)

RegisterNUICallback('decline', function(data, cb)
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('rp_vehicle_rental:server:decline')
    cb({ ok = true })
end)

RegisterNUICallback('close', function(data, cb)
    if activeRental and activeRental.graceUntil then
        TriggerServerEvent('rp_vehicle_rental:server:decline')
    end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb({ ok = true })
end)

CreateThread(function()
    Wait(1000)
    createRentalPeds()
    local currentLocation = nil
    while true do
        local waitTime = 800
        if not tabletOpen and not activeRental then
            local coords = GetEntityCoords(PlayerPedId())
            local nearestKey, nearestDistance
            for key, location in pairs(Config.Locations) do
                local p = location.ped
                local distance = #(coords - vector3(p.x, p.y, p.z))
                if distance < (nearestDistance or 2.0) then
                    nearestKey, nearestDistance = key, distance
                end
            end
            if nearestKey and nearestDistance <= Config.InteractionDistance then
                waitTime = 0
                if not promptVisible or currentLocation ~= nearestKey then
                    exports['rp_ui']:ShowTextUI('[E] Louer un véhicule')
                    promptVisible = true
                    currentLocation = nearestKey
                end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('rp_vehicle_rental:server:openTablet', nearestKey)
                end
            elseif promptVisible then
                exports['rp_ui']:HideTextUI()
                promptVisible = false
                currentLocation = nil
            end
        elseif promptVisible then
            exports['rp_ui']:HideTextUI()
            promptVisible = false
        end
        Wait(waitTime)
    end
end)

CreateThread(function()
    while true do
        if activeRental then
            local remaining = math.ceil(((activeRental.expiresAt or GetGameTimer()) - GetGameTimer()) / 1000)
            if remaining > 0 then
                drawTimer(remaining)
                Wait(0)
            elseif activeRental.graceUntil and GetGameTimer() < activeRental.graceUntil then
                Wait(250)
            else
                -- The server owns the final expiry decision; keep the display responsive.
                drawTimer(0)
                Wait(250)
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if promptVisible then exports['rp_ui']:HideTextUI() end
    for _, tablet in pairs(rentalTablets) do
        if DoesEntityExist(tablet) then DeleteEntity(tablet) end
    end
    for _, ped in pairs(rentalPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
