local schoolBlip
local promptVisible = false
local examVehicle
local currentCheckpoint = 0
local checkpointCount = 0
local activeCategory
local activeCheckpoints

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

local function closeTheory()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openSchool()
    TriggerServerEvent('rp_drivingschool:server:requestLicenses')
end

RegisterNetEvent('rp_drivingschool:client:licenses', function(rows)
    local categories = {}
    for id, item in pairs(Config.Categories) do
        categories[id] = { label = item.label, price = item.price }
    end
    SendNUIMessage({ action = 'open', categories = categories, licenses = rows or {} })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('rp_drivingschool:client:theory', function(category, label, questions)
    activeCategory = category
    SendNUIMessage({ action = 'theory', category = category, label = label, questions = questions })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('rp_drivingschool:client:startPractical', function(data)
    closeTheory()
    local hash = GetHashKey(data.model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        notify('Véhicule d’examen indisponible.', 'error')
        TriggerServerEvent('rp_drivingschool:server:cancelExam')
        return
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(hash) then
        notify('Chargement du véhicule impossible.', 'error')
        TriggerServerEvent('rp_drivingschool:server:cancelExam')
        return
    end
    local p = data.spawn
    local vehicle = CreateVehicle(hash, p.x, p.y, p.z, p.w, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('Impossible de créer le véhicule d’examen.', 'error')
        TriggerServerEvent('rp_drivingschool:server:cancelExam')
        return
    end
    examVehicle = vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleDoorsLocked(vehicle, 1)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    TriggerServerEvent('rp_drivingschool:server:practicalStarted', netId)
    activeCategory = data.category
    currentCheckpoint = 0
    checkpointCount = #data.checkpoints
    activeCheckpoints = data.checkpoints
end)

RegisterNetEvent('rp_drivingschool:client:checkpoint', function(index, total)
    currentCheckpoint = tonumber(index) or 0
    checkpointCount = tonumber(total) or 0
    local p = activeCheckpoints and activeCheckpoints[currentCheckpoint]
    if p then
        SetNewWaypoint(p.x, p.y)
        notify(('Checkpoint %d/%d : suivez le GPS.'):format(currentCheckpoint, checkpointCount), 'info')
    end
end)

RegisterNetEvent('rp_drivingschool:client:examPassed', function(category)
    if examVehicle and DoesEntityExist(examVehicle) then
        DeleteVehicle(examVehicle)
    end
    examVehicle = nil
    activeCategory = nil
    currentCheckpoint = 0
    activeCheckpoints = nil
    notify('Permis enregistré dans votre dossier de personnage.', 'success')
end)

RegisterNetEvent('rp_drivingschool:client:examFailed', function()
    if examVehicle and DoesEntityExist(examVehicle) then
        DeleteVehicle(examVehicle)
    end
    examVehicle = nil
    activeCategory = nil
    currentCheckpoint = 0
    activeCheckpoints = nil
end)

RegisterNUICallback('close', function(_, cb)
    closeTheory()
    cb({ ok = true })
end)

RegisterNUICallback('startTheory', function(data, cb)
    if type(data) == 'table' and type(data.category) == 'string' then
        closeTheory()
        TriggerServerEvent('rp_drivingschool:server:startTheory', data.category)
    end
    cb({ ok = true })
end)

RegisterNUICallback('submitTheory', function(data, cb)
    if type(data) == 'table' and type(data.answers) == 'table' then
        closeTheory()
        TriggerServerEvent('rp_drivingschool:server:submitTheory', data.answers)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cancelExam', function(_, cb)
    closeTheory()
    TriggerServerEvent('rp_drivingschool:server:cancelExam')
    cb({ ok = true })
end)

CreateThread(function()
    schoolBlip = AddBlipForCoord(Config.School.coords.x, Config.School.coords.y, Config.School.coords.z)
    SetBlipSprite(schoolBlip, Config.School.blip.sprite)
    SetBlipDisplay(schoolBlip, 4)
    SetBlipScale(schoolBlip, Config.School.blip.scale)
    SetBlipColour(schoolBlip, Config.School.blip.colour)
    SetBlipAsShortRange(schoolBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.School.blip.label)
    EndTextCommandSetBlipName(schoolBlip)

    while true do
        local waitTime = 800
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            local coords = GetEntityCoords(ped)
            local distance = #(coords - Config.School.coords)
            if distance <= Config.InteractionDistance then
                waitTime = 0
                if not promptVisible then
                    exports['rp_ui']:ShowTextUI('[E] Accéder à l’auto-école')
                    promptVisible = true
                end
                if IsControlJustReleased(0, 38) then openSchool() end
            elseif promptVisible then
                exports['rp_ui']:HideTextUI()
                promptVisible = false
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
        if examVehicle and DoesEntityExist(examVehicle) and currentCheckpoint > 0 then
            local p = activeCheckpoints and activeCheckpoints[currentCheckpoint]
            if p then
                local target = vector3(p.x, p.y, p.z)
                local coords = GetEntityCoords(PlayerPedId())
                DrawMarker(1, target.x, target.y, target.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    5.0, 5.0, 2.0, 40, 160, 255, 120, false, true, 2, false, nil, nil, false)
                if #(coords - target) <= Config.CheckpointRadius then
                    TriggerServerEvent('rp_drivingschool:server:checkpointReached', currentCheckpoint)
                    currentCheckpoint = 0
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeTheory()
    if promptVisible then exports['rp_ui']:HideTextUI() end
    if schoolBlip and DoesBlipExist(schoolBlip) then RemoveBlip(schoolBlip) end
    if examVehicle and DoesEntityExist(examVehicle) then DeleteVehicle(examVehicle) end
end)
