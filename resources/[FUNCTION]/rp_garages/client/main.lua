local garageBlips = {}
local promptVisible = false
local tabletOpen = false
local currentGarage = nil
local garageOpening = nil
local pendingVehicle = nil
local tuningOpen = false
local tuningVehicle = nil
local tuningOriginal = {}

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

local function hidePrompt()
    if promptVisible then
        exports['rp_ui']:HideTextUI()
        promptVisible = false
    end
end

local function closeGarage()
    if not tabletOpen then return end
    tabletOpen = false
    currentGarage = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function captureVehicleProperties(vehicle)
    local props = {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        primaryColor = 0,
        secondaryColor = 0,
        pearlescentColor = 0,
        wheelColor = 0,
        wheelType = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        mods = {},
        neonEnabled = {},
        turbo = IsToggleModOn(vehicle, 18),
        xenon = IsToggleModOn(vehicle, 22),
        neonColor = {}
    }

    local primary, secondary = GetVehicleColours(vehicle)
    props.primaryColor, props.secondaryColor = primary, secondary
    props.pearlescentColor, props.wheelColor = GetVehicleExtraColours(vehicle)
    for modType = 0, 49 do props.mods[tostring(modType)] = GetVehicleMod(vehicle, modType) end
    for i = 0, 3 do props.neonEnabled[i + 1] = IsVehicleNeonLightEnabled(vehicle, i) end
    local nr, ng, nb = GetVehicleNeonLightsColour(vehicle)
    props.neonColor = { nr, ng, nb }
    if GetIsVehiclePrimaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
        props.customPrimaryColor = { r, g, b }
    end
    if GetIsVehicleSecondaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
        props.customSecondaryColor = { r, g, b }
    end
    props.livery = GetVehicleLivery(vehicle)
    props.modLivery = GetVehicleMod(vehicle, 48)
    return props
end

local function applyVehicleProperties(vehicle, props)
    if type(props) ~= 'table' then return end
    SetVehicleModKit(vehicle, 0)
    SetVehicleEngineHealth(vehicle, tonumber(props.engineHealth) or 1000.0)
    SetVehicleBodyHealth(vehicle, tonumber(props.bodyHealth) or 1000.0)
    SetVehicleFuelLevel(vehicle, tonumber(props.fuelLevel) or 100.0)
    SetVehicleDirtLevel(vehicle, tonumber(props.dirtLevel) or 0.0)
    SetVehicleWheelType(vehicle, tonumber(props.wheelType) or 0)
    SetVehicleWindowTint(vehicle, tonumber(props.windowTint) or 0)
    SetVehicleNumberPlateTextIndex(vehicle, tonumber(props.plateIndex) or 0)
    SetVehicleColours(vehicle, tonumber(props.primaryColor) or 0, tonumber(props.secondaryColor) or 0)
    SetVehicleExtraColours(vehicle, tonumber(props.pearlescentColor) or 0, tonumber(props.wheelColor) or 0)

    if type(props.mods) == 'table' then
        for key, value in pairs(props.mods) do
            local modType, modIndex = tonumber(key), tonumber(value)
            if modType and modType >= 0 and modType <= 49 and modIndex then
                SetVehicleMod(vehicle, modType, modIndex, false)
            end
        end
    end
    ToggleVehicleMod(vehicle, 18, props.turbo == true)
    ToggleVehicleMod(vehicle, 22, props.xenon == true)
    if type(props.neonEnabled) == 'table' then
        for i = 0, 3 do SetVehicleNeonLightEnabled(vehicle, i, props.neonEnabled[i + 1] == true) end
    end
    if type(props.neonColor) == 'table' then
        SetVehicleNeonLightsColour(vehicle, tonumber(props.neonColor[1]) or 255,
            tonumber(props.neonColor[2]) or 255, tonumber(props.neonColor[3]) or 255)
    end
    if type(props.customPrimaryColor) == 'table' and #props.customPrimaryColor == 3 then
        SetVehicleCustomPrimaryColour(vehicle, props.customPrimaryColor[1], props.customPrimaryColor[2], props.customPrimaryColor[3])
    end
    if type(props.customSecondaryColor) == 'table' and #props.customSecondaryColor == 3 then
        SetVehicleCustomSecondaryColour(vehicle, props.customSecondaryColor[1], props.customSecondaryColor[2], props.customSecondaryColor[3])
    end
    if tonumber(props.livery) and tonumber(props.livery) >= 0 then SetVehicleLivery(vehicle, tonumber(props.livery)) end
    if tonumber(props.modLivery) then SetVehicleMod(vehicle, 48, tonumber(props.modLivery), false) end
