local isProgressActive = false
local isCharacterLoaded = false

-- Exports & Events for TextUI
function ShowTextUI(message, position)
    SendNUIMessage({
        action = 'showTextUI',
        text = message or '',
        position = position or 'right'
    })
end

function HideTextUI()
    SendNUIMessage({
        action = 'hideTextUI'
    })
end

exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)

RegisterNetEvent('rp_ui:showTextUI', ShowTextUI)
RegisterNetEvent('rp_ui:hideTextUI', HideTextUI)

-- Exports & Events for Progress Bar
function ProgressBar(data, cb)
    if isProgressActive then return end
    isProgressActive = true

    local duration = data.duration or 5000
    local label = data.label or 'Action en cours...'
    local canCancel = data.canCancel ~= false

    SendNUIMessage({
        action = 'startProgress',
        duration = duration,
        label = label,
        canCancel = canCancel
    })

    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local cancelled = false

        while GetGameTimer() - startTime < duration do
            Citizen.Wait(0)
            if canCancel and IsControlJustPressed(0, 73) then -- X key to cancel
                cancelled = true
                SendNUIMessage({ action = 'cancelProgress' })
                break
            end
        end

        isProgressActive = false
        if cb then
            cb(not cancelled)
        end
    end)
end

exports('ProgressBar', ProgressBar)
RegisterNetEvent('rp_ui:startProgress', function(duration, label)
    ProgressBar({ duration = duration, label = label })
end)


-- In-game status HUD. It becomes visible only after a character is loaded.
local function UpdatePlayerHUD()
    local ok, data = pcall(function() return exports['rp_core']:GetPlayerData() end)
    if not ok or type(data) ~= 'table' or not tonumber(data.charId) then
        isCharacterLoaded = false
        SendNUIMessage({ action = 'hideHUD' })
        SendNUIMessage({ action = 'hideVehicleHUD' })
        return false
    end
    isCharacterLoaded = true
    local ped = PlayerPedId()
    local maxHealth = math.max(1, GetEntityMaxHealth(ped) - 100)
    local health = math.max(0, math.min(100, ((GetEntityHealth(ped) - 100) / maxHealth) * 100))
    SendNUIMessage({
        action = 'updateHUD', visible = true,
        health = math.floor(health + 0.5),
        hunger = math.floor(math.max(0, math.min(100, tonumber(data.hunger) or 100)) + 0.5),
        thirst = math.floor(math.max(0, math.min(100, tonumber(data.thirst) or 100)) + 0.5),
        job = tostring(data.jobLabel or data.job or 'Sans-emploi'),
        grade = tostring(data.jobGradeLabel or '')
    })
    DisplayRadar(true)
    return true
end

RegisterNetEvent('rp_core:client:setPlayerData', function()
    CreateThread(function() Wait(100); UpdatePlayerHUD() end)
end)
RegisterNetEvent('rp_core:client:updateCash', function() UpdatePlayerHUD() end)
RegisterNetEvent('rp_core:client:updateBank', function() UpdatePlayerHUD() end)
RegisterNetEvent('rp_core:client:updateNeeds', function() UpdatePlayerHUD() end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'hideHUD' })
end)
AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'hideHUD' })
end)

-- Vehicle dashboard: speed is displayed in km/h and fuel comes from the vehicle native.
local VehicleClassLabels = {
    [0] = 'Compacte', [1] = 'Berline', [2] = 'SUV', [3] = 'Coupé',
    [4] = 'Muscle', [5] = 'Sport classique', [6] = 'Sportive',
    [7] = 'Super sportive', [8] = 'Moto', [9] = 'Tout-terrain',
    [10] = 'Industriel', [11] = 'Utilitaire', [12] = 'Van',
    [13] = 'Vélo', [14] = 'Bateau', [15] = 'Hélicoptère',
    [16] = 'Avion', [17] = 'Service', [18] = 'Urgence',
    [19] = 'Militaire', [20] = 'Commercial', [21] = 'Train'
}

local function GetVehicleHUDIdentity(vehicle)
    local vehicleType = VehicleClassLabels[GetVehicleClass(vehicle)] or 'Véhicule'
    local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local vehicleName = displayName and displayName ~= '' and displayName ~= 'CARNOTFOUND' and displayName ~= 'NULL'
        and GetLabelText(displayName) or vehicleType

    if not vehicleName or vehicleName == '' or vehicleName == 'NULL' then
        vehicleName = displayName and displayName ~= '' and displayName ~= 'CARNOTFOUND' and displayName or vehicleType
    end

    return vehicleType, vehicleName
end

CreateThread(function()
    local lastVehicle = 0
    local lastVehicleType, lastVehicleName = 'Véhicule', ''
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if isCharacterLoaded and vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            if vehicle ~= lastVehicle then
                lastVehicleType, lastVehicleName = GetVehicleHUDIdentity(vehicle)
            end
            local speed = math.floor(GetEntitySpeed(vehicle) * 3.6 + 0.5)
            local fuel = math.max(0, math.min(100, GetVehicleFuelLevel(vehicle)))
            local gear = GetVehicleCurrentGear(vehicle)
            SendNUIMessage({
                action = 'updateVehicleHUD', visible = true,
                speed = speed, fuel = fuel, gear = gear,
                vehicleType = lastVehicleType, vehicleName = lastVehicleName
            })
            lastVehicle = vehicle
            Wait(100)
        else
            if lastVehicle ~= 0 then SendNUIMessage({ action = 'hideVehicleHUD' }); lastVehicle = 0 end
            Wait(350)
        end
    end
end)

