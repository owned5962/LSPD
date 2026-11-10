local isTabletOpen = false
local tabletEntity = nil
local tabletDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local tabletAnim = "base"
local tabletModel = GetHashKey('prop_cs_tablet')

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
