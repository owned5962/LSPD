local isTabletOpen = false
local lastAdminToggleAt = 0
local tabletEntity = nil
local tabletDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local tabletAnim = "base"
local tabletModel = GetHashKey('prop_cs_tablet')
local isAdminNoclip = false
local isAdminGodmode = false
local isAdminSpectating = false
local spectateTargetPed = nil

-- A resource restart must never leave the NUI visible or focused.
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isTabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeTablet' })
end)

function OpenAdminTablet()
    TriggerServerEvent('rp_tablet_admin:server:requestOpen')
end

function CloseAdminTablet()
    -- Idempotent: always release NUI focus, even if Lua and NUI state drift.
    if isAdminSpectating then TriggerServerEvent('rp_tablet_admin:server:stopSpectate') end
    local wasOpen = isTabletOpen
    isTabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeTablet" })
    if wasOpen then StopTabletAnimation() end
end

function StartTabletAnimation()
    local ped = PlayerPedId()
    RequestAnimDict(tabletDict)
    while not HasAnimDictLoaded(tabletDict) do Wait(10) end

    RequestModel(tabletModel)
    while not HasModelLoaded(tabletModel) do Wait(10) end

    tabletEntity = CreateObject(tabletModel, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(tabletEntity, ped, GetPedBoneIndex(ped, 28422), -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, tabletDict, tabletAnim, 3.0, 3.0, -1, 49, 0, false, false, false)
end

function StopTabletAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if tabletEntity and DoesEntityExist(tabletEntity) then
        DeleteEntity(tabletEntity)
        tabletEntity = nil
    end
end

RegisterNetEvent('rp_tablet_admin:client:openAuthorized', function(adminData, playersList, jobsList, frozenPlayers)
    isTabletOpen = true
    StartTabletAnimation()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openTablet",
        admin = adminData,
        players = playersList,
        jobs = jobsList,
        frozenPlayers = frozenPlayers or {}
    })
end)

RegisterCommand('admin', function()
    local now = GetGameTimer()
    -- Prevent a simultaneous NUI F10 key event and key mapping from reopening it.
    if lastAdminToggleAt > 0 and now - lastAdminToggleAt < 500 then return end
    lastAdminToggleAt = now

    if isTabletOpen then
        CloseAdminTablet()
    else
        OpenAdminTablet()
    end
end, false)

RegisterKeyMapping('admin', 'Ouvrir la Tablette Admin', 'keyboard', 'F10')

RegisterNUICallback('close', function(data, cb)
    if type(data) == 'table' and data.source == 'f10' then
        lastAdminToggleAt = GetGameTimer()
    end
    CloseAdminTablet()
    cb('ok')
end)

RegisterNUICallback('spectatePlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:spectatePlayer', data.playerId)
    cb('ok')
end)

RegisterNUICallback('stopSpectate', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:stopSpectate')
    cb('ok')
end)

RegisterNUICallback('toggleNoclip', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:toggleNoclip')
    cb('ok')
end)

RegisterNUICallback('toggleGodmode', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:toggleGodmode')
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:spawnVehicle', data.model)
    cb('ok')
end)
RegisterNUICallback('banPlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:banPlayer', data.playerId, data.reason)
    cb('ok')
end)

RegisterNUICallback('kickPlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:kickPlayer', data.playerId, data.reason)
    cb('ok')
end)

RegisterNUICallback('freezePlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:freezePlayer', data.playerId, data.freeze)
    cb('ok')
end)

RegisterNUICallback('teleportToPlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:teleportToPlayer', data.playerId)
    cb('ok')
end)

RegisterNUICallback('bringPlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:bringPlayer', data.playerId)
    cb('ok')
end)

RegisterNUICallback('healPlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:healPlayer', data.playerId)
    cb('ok')
end)

RegisterNUICallback('revivePlayer', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:revivePlayer', data.playerId)
    cb('ok')
end)

RegisterNUICallback('manageEconomy', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:manageEconomy', data.playerId, data.type, data.amount, data.operation)
    cb('ok')
end)

RegisterNUICallback('setJob', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:setJob', data.playerId, data.jobName, data.grade)
    cb('ok')
end)

-- Vehicle spawning/deletion are intentionally unavailable until they use
-- server-authorized entity creation and ownership validation.

RegisterNUICallback('setWeatherTime', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:setWeatherTime', data.weather, tonumber(data.hours), tonumber(data.minutes))
    cb('ok')
end)

RegisterNUICallback('broadcastAnnouncement', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:broadcastAnnouncement', data.message)
    cb('ok')
end)

RegisterNUICallback('requestPlayerPositions', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:requestPlayerPositions')
    cb('ok')
end)

RegisterNUICallback('requestAuditLogs', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:requestAuditLogs')
    cb('ok')
end)

RegisterNetEvent('rp_tablet_admin:client:auditLogs', function(logs)
    SendNUIMessage({ action = 'auditLogs', logs = logs or {} })
end)

RegisterNetEvent('rp_tablet_admin:client:playerPositions', function(players)
    SendNUIMessage({ action = 'playerPositions', players = players or {} })
end)