end

local function applyTuningOption(vehicle, modType, modIndex)
    local category = Config.TuningCategories[modType]
    if not category then return false end
    if category.toggle then
        ToggleVehicleMod(vehicle, modType, modIndex == 1)
    else
        SetVehicleModKit(vehicle, 0)
        SetVehicleMod(vehicle, modType, modIndex, false)
    end
    return true
end

local function restoreTuningPreview()
    if tuningVehicle and DoesEntityExist(tuningVehicle) then
        for modType, originalIndex in pairs(tuningOriginal) do
            applyTuningOption(tuningVehicle, tonumber(modType), originalIndex)
        end
    end
end

local function closeTuning()
    if not tuningOpen then return end
    restoreTuningPreview()
    tuningOpen = false
    tuningVehicle = nil
    tuningOriginal = {}
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeTuning' })
end

RegisterNetEvent('rp_garages:client:openTuning', function(data)
    if type(data) ~= 'table' then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or NetworkGetNetworkIdFromEntity(vehicle) ~= tonumber(data.netId) then
        notify('Remonte au volant de ton véhicule pour le personnaliser.', 'error')
        return
    end

    tuningVehicle = vehicle
    tuningOriginal = {}
    local categories = {}
    SetVehicleModKit(vehicle, 0)
    for modType, definition in pairs(Config.TuningCategories) do
        local count = definition.toggle and 2 or GetNumVehicleMods(vehicle, modType)
        if count and count > 0 then
            local current = definition.toggle and (IsToggleModOn(vehicle, modType) and 1 or 0) or GetVehicleMod(vehicle, modType)
            tuningOriginal[tostring(modType)] = current
            categories[#categories + 1] = {
                modType = modType,
                id = definition.id,
                label = definition.label,
                basePrice = definition.basePrice,
                maxIndex = definition.toggle and 1 or math.min(count - 1, definition.maxIndex),
                current = definition.toggle and current or math.max(0, current),
                installedIndex = current,
                toggle = definition.toggle == true
            }
        end
    end
    table.sort(categories, function(a, b) return a.modType < b.modType end)
    if #categories == 0 then
        notify('Aucune amélioration compatible sur ce véhicule.', 'warning')
        return
    end

    tuningOpen = true
    hidePrompt()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openTuning',
        workshop = data.workshop or 'Atelier mécanique',
        plate = data.plate or GetVehicleNumberPlateText(vehicle),
        categories = categories
    })
end)

RegisterNetEvent('rp_garages:client:applyPurchasedTune', function(modType, modIndex)
    modType, modIndex = tonumber(modType), tonumber(modIndex)
    if not tuningOpen or not tuningVehicle or not DoesEntityExist(tuningVehicle)
        or not applyTuningOption(tuningVehicle, modType, modIndex) then
        TriggerServerEvent('rp_garages:server:saveTune', 0, {})
        return
    end
    local props = captureVehicleProperties(tuningVehicle)
    TriggerServerEvent('rp_garages:server:saveTune',
        NetworkGetNetworkIdFromEntity(tuningVehicle), props)
end)

RegisterNetEvent('rp_garages:client:tuneSaved', function(modType, modIndex, price)
    modType, modIndex = tonumber(modType), tonumber(modIndex)
    if modType then tuningOriginal[tostring(modType)] = modIndex end
    SendNUIMessage({ action = 'tuneSaved', modType = modType, modIndex = modIndex })
    notify(('Amélioration installée et sauvegardée : %s $.'):format(tonumber(price) or 0), 'success')
end)

