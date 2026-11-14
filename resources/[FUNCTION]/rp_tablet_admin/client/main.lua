local isTabletOpen = false
local isAdminOpening = false
local lastAdminToggleAt = 0
local tabletEntity = nil
local tabletDict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
local tabletAnim = 'base'
local tabletModel = GetHashKey('prop_cs_tablet')
local isAdminNoclip = false
local isAdminGodmode = false
local isAdminSpectating = false
local spectateTargetPed = nil

-- Long-bracket pattern avoids quoting/line-break corruption in Lua weapon validation.
local WEAPON_NAME_PATTERN = [[^WEAPON_[A-Z0-9_]+$]]

local function Notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

function StopTabletAnimation()
    local ped = PlayerPedId()
    ClearPedSecondaryTask(ped)
    if tabletEntity and DoesEntityExist(tabletEntity) then
        DeleteEntity(tabletEntity)
    end
    tabletEntity = nil
    SetModelAsNoLongerNeeded(tabletModel)
end

function StartTabletAnimation()
    local ped = PlayerPedId()
    RequestAnimDict(tabletDict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(tabletDict) and GetGameTimer() < deadline do Wait(10) end
    if not HasAnimDictLoaded(tabletDict) then return end

    RequestModel(tabletModel)
    deadline = GetGameTimer() + 5000
    while not HasModelLoaded(tabletModel) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(tabletModel) then return end

    if tabletEntity and DoesEntityExist(tabletEntity) then DeleteEntity(tabletEntity) end
    tabletEntity = CreateObject(tabletModel, 0.0, 0.0, 0.0, true, true, false)
    if tabletEntity and tabletEntity ~= 0 then
        AttachEntityToEntity(tabletEntity, ped, GetPedBoneIndex(ped, 28422),
            -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        TaskPlayAnim(ped, tabletDict, tabletAnim, 3.0, 3.0, -1, 49, 0, false, false, false)
    else
        tabletEntity = nil
    end
    SetModelAsNoLongerNeeded(tabletModel)
end

function CloseAdminTablet()
    if isAdminSpectating then
        TriggerServerEvent('rp_tablet_admin:server:stopSpectate')
    end
    local wasOpen = isTabletOpen
    isTabletOpen = false
    isAdminOpening = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeTablet' })
    if wasOpen then StopTabletAnimation() end
end

function OpenAdminTablet()
    if isAdminOpening or isTabletOpen then return end
    isAdminOpening = true
    TriggerServerEvent('rp_tablet_admin:server:requestOpen')
    SetTimeout(7000, function()
        if isAdminOpening and not isTabletOpen then
            isAdminOpening = false
            Notify('La tablette administrateur ne répond pas. Vérifiez les permissions et la console serveur.', 'error')
        end
    end)
end


RegisterNetEvent('rp_tablet_admin:client:openAuthorized', function(adminData, playersList, jobsList, frozenPlayers, itemCatalog, weaponPolicy)
    isAdminOpening = false
    isTabletOpen = true
    StartTabletAnimation()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openTablet',
        admin = adminData or {},
        players = playersList or {},
        jobs = jobsList or {},
        items = itemCatalog or {},
        frozenPlayers = frozenPlayers or {},
        weaponPolicy = weaponPolicy or {}
    })
end)

RegisterNetEvent('rp_tablet_admin:client:openDenied', function(message)
    isAdminOpening = false
    Notify(tostring(message or 'Ouverture de la tablette administrateur refusée.'), 'error')
end)

local function ToggleAdminTablet()
    local now = GetGameTimer()
    if lastAdminToggleAt > 0 and now - lastAdminToggleAt < 500 then return end
    lastAdminToggleAt = now
    if isAdminOpening then return end

    if isAdminSpectating then
        TriggerServerEvent('rp_tablet_admin:server:stopSpectate')
    elseif isTabletOpen then
        CloseAdminTablet()
    else
        OpenAdminTablet()
    end
end

RegisterCommand('rp_admin_tablet_toggle', ToggleAdminTablet, false)
RegisterKeyMapping('rp_admin_tablet_toggle', 'Ouvrir la Tablette Admin', 'keyboard', 'F10')
RegisterCommand('admin', ToggleAdminTablet, false)
RegisterCommand('adminmenu', ToggleAdminTablet, false)

RegisterCommand('rapport', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openPlayerReport' })
end, false)

RegisterNUICallback('submitPlayerReport', function(data, cb)
    local message = type(data) == 'table' and data.message or ''
    TriggerServerEvent('rp_tablet_admin:server:submitPlayerReport', message)
    cb({ ok = true })
end)

