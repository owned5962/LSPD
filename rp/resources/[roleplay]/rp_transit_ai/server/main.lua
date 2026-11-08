-- rp_transit_ai server
RegisterNetEvent('rp_transit:payAndSpawnTaxi')
AddEventHandler('rp_transit:payAndSpawnTaxi', function(dest, drivingStyle)
    local _source = source
    local price = dest.price or 50

    local bank = exports['rp_economy']:GetBank(_source)
    if bank >= price then
        exports['rp_economy']:RemoveBank(_source, price)
        TriggerClientEvent('rp_transit:startTaxiTrip', _source, dest, drivingStyle)
    else
        local cash = exports['rp_economy']:GetCash(_source)
        if cash >= price then
            exports['rp_economy']:RemoveCash(_source, price)
            TriggerClientEvent('rp_transit:startTaxiTrip', _source, dest, drivingStyle)
        else
            TriggerClientEvent('chat:addMessage', _source, {
                color = { 239, 68, 68 },
                multiline = true,
                args = { "LST DISPATCH", "Fonds insuffisants ($" .. price .. " requis)." }
            })
        end
    end
end)

RegisterNetEvent('rp_transit:payAndSpawnBus')
AddEventHandler('rp_transit:payAndSpawnBus', function(route)
    local _source = source
    local price = route.price or 15

    exports['rp_economy']:RemoveCash(_source, price)
    TriggerClientEvent('chat:addMessage', _source, {
        color = { 59, 130, 246 },
        multiline = true,
        args = { "LST BUS IA", "Ticket acheté pour " .. route.name .. " ($" .. price .. "). Le bus est en approche !" }
    })
end)
