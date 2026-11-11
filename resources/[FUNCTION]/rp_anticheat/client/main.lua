local isSpectating = false
local spectateTarget = nil
local lastCoords = nil
local lastCheck = 0
local isAnticheatUIOpen = false
local isAnticheatPrisoner = false
local prisonEndsAt = 0
local prisonCenter = nil
local prisonRelease = nil

-- Commande locale d'ouverture du menu Anticheat.
local function ToggleAnticheatTablet()
    if isSpectating then
        StopSpectate()
        return
    end
    if isAnticheatUIOpen then
        isAnticheatUIOpen = false
        TriggerServerEvent('rp_anticheat:closeUI')
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        return
    end
    TriggerServerEvent('rp_anticheat:requestOpen')
end

-- Déclarer la commande avant de lui associer F9.
RegisterCommand('openanticheat', ToggleAnticheatTablet, false)
RegisterKeyMapping('openanticheat', 'Ouvrir le menu Anticheat', 'keyboard', 'F9')

-- Alias pour tester l'ouverture depuis le chat.
RegisterCommand('anticheat', ToggleAnticheatTablet, false)

local function markCurrentPlayer(playersList)
    local ownServerId = GetPlayerServerId(PlayerId())
    for _, player in ipairs(playersList or {}) do
        player.isSelf = tonumber(player.id) == ownServerId
    end
    return playersList
end

RegisterNetEvent('rp_anticheat:updatePlayers', function(playersList)
    if not isAnticheatUIOpen or type(playersList) ~= 'table' then return end
    SendNUIMessage({ action = 'updatePlayers', players = markCurrentPlayer(playersList) })
end)

RegisterNetEvent('rp_anticheat:syncProtections', function(protections)
    if type(protections) == 'table' then
        Config.Protections = protections
        if isAnticheatUIOpen then SendNUIMessage({ action = 'protections', protections = protections }) end
    end
end)

RegisterNetEvent('rp_anticheat:openUI', function(protections, playersList, logsList, detectionCount)
    isAnticheatUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        protections = protections,
        players = markCurrentPlayer(playersList),
        logs = logsList or {},
        detectionCount = tonumber(detectionCount) or #(logsList or {})
    })
end)

RegisterNUICallback('close', function(data, cb)
    isAnticheatUIOpen = false
    TriggerServerEvent('rp_anticheat:closeUI')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isAnticheatUIOpen = false
    TriggerServerEvent('rp_anticheat:closeUI')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if isSpectating then StopSpectate() end
    SetNuiFocus(false, false)
end)

RegisterNetEvent('rp_anticheat:updateLogs', function(payload)
    if isAnticheatUIOpen then
        payload = type(payload) == 'table' and payload or {}
        SendNUIMessage({ action = 'updateLogs', logs = payload.logs or {}, detectionCount = payload.detectionCount or 0 })
    end
end)

RegisterNetEvent('rp_anticheat:updateBans', function(bansList)
    if isAnticheatUIOpen then SendNUIMessage({ action = 'updateBans', bans = bansList or {} }) end
end)

RegisterNUICallback('requestStatistics', function(data, cb)
    TriggerServerEvent('rp_anticheat:requestStatistics', data.period)
    cb({ ok = true })
end)

RegisterNetEvent('rp_anticheat:updateStatistics', function(payload)
    if isAnticheatUIOpen then SendNUIMessage({ action = 'updateStatistics', statistics = payload }) end
end)

RegisterNUICallback('requestLogs', function(data, cb)
    TriggerServerEvent('rp_anticheat:requestLogs')
    cb({ ok = true })
end)

RegisterNUICallback('requestSanctionConfig', function(data, cb)
    TriggerServerEvent('rp_anticheat:requestSanctionConfig')
    cb({ ok = true })
end)

RegisterNUICallback('saveSanctionConfig', function(data, cb)
    TriggerServerEvent('rp_anticheat:saveSanctionConfig', data.sanctions, data.prisonMinutes)
    cb({ ok = true })
end)

