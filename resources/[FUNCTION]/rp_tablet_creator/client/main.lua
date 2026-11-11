local isOpen = false

local function closeTablet()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function requestOpen()
    TriggerServerEvent('rp_tablet_creator:server:requestOpen')
end

RegisterCommand('creator', requestOpen, false)
RegisterKeyMapping('creator', 'Ouvrir la tablette Créateur', 'keyboard', 'F11')

RegisterNetEvent('rp_tablet_creator:client:open', function(role)
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', role = role or 'Créateur' })
    TriggerServerEvent('rp_tablet_creator:server:requestTools')
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('setWorld', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:setWorld', data.weather, data.hours, data.minutes)
    cb({ ok = true })
end)

RegisterNUICallback('broadcast', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:broadcast', data.message)
    cb({ ok = true })
end)


RegisterNUICallback('spawnProp', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:spawnProp', data.model)
    cb({ ok = true })
end)

RegisterNUICallback('deleteProp', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:deleteProp', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('saveJobBlip', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:saveJobBlip', data)
    cb({ ok = true })
end)

RegisterNUICallback('refreshTools', function(_, cb)
    TriggerServerEvent('rp_tablet_creator:server:requestTools')
    cb({ ok = true })
end)

RegisterNUICallback('setServerSettings', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:setServerSettings', data)
    cb({ ok = true })
end)

RegisterNUICallback('setModuleState', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:setModuleState', data.name, data.enabled)
    cb({ ok = true })
end)

RegisterNUICallback('updatePlayerIdentity', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:updatePlayerIdentity', data)
    cb({ ok = true })
end)

RegisterNUICallback('updatePlayerBalances', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:updatePlayerBalances', data)
    cb({ ok = true })
end)

RegisterNUICallback('updatePlayerJob', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:updatePlayerJob', data)
    cb({ ok = true })
end)

RegisterNUICallback('updatePlayerInventory', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:updatePlayerInventory', data)
    cb({ ok = true })
end)

RegisterNUICallback('updatePlayerAccess', function(data, cb)
    TriggerServerEvent('rp_tablet_creator:server:updatePlayerAccess', data)
    cb({ ok = true })
end)

RegisterNetEvent('rp_tablet_creator:client:refreshTools', function()
    if isOpen then TriggerServerEvent('rp_tablet_creator:server:requestTools') end
end)

RegisterNetEvent('rp_tablet_creator:client:toolsData', function(jobs, blips, mapping, catalog, players, items, settings, modules)
    local coords = GetEntityCoords(PlayerPedId())
    SendNUIMessage({
        action = 'toolsData', jobs = jobs or {}, blips = blips or {}, mapping = mapping or {},
        catalog = catalog or {}, position = { x = coords.x, y = coords.y, z = coords.z },
        players = players or {}, items = items or {}, settings = settings or {}, modules = modules or {}
    })
end)

RegisterNetEvent('rp_tablet_creator:client:mappingAdded', function(item)
    SendNUIMessage({ action = 'mappingAdded', item = item })
end)

RegisterNetEvent('rp_tablet_creator:client:mappingRemoved', function(id)
    SendNUIMessage({ action = 'mappingRemoved', id = id })
end)

local activeJobBlips = {}
local function refreshJobBlips(rows)
    for _, blip in ipairs(activeJobBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    activeJobBlips = {}
    local data = exports['rp_core']:GetPlayerData()
    local jobName = data and data.job or 'unemployed'
    for _, item in ipairs(rows or {}) do
        if tostring(item.job) == tostring(jobName) and (item.enabled == true or tonumber(item.enabled) == 1) then
            local blip = AddBlipForCoord(tonumber(item.x), tonumber(item.y), tonumber(item.z))
            SetBlipSprite(blip, tonumber(item.sprite) or 1)
            SetBlipColour(blip, tonumber(item.color) or 0)
            SetBlipScale(blip, tonumber(item.scale) or 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(tostring(item.label or item.job))
            EndTextCommandSetBlipName(blip)
            activeJobBlips[#activeJobBlips + 1] = blip
        end
    end
end

RegisterNetEvent('rp_tablet_creator:client:syncJobBlips', function(rows)
    refreshJobBlips(rows)
end)

RegisterNetEvent('rp_core:client:setPlayerData', function()
    TriggerServerEvent('rp_tablet_creator:server:requestJobBlips')
end)
RegisterNetEvent('rp_core:client:setJob', function()
    TriggerServerEvent('rp_tablet_creator:server:requestJobBlips')
end)
RegisterNetEvent('rp_tablet_creator:client:jobBlips', function(rows)
    refreshJobBlips(rows)
end)

RegisterNetEvent('rp_tablet_creator:client:result', function(message, success)
    SendNUIMessage({ action = 'result', message = tostring(message or ''), success = success == true })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeTablet()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isOpen = false
    SetNuiFocus(false, false)
end)