RegisterNetEvent('rp_tablet_admin:client:startSpectate', function(targetId)
    local playerIndex = GetPlayerFromServerId(tonumber(targetId) or -1)
    if playerIndex == -1 or not NetworkIsPlayerActive(playerIndex) then
        TriggerEvent('rp_core:client:notify', 'Joueur introuvable pour la surveillance.', 'error')
        return
    end
    local targetPed = GetPlayerPed(playerIndex)
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then return end
    spectateTargetPed = targetPed
    isAdminSpectating = true
    NetworkSetInSpectatorMode(true, targetPed)
    TriggerEvent('rp_core:client:notify', 'Surveillance activée.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:client:stopSpectate', function()
    if not isAdminSpectating then return end
    NetworkSetInSpectatorMode(false, spectateTargetPed or PlayerPedId())
    isAdminSpectating = false
    spectateTargetPed = nil
    TriggerEvent('rp_core:client:notify', 'success', 'Surveillance arrêtée.')
end)

RegisterNetEvent('rp_tablet_admin:client:toggleGodmode', function()
    isAdminGodmode = not isAdminGodmode
    SetPlayerInvincible(PlayerId(), isAdminGodmode or isAdminNoclip)
    SetEntityInvincible(PlayerPedId(), isAdminGodmode or isAdminNoclip)
    TriggerEvent('rp_core:client:notify', isAdminGodmode and 'GodMode activé.' or 'GodMode désactivé.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:client:toggleNoclip', function()
    isAdminNoclip = not isAdminNoclip
    local enabled = isAdminNoclip
    local ped = PlayerPedId()
    SetEntityCollision(ped, not enabled, not enabled)
    SetEntityInvincible(ped, enabled or isAdminGodmode)
    SetPlayerInvincible(PlayerId(), enabled or isAdminGodmode)
    TriggerEvent('rp_core:client:notify', enabled and 'NoClip activé. WASD / Espace / Ctrl pour bouger.' or 'NoClip désactivé.', 'info')
    if enabled then
        CreateThread(function()
            while isAdminNoclip do
                Wait(0)
                ped = PlayerPedId()
                local camRot = GetGameplayCamRot(2)
                local pitch = math.rad(camRot.x)
                local heading = math.rad(camRot.z)
                local forward = vector3(-math.sin(heading) * math.cos(pitch), math.cos(heading) * math.cos(pitch), math.sin(pitch))
                local right = vector3(math.cos(heading), math.sin(heading), 0.0)
                local position = GetEntityCoords(ped)
                local speed = IsControlPressed(0, 21) and 4.0 or 1.2
                if IsControlPressed(0, 32) then position = position + forward * speed end
                if IsControlPressed(0, 33) then position = position - forward * speed end
                if IsControlPressed(0, 35) then position = position + right * speed end
                if IsControlPressed(0, 34) then position = position - right * speed end
                if IsControlPressed(0, 22) then position = position + vector3(0.0, 0.0, speed) end
                if IsControlPressed(0, 36) then position = position - vector3(0.0, 0.0, speed) end
                SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, true, true, true)
            end
            ped = PlayerPedId()
            SetEntityCollision(ped, true, true)
            SetEntityInvincible(ped, isAdminGodmode)
            SetPlayerInvincible(PlayerId(), isAdminGodmode)
        end)
    end
end)

RegisterNetEvent('rp_tablet_admin:client:spawnVehicle', function(model)
    if type(model) ~= 'string' then return end
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        TriggerEvent('rp_core:client:notify', 'Modèle de véhicule inconnu ou invalide.', 'error')
        return
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then TriggerEvent('rp_core:client:notify', 'Chargement du véhicule impossible.', 'error'); return end
    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, true)
    if vehicle and vehicle ~= 0 then
        SetPedIntoVehicle(ped, vehicle, -1)
        SetVehicleOnGroundProperly(vehicle)
        SetEntityAsMissionEntity(vehicle, true, true)
        TriggerEvent('rp_core:client:notify', 'Véhicule créé : ' .. model, 'success')
    end
    SetModelAsNoLongerNeeded(hash)
end)
RegisterNetEvent('rp_tablet_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('rp_tablet_admin:client:freezeToggle', function(freeze)
    FreezeEntityPosition(PlayerPedId(), freeze)
end)

RegisterNetEvent('rp_tablet_admin:client:teleport', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
end)

RegisterNetEvent('rp_tablet_admin:client:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('rp_tablet_admin:client:syncWeather', function(weather)
    SetWeatherTypeOverTime(weather, 10.0)
    Wait(1000)
    ClearOverrideWeather()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isAdminNoclip = false
    if isAdminSpectating then NetworkSetInSpectatorMode(false, spectateTargetPed or PlayerPedId()) end
    isAdminSpectating = false
    spectateTargetPed = nil
    local ped = PlayerPedId()
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    SetNuiFocus(false, false)
    if tabletEntity and DoesEntityExist(tabletEntity) then DeleteEntity(tabletEntity); tabletEntity = nil end
end)
RegisterNetEvent('rp_tablet_admin:client:syncTime', function(hours, minutes)
    NetworkOverrideClockTime(hours, minutes, 0)
end)
