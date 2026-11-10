local isOpen = false

local function closeTablet()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function requestOpen()
    TriggerServerEvent('rp_police_mdt:server:requestOpen')
end

RegisterCommand('mdt', requestOpen, false)
RegisterKeyMapping('mdt', 'Ouvrir la tablette MDT LSPD', 'keyboard', 'F6')

RegisterNetEvent('rp_police_mdt:client:open', function(data)
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('rp_police_mdt:client:updateData', function(data)
    if isOpen then
        SendNUIMessage({ action = 'updateData', data = data })
    end
end)

RegisterNetEvent('rp_police_mdt:client:close', closeTablet)

RegisterNetEvent('rp_police_mdt:client:waypoint', function(coords, label)
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' then return end
    SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
    TriggerEvent('rp_core:client:notify', 'GPS défini : ' .. (label or 'citoyen'), 'success')
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('rp_police_mdt:server:requestData')
    cb({ ok = true })
end)

RegisterNUICallback('locateCitizen', function(data, cb)
    TriggerServerEvent('rp_police_mdt:server:locateCitizen', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('acceptDispatch', function(data, cb)
    local id = tonumber(data and data.id)
    if id then
        TriggerServerEvent('rp_crime:server:acceptDispatch', id)
        SetTimeout(700, function()
            TriggerServerEvent('rp_police_mdt:server:requestData')
        end)
    end
    cb({ ok = id ~= nil })
end)

RegisterNetEvent('rp_police_mdt:client:requestRefresh', function()
    TriggerServerEvent('rp_police_mdt:server:requestData')
end)