RegisterNetEvent('rp_ui:notify', function(message, kind, duration)
    SendNUIMessage({ action = 'notify', message = tostring(message or ''), kind = kind or 'info', duration = tonumber(duration) or 4000 })
end)

CreateThread(function()
    local lastVisible = false
    while true do
        local visible = UpdatePlayerHUD()
        if visible and not lastVisible then DisplayRadar(true) end
        lastVisible = visible
        Wait(500)
    end
end)


-- Remove GTA's native health/armour bars below the minimap. These bars are
-- rendered by the minimap Scaleform, so HideHudComponentThisFrame cannot remove
-- them. SETUP_HEALTH_ARMOUR(3) selects the layout without those bars.
CreateThread(function()
    local minimap = RequestScaleformMovie('minimap')
    local deadline = GetGameTimer() + 10000
    while not HasScaleformMovieLoaded(minimap) and GetGameTimer() < deadline do
        Wait(50)
    end

    if not HasScaleformMovieLoaded(minimap) then
        print('[rp_ui] Minimap Scaleform failed to load; native health/armour bars may remain visible.')
        return
    end

    -- Use the round radar mask when the standard circlemap texture is available.
    RequestStreamedTextureDict('circlemap', false)
    local textureDeadline = GetGameTimer() + 5000
    while not HasStreamedTextureDictLoaded('circlemap') and GetGameTimer() < textureDeadline do Wait(50) end
    if HasStreamedTextureDictLoaded('circlemap') then
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'circlemap', 'radarmasksm')
        SetMinimapClipType(1)
    else
        print('[rp_ui] circlemap texture unavailable; standard minimap retained.')
    end

    -- Rebuild the minimap once so the custom layout is applied immediately.
    SetBigmapActive(true, false)
    Wait(0)
    SetBigmapActive(false, false)

    while true do
        if not IsPauseMenuActive() then
            BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
            ScaleformMovieMethodAddParamInt(3)
            EndScaleformMovieMethod()
        end
        -- The game can reset the minimap Scaleform after respawn, map changes
        -- or settings updates; reapply at a low frequency instead of every frame.
        Wait(750)
    end
end)

-- F12 client diagnostics. FiveM does not expose reliable CPU/GPU temperature or
-- utilization to Lua; show only metrics the game client can actually measure.
local diagnosticsOpen = false
local function ToggleDiagnostics()
    if diagnosticsOpen then
        diagnosticsOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'hideDiagnostics' })
        return
    end
    -- The server decides whether this account has founder access.
    TriggerServerEvent('rp_ui:server:requestDiagnosticsAccess')
end
RegisterCommand('clientdiagnostics', ToggleDiagnostics, false)
RegisterKeyMapping('clientdiagnostics', 'Afficher les statistiques client', 'keyboard', 'F12')
RegisterCommand('diagnostics', ToggleDiagnostics, false)
RegisterCommand('f12', ToggleDiagnostics, false)
RegisterNUICallback('closeDiagnostics', function(_, cb)
    diagnosticsOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideDiagnostics' })
    cb({ ok = true })
end)
RegisterNUICallback('openResourceMonitor', function(_, cb)
    ExecuteCommand('resmon true')
    cb({ ok = true })
end)
RegisterNetEvent('rp_ui:client:openFounderDiagnostics', function()
    diagnosticsOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showDiagnostics' })
    TriggerServerEvent('rp_ui:server:requestDiagnosticsStats')
end)
RegisterNetEvent('rp_ui:client:denyFounderDiagnostics', function()
    diagnosticsOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideDiagnostics' })
    TriggerEvent('rp_ui:notify', 'Accès réservé au fondateur du serveur.', 'error')
end)
RegisterNetEvent('rp_ui:client:diagnosticsStats', function(stats)
    if diagnosticsOpen and type(stats) == 'table' then
        SendNUIMessage({ action = 'updateServerDiagnostics', stats = stats })
    end
end)
CreateThread(function()
    local nextServerRefresh = 0
    while true do
        if diagnosticsOpen then
            local frameTime = GetFrameTime()
            local fps = math.floor(1.0 / math.max(0.001, frameTime) + 0.5)
            local coords = GetEntityCoords(PlayerPedId())
            SendNUIMessage({
                action = 'updateDiagnostics',
                fps = fps,
                frameMs = math.floor(frameTime * 100000 + 0.5) / 100,
                ping = GetPlayerPing(GetPlayerServerId(PlayerId())),
                players = #GetActivePlayers(),
                maxPlayers = GetConvarInt('sv_maxclients', 0),
                coords = { x = math.floor(coords.x), y = math.floor(coords.y), z = math.floor(coords.z) }
            })
            if GetGameTimer() >= nextServerRefresh then
                TriggerServerEvent('rp_ui:server:requestDiagnosticsStats')
                nextServerRefresh = GetGameTimer() + 5000
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

