-- rp_housing_business client
local isUIOpen = false

RegisterNetEvent('rp_housing:openAgency')
AddEventHandler('rp_housing:openAgency', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAgency' })
    isUIOpen = true
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    cb('ok')
end)

RegisterNUICallback('buyProperty', function(data, cb)
    TriggerServerEvent('rp_housing:buyProperty', data.id, data.price)
    cb('ok')
end)

RegisterNUICallback('rentProperty', function(data, cb)
    TriggerServerEvent('rp_housing:rentProperty', data.id, data.price)
    cb('ok')
end)

RegisterNUICallback('buyBusiness', function(data, cb)
    TriggerServerEvent('rp_housing:buyBusiness', data.id, data.price)
    cb('ok')
end)

RegisterNUICallback('rentBusiness', function(data, cb)
    TriggerServerEvent('rp_housing:rentBusiness', data.id, data.price)
    cb('ok')
end)

RegisterCommand('dynasty8', function()
    TriggerEvent('rp_housing:openAgency')
end, false)
