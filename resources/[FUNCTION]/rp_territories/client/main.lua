local territories = {}
local areaBlips = {}
local pointBlips = {}
local uiOpen = false
local nearestSector = nil
local nearestDistance = nil

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
    RemoveMapBlips()
    for _, sector in ipairs(Config.Sectors) do
        local owned = territories[sector.id]
        local color = owned and tonumber(owned.color) or 0
        local alpha = owned and Config.AreaAlphaOwned or Config.AreaAlphaFree

        local area = AddBlipForArea(sector.x, sector.y, 0.0, Config.AreaSize, Config.AreaSize)
        SetBlipColour(area, color)
        SetBlipAlpha(area, alpha)
        SetBlipAsShortRange(area, false)
        areaBlips[#areaBlips + 1] = area

        local point = AddBlipForCoord(sector.x, sector.y, sector.z)
        SetBlipSprite(point, Config.PointBlipSprite)
        SetBlipScale(point, Config.PointBlipScale)
        SetBlipColour(point, color)
        SetBlipAsShortRange(point, false)
        BeginTextCommandSetBlipName('STRING')
        if owned then
            AddTextComponentString(('Secteur %s - %s'):format(sector.id, owned.ownerName or 'Occupé'))
        else
            AddTextComponentString(('Secteur %s - À revendiquer'):format(sector.id))
        end
        EndTextCommandSetBlipName(point)
        pointBlips[#pointBlips + 1] = point
    end
end

RegisterNetEvent('rp_territories:client:sync', function(data)
    territories = type(data) == 'table' and data or {}
    BuildMap()
end)

RegisterNetEvent('rp_territories:client:openMenu', function(info)
    if type(info) ~= 'table' then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', info = info })
end)

RegisterNetEvent('rp_territories:client:claimResult', function(result)
    if type(result) ~= 'table' then return end
    SendNUIMessage({ action = 'claimResult', result = result })
    if result.success then
        uiOpen = false
        SetNuiFocus(false, false)
    end
end)

RegisterNUICallback('claim', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }) return end
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

CreateThread(function()
    Wait(1500)
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
                    TriggerServerEvent('rp_territories:server:requestOpen', nearestSector.id)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveMapBlips()
    if uiOpen then SetNuiFocus(false, false) end
end)