RegisterNetEvent('rp_anticheat:updateSanctionConfig', function(payload)
    if isAnticheatUIOpen and type(payload) == 'table' then
        SendNUIMessage({ action = 'updateSanctionConfig', sanctions = payload.sanctions or {}, prisonMinutes = payload.prisonMinutes or 30 })
    end
end)

RegisterNUICallback('requestBans', function(data, cb)
    TriggerServerEvent('rp_anticheat:requestBans')
    cb({ ok = true })
end)

RegisterNUICallback('unban', function(data, cb)
    TriggerServerEvent('rp_anticheat:unban', data.identifier)
    cb({ ok = true })
end)

RegisterNUICallback('toggleProtection', function(data, cb)
    TriggerServerEvent('rp_anticheat:toggleProtection', data.protectionKey, data.state)
    cb('ok')
end)

RegisterNUICallback('spectatePlayer', function(data, cb)
    TriggerServerEvent('rp_anticheat:requestSpectate', tonumber(data.targetId))
    cb('ok')
end)

RegisterNetEvent('rp_anticheat:startSpectate', function(targetServerId, coords)
    StartSpectate(targetServerId, coords)
end)

RegisterNUICallback('stopSpectate', function(data, cb)
    StopSpectate()
    cb('ok')
end)

RegisterNUICallback('punishPlayer', function(data, cb)
    TriggerServerEvent('rp_anticheat:punish', data.targetId, data.punishType, data.reason)
    cb('ok')
end)

-- Live Surveillance Camera (Spectate)
function StartSpectate(targetServerId, targetCoords)
    targetServerId = tonumber(targetServerId)
    if type(targetCoords) ~= 'table' or not tonumber(targetCoords.x) or not tonumber(targetCoords.y) or not tonumber(targetCoords.z) then
        TriggerEvent('rp_core:notify', 'error', 'Coordonnées de surveillance invalides.')
        return
    end

    SetFocusPosAndVel(tonumber(targetCoords.x), tonumber(targetCoords.y), tonumber(targetCoords.z), 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(tonumber(targetCoords.x), tonumber(targetCoords.y), tonumber(targetCoords.z))
    local deadline = GetGameTimer() + 10000
    local playerIndex, targetPed = -1, 0
    repeat
        playerIndex = GetPlayerFromServerId(targetServerId or -1)
        if playerIndex ~= -1 and NetworkIsPlayerActive(playerIndex) then
            targetPed = GetPlayerPed(playerIndex)
            if targetPed ~= 0 and DoesEntityExist(targetPed) then break end
        end
        Wait(100)
    until GetGameTimer() >= deadline

    if playerIndex == -1 or targetPed == 0 or not DoesEntityExist(targetPed) or targetPed == PlayerPedId() then
        ClearFocus()
        TriggerEvent('rp_core:notify', 'error', 'Le joueur n’est pas disponible dans la zone de streaming.')
        return
    end

    isSpectating = true
    spectateTarget = targetPed
    NetworkSetInSpectatorMode(true, targetPed)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'spectateStarted', targetId = targetServerId })
    TriggerEvent('rp_core:notify', 'info', 'Vue spectateur activée. Appuie sur F9 pour arrêter.')
end

function StopSpectate()
    if not isSpectating then return end
    NetworkSetInSpectatorMode(false, spectateTarget or PlayerPedId())
    ClearFocus()
    isSpectating = false
    spectateTarget = nil
    if isAnticheatUIOpen then SetNuiFocus(true, true) end
    SendNUIMessage({ action = 'spectateStopped' })
    TriggerEvent('rp_core:notify', 'info', 'Surveillance arrêtée.')
end

RegisterNetEvent('rp_anticheat:applyPrison', function(payload)
    if type(payload) ~= 'table' or type(payload.jail) ~= 'table' or type(payload.release) ~= 'table' then return end
    local jail = payload.jail
    local release = payload.release
    if not tonumber(jail.x) or not tonumber(jail.y) or not tonumber(jail.z)
        or not tonumber(release.x) or not tonumber(release.y) or not tonumber(release.z) then return end
    isAnticheatPrisoner = true
    prisonEndsAt = tonumber(payload.endsAt) or (os.time() + 1800)
    prisonCenter = vector3(tonumber(jail.x), tonumber(jail.y), tonumber(jail.z))
    prisonRelease = vector3(tonumber(release.x), tonumber(release.y), tonumber(release.z))
    SetEntityCoords(PlayerPedId(), prisonCenter.x, prisonCenter.y, prisonCenter.z, false, false, false, false)
    TriggerEvent('rp_core:client:notify', 'error', 'Tu es placé en prison pour une sanction anticheat.')
end)