RegisterNetEvent('rp_garages:client:tuneRollback', function(modType, originalIndex, message)
    modType, originalIndex = tonumber(modType), tonumber(originalIndex) or -1
    if tuningVehicle and DoesEntityExist(tuningVehicle) then
        applyTuningOption(tuningVehicle, modType, originalIndex)
    end
    if modType then tuningOriginal[tostring(modType)] = originalIndex end
    SendNUIMessage({ action = 'tuneRollback', modType = modType, modIndex = originalIndex })
    notify(message or 'La personnalisation a été annulée.', 'error')
end)

local function createBlips()
    for _, garage in ipairs(Config.Garages) do
        if garage.blip and garage.blip.enabled then
            local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
            SetBlipSprite(blip, garage.blip.sprite or 357)
            SetBlipColour(blip, garage.blip.colour or 3)
            SetBlipScale(blip, garage.blip.scale or 0.72)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Garage personnel')
            EndTextCommandSetBlipName(blip)
            garageBlips[#garageBlips + 1] = blip
        end
    end
end

RegisterNetEvent('rp_garages:client:open', function(payload)
    garageOpening = nil
    if type(payload) ~= 'table' then return end
    hidePrompt()
    tabletOpen = true
    currentGarage = payload.garage
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        garage = payload.label or 'Garage personnel',
        vehicles = payload.vehicles or {},
        currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false) ~= 0
    })
end)

RegisterNetEvent('rp_garages:client:stored', function(plate)
    notify(('Véhicule %s rangé et sauvegardé.'):format(plate or ''), 'success')
    if tabletOpen and currentGarage then TriggerServerEvent('rp_garages:server:open', currentGarage) end
end)

RegisterNetEvent('rp_garages:client:spawn', function(data)
    if type(data) ~= 'table' or type(data.model) ~= 'string' or type(data.spawn) ~= 'table' then
        if type(data) == 'table' then TriggerServerEvent('rp_garages:server:spawnFailed', data.vehicleId) end
        return
    end

    local hash = joaat(data.model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) or not IsModelAVehicle(hash) then
        TriggerServerEvent('rp_garages:server:spawnFailed', data.vehicleId)
        notify('Modèle de véhicule invalide : contacte un administrateur.', 'error')
        return
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 12000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then
        TriggerServerEvent('rp_garages:server:spawnFailed', data.vehicleId)
        notify('Le modèle du véhicule n’a pas pu être chargé.', 'error')
        return
    end

    local spawn = data.spawn
    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        TriggerServerEvent('rp_garages:server:spawnFailed', data.vehicleId)
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, data.plate)
    applyVehicleProperties(vehicle, data.props)
    SetVehicleNumberPlateText(vehicle, data.plate)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, false, true, true)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    pendingVehicle = vehicle
    TriggerServerEvent('rp_garages:server:spawned', netId, data.vehicleId)
end)

RegisterNetEvent('rp_garages:client:spawnConfirmed', function()
    if pendingVehicle and DoesEntityExist(pendingVehicle) then
        TaskWarpPedIntoVehicle(PlayerPedId(), pendingVehicle, -1)
        SetVehicleEngineOn(pendingVehicle, true, true, false)
        notify('Véhicule sorti du garage.', 'success')
    end
    pendingVehicle = nil
    closeGarage()
end)

RegisterNetEvent('rp_garages:client:spawnFailed', function(message)
    if pendingVehicle and DoesEntityExist(pendingVehicle) then DeleteEntity(pendingVehicle) end
    pendingVehicle = nil
    notify(message or 'La sortie du véhicule a échoué.', 'error')
end)