RegisterNUICallback('closePlayerReport', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePlayerReport' })
    cb({ ok = true })
end)

RegisterNUICallback('close', function(data, cb)
    if type(data) == 'table' and data.source == 'f10' then
        lastAdminToggleAt = GetGameTimer()
    end
    CloseAdminTablet()
    cb('ok')
end)

local function RegisterServerCallback(name, eventName, fields)
    RegisterNUICallback(name, function(data, cb)
        data = type(data) == 'table' and data or {}
        local args = {}
        for i = 1, #fields do args[i] = data[fields[i]] end
        TriggerServerEvent(eventName, table.unpack(args))
        cb('ok')
    end)
end

RegisterServerCallback('spectatePlayer', 'rp_tablet_admin:server:spectatePlayer', { 'playerId' })
RegisterServerCallback('stopSpectate', 'rp_tablet_admin:server:stopSpectate', {})
RegisterServerCallback('toggleNoclip', 'rp_tablet_admin:server:toggleNoclip', {})
RegisterServerCallback('toggleGodmode', 'rp_tablet_admin:server:toggleGodmode', {})
RegisterServerCallback('spawnVehicle', 'rp_tablet_admin:server:spawnVehicle', { 'model' })
RegisterServerCallback('giveVehicle', 'rp_tablet_admin:server:giveVehicle', { 'playerId', 'model' })
RegisterServerCallback('giveWeapon', 'rp_tablet_admin:server:giveWeapon', { 'playerId', 'weapon' })
RegisterServerCallback('saveWeaponPolicy', 'rp_tablet_admin:server:saveWeaponPolicy', { 'policy' })
RegisterServerCallback('giveItem', 'rp_tablet_admin:server:giveItem', { 'playerId', 'item', 'count' })
RegisterServerCallback('banPlayer', 'rp_tablet_admin:server:banPlayer', { 'playerId', 'reason' })
RegisterServerCallback('kickPlayer', 'rp_tablet_admin:server:kickPlayer', { 'playerId', 'reason' })
RegisterServerCallback('freezePlayer', 'rp_tablet_admin:server:freezePlayer', { 'playerId', 'freeze' })
RegisterServerCallback('teleportToPlayer', 'rp_tablet_admin:server:teleportToPlayer', { 'playerId' })
RegisterServerCallback('bringPlayer', 'rp_tablet_admin:server:bringPlayer', { 'playerId' })
RegisterServerCallback('healPlayer', 'rp_tablet_admin:server:healPlayer', { 'playerId' })
RegisterServerCallback('revivePlayer', 'rp_tablet_admin:server:revivePlayer', { 'playerId' })
RegisterServerCallback('manageEconomy', 'rp_tablet_admin:server:manageEconomy',
    { 'playerId', 'type', 'amount', 'operation' })
RegisterServerCallback('setJob', 'rp_tablet_admin:server:setJob',
    { 'playerId', 'jobName', 'grade' })
RegisterServerCallback('setWeatherTime', 'rp_tablet_admin:server:setWeatherTime',
    { 'weather', 'hours', 'minutes' })
RegisterServerCallback('broadcastAnnouncement', 'rp_tablet_admin:server:broadcastAnnouncement',
    { 'message' })
RegisterServerCallback('requestPlayerPositions', 'rp_tablet_admin:server:requestPlayerPositions', {})
RegisterServerCallback('teleportToMapPoint', 'rp_tablet_admin:server:teleportToMapPoint', { 'x', 'y' })
RegisterServerCallback('requestAuditLogs', 'rp_tablet_admin:server:requestAuditLogs', {})
RegisterServerCallback('requestReports', 'rp_tablet_admin:server:requestReports', {})
RegisterServerCallback('updateReport', 'rp_tablet_admin:server:updateReport', { 'reportId', 'status' })

RegisterNetEvent('rp_tablet_admin:client:weaponPolicySaveFailed', function(message)
    SendNUIMessage({ action = 'weaponPolicySaveFailed', message = tostring(message or 'Enregistrement impossible.') })
end)

RegisterNetEvent('rp_tablet_admin:client:weaponPolicySaved', function(policy)
    SendNUIMessage({ action = 'weaponPolicySaved', weaponPolicy = policy or {} })
end)

