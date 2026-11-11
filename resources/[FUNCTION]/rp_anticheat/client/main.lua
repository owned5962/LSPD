local isSpectating = false
local spectateTarget = nil
local lastCoords = nil
local lastCheck = 0
local isAnticheatUIOpen = false

-- In-game Anticheat UI command for Admins
RegisterKeyMapping('openanticheat', 'Ouvrir le menu Anticheat', 'keyboard', 'F9')

RegisterCommand('openanticheat', function()
    if isSpectating then
        StopSpectate()
    else
        TriggerServerEvent('rp_anticheat:requestOpen')
    end
end, false)

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

RegisterNetEvent('rp_anticheat:openUI', function(protections, playersList)
    isAnticheatUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        protections = protections,
        players = markCurrentPlayer(playersList)
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
    SendNUIMessage({ action = 'spectateStarted', targetId = targetServerId })
    TriggerEvent('rp_core:notify', 'info', 'Vue spectateur activée. Appuie sur F9 pour arrêter.')
end

function StopSpectate()
    if not isSpectating then return end
    NetworkSetInSpectatorMode(false, spectateTarget or PlayerPedId())
    ClearFocus()
    isSpectating = false
    spectateTarget = nil
    SendNUIMessage({ action = 'spectateStopped' })
    TriggerEvent('rp_core:notify', 'info', 'Surveillance arrêtée.')
end

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
RegisterNetEvent('rp_anticheat:notifyStaff', function(data)
    SendNUIMessage({
        action = 'newDetection',
        alert = data
    })
    TriggerEvent('rp_core:notify', 'error', '[ANTICHEAT] ' .. data.playerName .. ' (ID ' .. data.playerId .. ') : ' .. data.reason)
end)
