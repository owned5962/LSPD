local activeOfficer = nil
local activeOffence = nil
local interactionOpen = false
local lastDetection = {}
local lastVehicle = 0
local inCustody = false

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', tostring(message or ''), kind or 'info')
end

local function report(offence)
    local now = GetGameTimer()
    if lastDetection[offence] and now - lastDetection[offence] < 45000 then return end
    lastDetection[offence] = now
    TriggerServerEvent('rp_police_interaction:server:reportOffence', offence)
end

local function closeInteraction()
    if not interactionOpen then return end
    interactionOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function removeOfficer()
    if activeOfficer and DoesEntityExist(activeOfficer) then
        SetEntityAsMissionEntity(activeOfficer, true, true)
        DeletePed(activeOfficer)
    end
    activeOfficer = nil
    activeOffence = nil
end

local function createOfficer()
    if activeOfficer and DoesEntityExist(activeOfficer) then return end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local angle = math.random() * math.pi * 2
    local spawn = vector3(
        playerCoords.x + math.cos(angle) * Config.PedSpawnDistance,
        playerCoords.y + math.sin(angle) * Config.PedSpawnDistance,
        playerCoords.z
    )
    local model = joaat(Config.PedModel)
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then return end

    local found, safeCoords = GetSafeCoordForPed(spawn.x, spawn.y, spawn.z, true, 16)
    if found then spawn = safeCoords end
    activeOfficer = CreatePed(4, model, spawn.x, spawn.y, spawn.z, 0.0, false, true)
    SetModelAsNoLongerNeeded(model)
    if activeOfficer == 0 then activeOfficer = nil; return end
    SetEntityAsMissionEntity(activeOfficer, true, true)
    SetBlockingOfNonTemporaryEvents(activeOfficer, true)
    SetPedFleeAttributes(activeOfficer, 0, false)
    SetPedCombatAttributes(activeOfficer, 46, true)
    SetPedAccuracy(activeOfficer, 35)
    SetPedArmour(activeOfficer, 50)
    GiveWeaponToPed(activeOfficer, joaat('WEAPON_PISTOL'), 60, false, true)
    TaskGoToEntity(activeOfficer, playerPed, -1, Config.ApproachDistance, 1.2, 0, 0)
end

local function showInteraction(data)
    if interactionOpen then return end
    interactionOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

RegisterNetEvent('rp_police_interaction:client:interpellation', function(data)
    if inCustody or interactionOpen then return end
    activeOffence = data.offence
    createOfficer()
    if not activeOfficer then
        notify('Impossible de joindre un agent de police à proximité.', 'error')
        return
    end
    CreateThread(function()
        local deadline = GetGameTimer() + 60000
        while activeOfficer and DoesEntityExist(activeOfficer) and not interactionOpen and GetGameTimer() < deadline do
            local distance = #(GetEntityCoords(activeOfficer) - GetEntityCoords(PlayerPedId()))
            if distance <= Config.ApproachDistance + 0.8 then
                ClearPedTasks(activeOfficer)
                TaskTurnPedToFaceEntity(activeOfficer, PlayerPedId(), 1000)
                Wait(700)
                showInteraction(data)
                return
            end
            Wait(250)
        end
        if not interactionOpen then
            removeOfficer()
            activeOffence = nil
        end
    end)
end)

RegisterNUICallback('surrender', function(_, cb)
    if not interactionOpen or not activeOffence then cb({ ok = false }); return end
    local offence = activeOffence
    closeInteraction()
    removeOfficer()
    inCustody = true
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(600)
    SetEntityCoords(ped, Config.Prison.x, Config.Prison.y, Config.Prison.z, false, false, false, false)
    SetEntityHeading(ped, Config.Prison.w)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    DoScreenFadeIn(500)
    notify('Vous vous êtes rendu. Vous êtes placé en détention pendant 30 secondes.', 'success')
    Wait(Config.SurrenderFreezeMs)
    FreezeEntityPosition(ped, false)
    inCustody = false
    notify('Fin de la période de détention.', 'info')
    cb({ ok = true })
end)

RegisterNUICallback('refuse', function(_, cb)
    if not interactionOpen or not activeOffence then cb({ ok = false }); return end
    local offence = activeOffence
    closeInteraction()
    TriggerServerEvent('rp_police_interaction:server:refused', offence)
    if activeOfficer and DoesEntityExist(activeOfficer) then
        ClearPedTasks(activeOfficer)
        TaskCombatPed(activeOfficer, PlayerPedId(), 0, 16)
        SetPedKeepTask(activeOfficer, true)
    end
    notify('Vous avez refusé de vous rendre. Les forces de l’ordre sont alertées.', 'error')
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    -- L'interpellation impose un choix : fermeture UI équivaut à un refus.
    if interactionOpen and activeOffence then
        local offence = activeOffence
        closeInteraction()
        TriggerServerEvent('rp_police_interaction:server:refused', offence)
        if activeOfficer and DoesEntityExist(activeOfficer) then
            TaskCombatPed(activeOfficer, PlayerPedId(), 0, 16)
        end
    else
        closeInteraction()
    end
    cb({ ok = true })
end)

RegisterNetEvent('rp_police_interaction:client:alert', function()
    -- Compatibility hook for future dispatch clients.
end)

-- Détection des dégâts : le serveur revalide le joueur, le métier et le délai.
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or inCustody then return end
    local victim, attacker = args[1], args[2]
    local playerPed = PlayerPedId()
    local playerVehicleHit = IsEntityAVehicle(attacker) and GetPedInVehicleSeat(attacker, -1) == playerPed
    if (attacker ~= playerPed and not playerVehicleHit) or victim == playerPed or not DoesEntityExist(victim) then return end
    if playerVehicleHit and GetEntitySpeed(attacker) >= 5.0 and IsEntityAPed(victim) and not IsPedAPlayer(victim) then
        report('pedestrian_collision')
        return
    end
    if IsEntityAPed(victim) then
        local isPlayer = IsPedAPlayer(victim)
        local offence = isPlayer and 'assault_player' or 'assault_npc'
        CreateThread(function()
            Wait(250)
            if DoesEntityExist(victim) and IsEntityDead(victim) then
                offence = isPlayer and 'murder_player' or 'murder_npc'
            end
            report(offence)
        end)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if not inCustody and IsPedShooting(ped) then
            if not IsPedInAnyPoliceVehicle(ped) then
                report('public_shooting')
            end
            Wait(1200)
        else
            Wait(150)
        end
    end
end)

-- Le vol est signalé uniquement pendant une animation de car-jacking,
-- et non à chaque entrée dans son propre véhicule.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if not inCustody and IsPedJacking(ped) then
            report('vehicle_theft')
            Wait(1500)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        SetMaxWantedLevel(0)
        ClearPlayerWantedLevel(PlayerId())
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        SetPoliceIgnorePlayer(PlayerId(), true)
        SetDispatchCopsForPlayer(PlayerId(), false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)

        if activeOfficer and DoesEntityExist(activeOfficer) and not interactionOpen and not inCustody then
            local distance = #(GetEntityCoords(activeOfficer) - GetEntityCoords(PlayerPedId()))
            if distance > 150.0 then removeOfficer() end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeInteraction()
    if inCustody then FreezeEntityPosition(PlayerPedId(), false) end
    removeOfficer()
end)