RegisterNUICallback('close', function(_, cb)
    closeGarage()
    cb({ ok = true })
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    if currentGarage and type(data) == 'table' then
        TriggerServerEvent('rp_garages:server:retrieve', currentGarage, data.vehicleId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('previewTune', function(data, cb)
    local modType = type(data) == 'table' and tonumber(data.modType)
    local modIndex = type(data) == 'table' and tonumber(data.modIndex)
    if tuningOpen and tuningVehicle and DoesEntityExist(tuningVehicle)
        and modType and modIndex and Config.TuningCategories[modType] then
        applyTuningOption(tuningVehicle, modType, modIndex)
    end
    cb({ ok = true })
end)

RegisterNUICallback('buyTune', function(data, cb)
    local modType = type(data) == 'table' and tonumber(data.modType)
    local modIndex = type(data) == 'table' and tonumber(data.modIndex)
    local originalIndex = modType and tuningOriginal[tostring(modType)]
    if tuningOpen and tuningVehicle and DoesEntityExist(tuningVehicle)
        and modType and modIndex and originalIndex ~= nil then
        TriggerServerEvent('rp_garages:server:purchaseUpgrade',
            NetworkGetNetworkIdFromEntity(tuningVehicle), modType, modIndex, originalIndex)
        cb({ ok = true })
    else
        cb({ ok = false })
    end
end)

RegisterNUICallback('closeTuning', function(_, cb)
    closeTuning()
    cb({ ok = true })
end)

RegisterNUICallback('storeVehicle', function(_, cb)
    if not currentGarage then cb({ ok = false }); return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify('Tu dois être au volant du véhicule à ranger.', 'error')
        cb({ ok = false })
        return
    end
    local props = captureVehicleProperties(vehicle)
    TriggerServerEvent('rp_garages:server:store', currentGarage, NetworkGetNetworkIdFromEntity(vehicle), props)
    cb({ ok = true })
end)

CreateThread(function()
    local visible = false
    while true do
        local sleep = 700
        if not tuningOpen and not tabletOpen and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, distance
            for _, workshop in ipairs(Config.Workshops or {}) do
                local current = #(coords - workshop.coords)
                if current < (distance or Config.InteractionDistance + 1.0) then
                    nearest, distance = workshop, current
                end
            end
            if nearest and distance <= Config.InteractionDistance then
                sleep = 0
                if not visible then
                    exports['rp_ui']:ShowTextUI('[E] Personnaliser mon véhicule')
                    visible = true
                end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('rp_garages:server:openWorkshop')
                end
            elseif visible then
                exports['rp_ui']:HideTextUI()
                visible = false
            end
        elseif visible then
            exports['rp_ui']:HideTextUI()
            visible = false
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    createBlips()
    while true do
        local sleep = 700
        if tabletOpen then
            local activeGarage
            for _, garage in ipairs(Config.Garages) do
                if garage.id == currentGarage then activeGarage = garage; break end
            end
            if not activeGarage or #(GetEntityCoords(PlayerPedId()) - activeGarage.coords) > Config.ServerInteractionDistance then
                closeGarage()
                notify('Garage fermé : tu as quitté la zone.', 'info')
            end
            hidePrompt()
            sleep = 250
        elseif tuningOpen then
            hidePrompt()
            sleep = 250
        elseif not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, distance
            for _, garage in ipairs(Config.Garages) do
                local current = #(coords - garage.coords)
                if current < (distance or Config.InteractionDistance + 1.0) then
                    nearest, distance = garage, current
                end
            end
            if nearest and distance <= Config.InteractionDistance then
                sleep = 0
                if not promptVisible then
                    exports['rp_ui']:ShowTextUI('[E] Ouvrir le garage personnel')
                    promptVisible = true
                end
                if IsControlJustReleased(0, 38) and not garageOpening then
                    garageOpening = nearest.id
                    TriggerServerEvent('rp_garages:server:open', nearest.id)
                    SetTimeout(5000, function()
                        if garageOpening == nearest.id then
                            garageOpening = nil
                            notify('Le garage ne répond pas.', 'error')
                        end
                    end)
                end
            else
                hidePrompt()
            end
        else
            hidePrompt()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeGarage()
    closeTuning()
    hidePrompt()
    for _, blip in ipairs(garageBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    if pendingVehicle and DoesEntityExist(pendingVehicle) then DeleteEntity(pendingVehicle) end
end)
