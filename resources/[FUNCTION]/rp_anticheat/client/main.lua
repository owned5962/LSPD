local isSpectating = false
local spectateTarget = nil
local lastCoords = nil
local lastCheck = 0
local isAnticheatUIOpen = false

-- In-game Anticheat UI command for Admins
RegisterKeyMapping('openanticheat', 'Ouvrir le menu Anticheat', 'keyboard', 'F11')

RegisterCommand('openanticheat', function()
    TriggerServerEvent('rp_anticheat:requestOpen')
end, false)

RegisterNetEvent('rp_anticheat:updatePlayers', function(playersList)
    if not isAnticheatUIOpen or type(playersList) ~= 'table' then return end
    SendNUIMessage({ action = 'updatePlayers', players = playersList })
end)

RegisterNetEvent('rp_anticheat:syncProtections', function(protections)
    if type(protections) == 'table' then Config.Protections = protections end
end)

RegisterNetEvent('rp_anticheat:openUI', function(protections, playersList)
    isAnticheatUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        protections = protections,
        players = playersList
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
    SetNuiFocus(false, false)
end)

RegisterNUICallback('toggleProtection', function(data, cb)
    TriggerServerEvent('rp_anticheat:toggleProtection', data.protectionKey, data.state)
    cb('ok')
end)

RegisterNUICallback('spectatePlayer', function(data, cb)
    local targetServerId = tonumber(data.targetId)
    StartSpectate(targetServerId)
    cb('ok')
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
function StartSpectate(targetServerId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
    if not DoesEntityExist(targetPed) then
        TriggerEvent('rp_core:notify', 'error', 'Cible introuvable ou hors de portée.')
        return
    end

    local myPed = PlayerPedId()
    isSpectating = true
    spectateTarget = targetPed

    SetEntityVisible(myPed, false, 0)
    SetEntityCollision(myPed, false, false)
    SetEntityInvincible(myPed, true)
    NetworkSetInSpectatorMode(true, targetPed)

    SendNUIMessage({ action = 'spectateStarted', targetId = targetServerId })
    TriggerEvent('rp_core:notify', 'info', 'Surveillance en direct activée sur ID: ' .. targetServerId)
end

function StopSpectate()
    if not isSpectating then return end
    local myPed = PlayerPedId()
    NetworkSetInSpectatorMode(false, spectateTarget)
    SetEntityVisible(myPed, true, 0)
    SetEntityCollision(myPed, true, true)
    SetEntityInvincible(myPed, false)
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
