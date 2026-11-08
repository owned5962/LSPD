local isMenuOpen = false
local isHandcuffed = false

RegisterKeyMapping('openjobmenu', 'Ouvrir le menu métier (F6)', 'keyboard', 'F6')

RegisterCommand('openjobmenu', function()
    TriggerServerEvent('rp_interactions:requestJobMenu')
end, false)

RegisterNetEvent('rp_interactions:openMenu', function(job, grade, jobData)
    isMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        job = job,
        grade = grade,
        jobData = jobData
    })
end)

RegisterNUICallback('close', function(data, cb)
    isMenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('triggerAction', function(data, cb)
    local action = data.actionId
    local closestPlayer, closestDistance = GetClosestPlayer()

    if action == 'repair' or action == 'clean' or action == 'impound' then
        TriggerEvent('rp_core:notify', 'error', 'Cette action est désactivée jusqu’à son implémentation sécurisée côté serveur.')
    elseif closestPlayer ~= -1 and closestDistance <= 3.0 then
        local targetServerId = GetPlayerServerId(closestPlayer)
        TriggerServerEvent('rp_interactions:executeAction', targetServerId, action, data.amount)
    else
        TriggerEvent('rp_core:notify', 'error', 'Aucun citoyen à proximité!')
    end

    isMenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent('rp_interactions:toggleCuff', function()
    isHandcuffed = not isHandcuffed
    local ped = PlayerPedId()
    if isHandcuffed then
        SetEnableHandcuffs(ped, true)
        DisablePlayerFiring(ped, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        SetPedCanPlayGestureAnims(ped, false)
        TriggerEvent('rp_core:notify', 'info', 'Vous avez été menotté.')
    else
        SetEnableHandcuffs(ped, false)
        DisablePlayerFiring(ped, false)
        SetPedCanPlayGestureAnims(ped, true)
        TriggerEvent('rp_core:notify', 'success', 'Vous avez été démenotté.')
    end
end)

function GetVehicleInFront()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local entityWorld = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
    local rayHandle = CastRayPointToPoint(pos.x, pos.y, pos.z, entityWorld.x, entityWorld.y, entityWorld.z, 10, ped, 0)
    local _, _, _, _, vehicle = GetRaycastResult(rayHandle)
    return vehicle
end

function GetClosestPlayer()
    local players = GetActivePlayers()
    local coords = GetEntityCoords(PlayerPedId())
    local closestDistance = -1
    local closestPlayer = -1

    for i = 1, #players, 1 do
        local target = GetPlayerPed(players[i])
        if target ~= PlayerPedId() then
            local targetCoords = GetEntityCoords(target)
            local distance = #(coords - targetCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = players[i]
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end
