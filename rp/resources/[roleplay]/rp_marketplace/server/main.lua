-- rp_marketplace server
local activeListings = {}

RegisterNetEvent('rp_marketplace:publishAd')
AddEventHandler('rp_marketplace:publishAd', function(adData)
    local _source = source
    local fee = 50

    local cash = exports['rp_economy']:GetCash(_source)
    if cash >= fee then
        exports['rp_economy']:RemoveCash(_source, fee)
        table.insert(activeListings, adData)
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 16, 185, 129 },
            multiline = true,
            args = { "MARKETPLACE", "Votre annonce '" .. adData.title .. "' a été publiée avec succès !" }
        })
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 239, 68, 68 },
            multiline = true,
            args = { "MARKETPLACE", "Frais de parution ($50) insuffisants en liquide." }
        })
    end
end)

RegisterNetEvent('rp_marketplace:buyListing')
AddEventHandler('rp_marketplace:buyListing', function(adId, price)
    local _source = source
    local bank = exports['rp_economy']:GetBank(_source)
    if bank >= price then
        exports['rp_economy']:RemoveBank(_source, price)
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 16, 185, 129 },
            multiline = true,
            args = { "MARKETPLACE", "Achat effectué avec succès pour $" .. price .. " ! L'objet/véhicule est à vous." }
        })
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 239, 68, 68 },
            multiline = true,
            args = { "MARKETPLACE", "Solde bancaire insuffisant." }
        })
    end
end)