RegisterNetEvent('rp_tablet_admin:client:economyResult', function(result)
    result = type(result) == 'table' and result or {}
    local message = tostring(result.message or 'Opération économique terminée.')
    if isTabletOpen then
        SendNUIMessage({ action = 'economyResult', result = result })
    else
        Notify(message, result.success == true and 'success' or 'error')
    end
end)

RegisterNetEvent('rp_tablet_admin:client:auditLogs', function(logs)
    SendNUIMessage({ action = 'auditLogs', logs = logs or {} })
end)

RegisterNetEvent('rp_tablet_admin:client:playerPositions', function(players)
    SendNUIMessage({ action = 'playerPositions', players = players or {} })
end)

RegisterNetEvent('rp_tablet_admin:client:reports', function(reports)
    SendNUIMessage({ action = 'reports', reports = reports or {} })
end)

RegisterNetEvent('rp_tablet_admin:client:reportUpdated', function(reportId, status, handledBy)
    SendNUIMessage({ action = 'reportUpdated', reportId = reportId, status = status, handledBy = handledBy })
end)

RegisterNetEvent('rp_tablet_admin:client:startSpectate', function(targetId, targetCoords)
    if isTabletOpen then
        isTabletOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeTablet' })
        StopTabletAnimation()
    end

    if type(targetCoords) ~= 'table'
        or not tonumber(targetCoords.x)
        or not tonumber(targetCoords.y)
        or not tonumber(targetCoords.z) then
        Notify('Coordonnées de surveillance invalides.', 'error')
        return
    end

    local x, y, z = tonumber(targetCoords.x), tonumber(targetCoords.y), tonumber(targetCoords.z)
    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(x, y, z)

    local deadline = GetGameTimer() + 10000
    local playerIndex, targetPed = -1, 0
    repeat
        playerIndex = GetPlayerFromServerId(tonumber(targetId) or -1)
        if playerIndex ~= -1 and NetworkIsPlayerActive(playerIndex) then
            targetPed = GetPlayerPed(playerIndex)
            if targetPed ~= 0 and DoesEntityExist(targetPed) then break end
        end
        Wait(100)
    until GetGameTimer() >= deadline

    if playerIndex == -1 or targetPed == 0 or not DoesEntityExist(targetPed) then
        ClearFocus()
        Notify('Joueur non disponible dans la zone de streaming.', 'error')
        return
    end

    spectateTargetPed = targetPed
    isAdminSpectating = true
    NetworkSetInSpectatorMode(true, targetPed)
    Notify('Surveillance activée. Appuyez sur F10 pour arrêter.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:client:stopSpectate', function()
    if not isAdminSpectating then return end
    NetworkSetInSpectatorMode(false, spectateTargetPed or PlayerPedId())
    ClearFocus()
    isAdminSpectating = false
    spectateTargetPed = nil
    Notify('Surveillance arrêtée.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:client:toggleGodmode', function(enabled)
    isAdminGodmode = enabled == true
    local invincible = isAdminGodmode or isAdminNoclip
    SetPlayerInvincible(PlayerId(), invincible)
    SetEntityInvincible(PlayerPedId(), invincible)
    Notify(isAdminGodmode and 'GodMode activé.' or 'GodMode désactivé.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:client:toggleNoclip', function(enabled, quiet)
    isAdminNoclip = enabled == true
    local ped = PlayerPedId()
    SetEntityCollision(ped, not isAdminNoclip, not isAdminNoclip)
    SetEntityInvincible(ped, isAdminNoclip or isAdminGodmode)
    SetPlayerInvincible(PlayerId(), isAdminNoclip or isAdminGodmode)
    if not quiet then
        Notify(isAdminNoclip and 'NoClip activé. WASD / Espace / Ctrl pour bouger.' or 'NoClip désactivé.', 'info')
    end

    if isAdminNoclip then
        CreateThread(function()
            while isAdminNoclip do
                Wait(0)
                ped = PlayerPedId()
                local camRot = GetGameplayCamRot(2)
                local pitch = math.rad(camRot.x)
                local heading = math.rad(camRot.z)
                local forward = vector3(-math.sin(heading) * math.cos(pitch),
                    math.cos(heading) * math.cos(pitch), math.sin(pitch))
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

local function CreateAdminVehicle(model, offset)
    if type(model) ~= 'string' or not model:match('^[%w_]+$') then
        Notify('Modèle de véhicule invalide.', 'error')
        return
    end

    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        Notify('Modèle de véhicule inconnu ou invalide.', 'error')
        return
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then
        Notify('Chargement du véhicule impossible.', 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, offset or 4.0, 0.0)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, true)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(hash)
        Notify('Création impossible : vérifiez les restrictions d’entités du serveur.', 'error')
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetModelAsNoLongerNeeded(hash)
    return vehicle
end

RegisterNetEvent('rp_tablet_admin:client:spawnVehicle', function(model)
    local vehicle = CreateAdminVehicle(model, 4.0)
    if vehicle then Notify('Véhicule créé : ' .. model, 'success') end
end)

RegisterNetEvent('rp_tablet_admin:client:spawnVehicleForPlayer', function(model)
    local vehicle = CreateAdminVehicle(model, 5.0)
    if vehicle then
        SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
        Notify('Un véhicule vous a été attribué par un administrateur.', 'success')
    end
end)

RegisterNetEvent('rp_tablet_admin:client:giveWeapon', function(weaponName, ammo)
    if type(weaponName) ~= 'string' or not weaponName:match(WEAPON_NAME_PATTERN) then
        return
    end

    local hash = GetHashKey(weaponName)
    if not IsWeaponValid(hash) then return end

    ammo = math.max(0, math.min(9999, math.floor(tonumber(ammo) or 120)))
    GiveWeaponToPed(PlayerPedId(), hash, ammo, false, false)
    SetPedAmmo(PlayerPedId(), hash, ammo)
    Notify('Arme reçue et sauvegardée : ' .. weaponName:gsub('^WEAPON_', ''), 'success')
end)

RegisterNetEvent('rp_tablet_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('rp_tablet_admin:client:freezeToggle', function(freeze)
    FreezeEntityPosition(PlayerPedId(), freeze == true)
end)

RegisterNetEvent('rp_tablet_admin:client:teleportToMapPoint', function(coords)
    if type(coords) ~= 'table' or not tonumber(coords.x) or not tonumber(coords.y) then return end
    local x, y = tonumber(coords.x), tonumber(coords.y)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, 1000.0)
    SetFocusPosAndVel(x, y, 1000.0, 0.0, 0.0, 0.0)
    local found, groundZ = false, 0.0
    local deadline = GetGameTimer() + 5000
    while GetGameTimer() < deadline do
        found, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, false)
        if found then break end
        RequestCollisionAtCoord(x, y, 1000.0)
        Wait(50)
    end
    local z = found and (groundZ + 1.0) or 100.0
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    ClearFocus()
    Notify('Téléportation effectuée au point défini sur la carte.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:client:teleport', function(coords)
    if type(coords) ~= 'table' or not tonumber(coords.x)
        or not tonumber(coords.y) or not tonumber(coords.z) then return end
    local ped = PlayerPedId()
    SetEntityCoords(ped, tonumber(coords.x), tonumber(coords.y), tonumber(coords.z), false, false, false, true)
end)

RegisterNetEvent('rp_tablet_admin:client:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(PlayerPedId(), 200)
    ClearPedBloodDamage(PlayerPedId())
end)

RegisterNetEvent('rp_tablet_admin:client:syncWeather', function(weather)
    if type(weather) ~= 'string' then return end
    SetWeatherTypeOverTime(weather, 10.0)
    Wait(1000)
    ClearOverrideWeather()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
end)

RegisterNetEvent('rp_tablet_admin:client:syncTime', function(hours, minutes)
    hours, minutes = tonumber(hours), tonumber(minutes)
    if not hours or not minutes or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then return end
    NetworkOverrideClockTime(hours, minutes, 0)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isTabletOpen = false
    isAdminOpening = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeTablet' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isAdminNoclip = false
    if isAdminSpectating then
        NetworkSetInSpectatorMode(false, spectateTargetPed or PlayerPedId())
        ClearFocus()
    end
    isAdminSpectating = false
    spectateTargetPed = nil
    local ped = PlayerPedId()
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeTablet' })
    StopTabletAnimation()
end)


RegisterNetEvent('rp_tablet_admin:client:playerReportResult', function(success, message)
    SendNUIMessage({ action = 'playerReportResult', success = success == true, message = tostring(message or '') })
    if success then
        SetNuiFocus(false, false)
    else
        Notify(tostring(message or 'Signalement impossible.'), 'error')
    end
end)
RegisterNetEvent('rp_tablet_admin:client:reportsRefresh', function()
    if isTabletOpen then TriggerServerEvent('rp_tablet_admin:server:requestReports') end
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isAdminNoclip = false
    isAdminGodmode = false
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)
    end
    SetPlayerInvincible(PlayerId(), false)
end)
