local territories = {}
local areaBlips = {}
local pointBlips = {}
local sectorPeds = {}
local uiOpen = false
local nearestSector = nil
local nearestDistance = nil

local function DebugLog(level, event, details)
    local caller = debug and debug.getinfo and debug.getinfo(2, 'Sl') or nil
    local source = caller and caller.short_src or 'client/main.lua'
    local line = caller and caller.currentline or 0
    local message = ('[rp_territories][CLIENT][%s:%d][%s] %s')
        :format(source, line, tostring(event), tostring(details or ''))
    if level == 'error' then
        print(('^1%s^7'):format(message))
    elseif level == 'warn' then
        print(('^3%s^7'):format(message))
    else
        print(('^5%s^7'):format(message))
    end
end

DebugLog('info', 'BOOT', 'Client territoires chargé')

local function RemoveMapBlips()
    for _, blip in ipairs(areaBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    for _, blip in ipairs(pointBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    areaBlips, pointBlips = {}, {}
end

local function GetGroundLevel(x, y, fallback)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, false)
    return found and groundZ or fallback
end

local function BuildMap()
    DebugLog('info', 'MAP_BUILD_START', ('Construction carte avec %d secteurs'):format(#Config.Sectors))
    RemoveMapBlips()
    for _, sector in ipairs(Config.Sectors) do
        local owned = territories[sector.id]
        local color = owned and tonumber(owned.color) or 0
        local alpha = owned and Config.AreaAlphaOwned or Config.AreaAlphaFree

        local area = AddBlipForArea(sector.x, sector.y, 0.0, Config.AreaSize, Config.AreaSize)
        SetBlipColour(area, color) -- 0 = blanc pour tout secteur libre.
        SetBlipAlpha(area, alpha)
        SetBlipDisplay(area, 2) -- Toujours visible sur la carte et la minimap.
        SetBlipAsShortRange(area, false)
        if not area or area == 0 then DebugLog('error', 'AREA_BLIP_FAILED', ('secteur=%s'):format(sector.id)) end
        areaBlips[#areaBlips + 1] = area

        local point = AddBlipForCoord(sector.x, sector.y, sector.z)
        SetBlipSprite(point, Config.PointBlipSprite)
        SetBlipScale(point, Config.PointBlipScale)
        SetBlipColour(point, color)
        SetBlipDisplay(point, 2)
        SetBlipAsShortRange(point, false)
        BeginTextCommandSetBlipName('STRING')
        if owned then
            AddTextComponentString(('Secteur %s - %s'):format(sector.id, owned.ownerName or 'Occupé'))
        else
            AddTextComponentString(('Secteur %s - À revendiquer'):format(sector.id))
        end
        EndTextCommandSetBlipName(point)
        if not point or point == 0 then DebugLog('error', 'POINT_BLIP_FAILED', ('secteur=%s'):format(sector.id)) end
        pointBlips[#pointBlips + 1] = point
    end
    DebugLog('info', 'MAP_BUILD_DONE', ('%d zones et %d points créés'):format(#areaBlips, #pointBlips))
end

RegisterNetEvent('rp_territories:client:sync', function(data)
    territories = type(data) == 'table' and data or {}
    local count = 0
    for _ in pairs(territories) do count = count + 1 end
    DebugLog('info', 'SYNC_RECEIVED', ('%d territoire(s) reçus du serveur'):format(count))
    local ok, err = xpcall(BuildMap, debug.traceback)
    if not ok then DebugLog('error', 'MAP_BUILD_CRASH', err) end
end)

RegisterNetEvent('rp_territories:client:openMenu', function(info)
    if type(info) ~= 'table' then
        DebugLog('error', 'OPEN_MENU_INVALID_DATA', ('type reçu=%s'):format(type(info)))
        return
    end
    DebugLog('info', 'OPEN_MENU_RECEIVED', ('secteur=%s'):format(tostring(info.sectorId)))
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', info = info })
end)

RegisterNetEvent('rp_territories:client:claimResult', function(result)
    if type(result) ~= 'table' then
        DebugLog('error', 'CLAIM_RESULT_INVALID', ('type reçu=%s'):format(type(result)))
        return
    end
    DebugLog(result.success and 'info' or 'warn', 'CLAIM_RESULT_RECEIVED', tostring(result.message))
    SendNUIMessage({ action = 'claimResult', result = result })
    if result.success then
        uiOpen = false
        SetNuiFocus(false, false)
    end
end)

RegisterNUICallback('claim', function(data, cb)
    if type(data) ~= 'table' then
        DebugLog('error', 'NUI_CLAIM_INVALID', 'Payload NUI non-tableau')
        cb({ ok = false })
        return
    end
    DebugLog('info', 'NUI_CLAIM_SUBMIT', ('secteur=%s | couleur=%s'):format(tostring(data.sectorId), tostring(data.colorId)))
    TriggerServerEvent('rp_territories:server:claim', data.sectorId, data.colorId)
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

local function DrawHelpText(message)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function LoadPedModel(modelName)
    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        DebugLog('error', 'PED_MODEL_INVALID', tostring(modelName))
        return nil
    end
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(model) then
        DebugLog('warn', 'PED_MODEL_TIMEOUT', tostring(modelName))
        return nil
    end
    return model
end

local function SpawnSectorPed(sector)
    if sectorPeds[sector.id] and DoesEntityExist(sectorPeds[sector.id]) then return end
    RequestCollisionAtCoord(sector.x, sector.y, sector.z)
    local groundFound, groundZ = false, sector.z
    for attempt = 1, 12 do
        groundFound, groundZ = GetGroundZFor_3dCoord(sector.x, sector.y, 1000.0, false)
        if groundFound then break end
        Wait(100)
    end
    if not groundFound then
        DebugLog('warn', 'PED_GROUND_NOT_FOUND', ('secteur=%s | x=%.1f | y=%.1f'):format(sector.id, sector.x, sector.y))
        return
    end

    local model = LoadPedModel(Config.PedModel or 'a_m_m_business_01')
    if not model then return end
    local ped = CreatePed(4, model, sector.x, sector.y, groundZ, 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        DebugLog('error', 'PED_CREATE_FAILED', ('secteur=%s'):format(sector.id))
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    sectorPeds[sector.id] = ped
    DebugLog('info', 'PED_SPAWNED', ('secteur=%s'):format(sector.id))
end

local function RemoveSectorPed(sectorId)
    local ped = sectorPeds[sectorId]
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
    end
    sectorPeds[sectorId] = nil
end

-- Les PNJ sont créés localement uniquement près du joueur pour éviter
-- de maintenir 60 entités chargées simultanément.
CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for _, sector in ipairs(Config.Sectors) do
            local dx, dy = coords.x - sector.x, coords.y - sector.y
            local distanceSquared = dx * dx + dy * dy
            if distanceSquared <= (Config.PedSpawnDistance * Config.PedSpawnDistance) then
                SpawnSectorPed(sector)
            elseif distanceSquared >= (Config.PedDespawnDistance * Config.PedDespawnDistance) then
                RemoveSectorPed(sector.id)
            end
        end
        Wait(1500)
    end
end)

CreateThread(function()
    Wait(1500)
    DebugLog('info', 'SYNC_REQUEST_SENT', 'Demande de synchronisation envoyée au serveur')
    TriggerServerEvent('rp_territories:server:requestSync')
    while true do
        Wait(350)
        if not uiOpen then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            nearestSector, nearestDistance = nil, nil
            for _, sector in ipairs(Config.Sectors) do
                local dx, dy = coords.x - sector.x, coords.y - sector.y
                local distanceSquared = dx * dx + dy * dy
                if not nearestDistance or distanceSquared < nearestDistance then
                    nearestDistance = distanceSquared
                    nearestSector = sector
                end
            end

            if nearestSector and nearestDistance <= (Config.InteractionDistance * Config.InteractionDistance) then
                local groundZ = GetGroundLevel(nearestSector.x, nearestSector.y, nearestSector.z)
                DrawMarker(1, nearestSector.x, nearestSector.y, groundZ + 0.15,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.8, 0.8, 0.35, 255, 255, 255, 150,
                    false, false, 2, false, nil, nil, false)
                DrawHelpText(('Appuie sur ~INPUT_CONTEXT~ pour gérer le secteur ~b~%s~s~'):format(nearestSector.id))
                if IsControlJustReleased(0, 38) then
                    DebugLog('info', 'CLAIM_POINT_INTERACT', ('secteur=%s'):format(nearestSector.id))
                    TriggerServerEvent('rp_territories:server:requestOpen', nearestSector.id)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DebugLog('info', 'RESOURCE_STOP', 'Nettoyage des blips et du focus NUI')
    RemoveMapBlips()
    for sectorId in pairs(sectorPeds) do RemoveSectorPed(sectorId) end
    if uiOpen then SetNuiFocus(false, false) end
end)
