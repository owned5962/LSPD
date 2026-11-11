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
RegisterKeyMapping('creator', 'Ouvrir la tablette Créateur', 'keyboard', 'F9')

RegisterNetEvent('rp_tablet_creator:client:open', function(role)
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', role = role or 'Créateur' })
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
