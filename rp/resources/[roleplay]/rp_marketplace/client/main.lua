-- rp_marketplace client
local isUIOpen = false

RegisterNetEvent('rp_marketplace:open')
AddEventHandler('rp_marketplace:open', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMarketplace' })
    isUIOpen = true
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    cb('ok')
end)

RegisterNUICallback('publishAd', function(data, cb)
    TriggerServerEvent('rp_marketplace:publishAd', data)
    cb('ok')
end)

RegisterNUICallback('buyListing', function(data, cb)
    TriggerServerEvent('rp_marketplace:buyListing', data.id, data.price)
    cb('ok')
end)

RegisterCommand('marketplace', function()
    TriggerEvent('rp_marketplace:open')
end, false)