RegisterNetEvent('rp_anticheat:releasePrison', function()
    if not isAnticheatPrisoner then return end
    isAnticheatPrisoner = false
    local ped = PlayerPedId()
    if prisonRelease then SetEntityCoords(ped, prisonRelease.x, prisonRelease.y, prisonRelease.z, false, false, false, false) end
    prisonCenter, prisonRelease, prisonEndsAt = nil, nil, 0
    TriggerEvent('rp_core:client:notify', 'success', 'Ta peine de prison est terminée.')
end)

CreateThread(function()
    while true do
        if not isAnticheatPrisoner then
            Wait(1000)
        else
            Wait(1000)
            if os.time() >= prisonEndsAt then
                TriggerServerEvent('rp_anticheat:prisonExpired')
            else
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                if prisonCenter and #(coords - prisonCenter) > (Config.PrisonRadius or 90.0) then
                    SetEntityCoords(ped, prisonCenter.x, prisonCenter.y, prisonCenter.z, false, false, false, false)
                end
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(('~r~AEGIS PRISON~s~  ·  Temps restant : ~b~%d min %02d sec'):format(
                    math.floor((prisonEndsAt - os.time()) / 60), math.max(0, (prisonEndsAt - os.time()) % 60)))
                EndTextCommandDisplayHelp(0, false, true, 1000)
            end
        end
    end
end)

-- Client-side Detection Thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local ped = PlayerPedId()

        if not isSpectating and not IsEntityDead(ped) then
            -- 1. GodMode detection
            if Config.Protections['godmode'] and Config.Protections['godmode'].enabled then
                if GetPlayerInvincible(PlayerId()) or not GetEntityCanBeDamaged(ped) then
                    TriggerServerEvent('rp_anticheat:flag', 'GodMode / Invincible')
                end
            end

            -- 2. SpeedHack detection
            if Config.Protections['speedhack'] and Config.Protections['speedhack'].enabled then
                if not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped) and not IsPedInParachuteFreeFall(ped) then
                    local speed = GetEntitySpeed(ped)
                    if speed > Config.MaxSpeed then
                        TriggerServerEvent('rp_anticheat:flag', 'SpeedHack à pied (' .. math.floor(speed) .. ' m/s)')
                    end
                end
            end

            -- 3. Blacklisted Weapons
            if Config.Protections['blacklisted_weapons'] and Config.Protections['blacklisted_weapons'].enabled then
                for _, weaponHash in ipairs(Config.BlacklistedWeapons) do
                    if HasPedGotWeapon(ped, weaponHash, false) then
                        RemoveWeaponFromPed(ped, weaponHash)
                        TriggerServerEvent('rp_anticheat:flag', 'Arme interdite détectée')
                        break
                    end
                end
            end

            -- 4. Thermal / Night Vision
            if Config.Protections['thermal_night_vision'] and Config.Protections['thermal_night_vision'].enabled then
                if GetUsingseethrough() or GetUsingnightvision() then
                    SetNightvision(false)
                    SetSeethrough(false)
                    TriggerServerEvent('rp_anticheat:flag', 'Vision thermique/nocturne non autorisée')
                end
            end
        end
    end
end)

-- Staff Security Notification Popup
RegisterNetEvent('rp_anticheat:notifyStaff', function(data, detectionCount)
    SendNUIMessage({
        action = 'newDetection',
        alert = data,
        detectionCount = detectionCount
    })
    TriggerEvent('rp_core:notify', 'error', '[ANTICHEAT] ' .. data.playerName .. ' (ID ' .. data.playerId .. ') : ' .. data.reason)
end)
