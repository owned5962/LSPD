local isTabletOpen = false
local tabletEntity = nil
local tabletDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local tabletAnim = "base"
local tabletModel = `prop_cs_tablet`

function OpenAdminTablet()
    TriggerServerEvent('rp_tablet_admin:server:requestOpen')
end

function CloseAdminTablet()
    if not isTabletOpen then return end
    isTabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeTablet" })
    StopTabletAnimation()
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

RegisterNetEvent('rp_tablet_admin:client:openAuthorized', function(adminData, playersList, jobsList)
    isTabletOpen = true
    StartTabletAnimation()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openTablet",
        admin = adminData,
        players = playersList,
        jobs = jobsList
    })
end)

RegisterCommand('admin', function()
    OpenAdminTablet()
end, false)

RegisterKeyMapping('admin', 'Ouvrir la Tablette Admin', 'keyboard', 'F10')

RegisterNUICallback('close', function(data, cb)
    CloseAdminTablet()
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

RegisterNUICallback('spawnVehicle', function(data, cb)
    local model = data.model
    if not model or model == '' then return cb('error') end
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        TriggerEvent('rp_core:client:notify', 'Modèle de véhicule invalide ou inexistant.', 'error')
        return cb('error')
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    TriggerEvent('rp_core:client:notify', 'Véhicule apparu: ' .. model, 'success')
    cb('ok')
end)

RegisterNUICallback('deleteVehicle', function(data, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and DoesEntityExist(veh) then
        DeleteEntity(veh)
        TriggerEvent('rp_core:client:notify', 'Véhicule supprimé.', 'info')
    else
        local coords = GetEntityCoords(ped)
        local closeVeh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
        if closeVeh and DoesEntityExist(closeVeh) then
            DeleteEntity(closeVeh)
            TriggerEvent('rp_core:client:notify', 'Véhicule proche supprimé.', 'info')
        end
    end
    cb('ok')
end)

RegisterNUICallback('setWeatherTime', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:setWeatherTime', data.weather, tonumber(data.hours), tonumber(data.minutes))
    cb('ok')
end)

RegisterNUICallback('broadcastAnnouncement', function(data, cb)
    TriggerServerEvent('rp_tablet_admin:server:broadcastAnnouncement', data.message)
    cb('ok')
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

RegisterNetEvent('rp_tablet_admin:client:syncTime', function(hours, minutes)
    NetworkOverrideClockTime(hours, minutes, 0)
end)
