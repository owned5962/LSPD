local PRICE_PER_LITRE = 6
local Stations = {
    vector3(-724.6, -935.2, 8.9), vector3(-70.2, -1761.8, 29.5),
    vector3(265.0, -1261.3, 29.3), vector3(819.6, -1028.2, 26.4),
    vector3(1208.3, -1402.3, 35.2), vector3(1181.4, -330.8, 69.3),
    vector3(620.8, 269.1, 103.0), vector3(2581.0, 362.0, 108.5),
    vector3(2005.0, 3774.0, 32.2), vector3(1687.2, 4929.2, 42.1),
    vector3(1701.3, 6416.0, 32.8), vector3(179.9, 6602.8, 31.9),
    vector3(-2555.5, 2334.0, 33.1), vector3(-2096.2, -320.3, 13.2),
    vector3(-1437.6, -276.7, 46.2), vector3(-1800.1, 803.5, 138.5)
}
local function isAtStation(coords)
    for _, station in ipairs(Stations) do if #(coords - station) <= 22.0 then return true end end
    return false
end
local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'error')
end

RegisterNetEvent('rp_fuel:server:purchase', function(rawNetId, rawLitres, payment, rawCurrentFuel)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'fuel:purchase', 2500) then return end
    local litres, netId = tonumber(rawLitres), tonumber(rawNetId)
    if not litres or litres % 1 ~= 0 or litres < 1 or litres > 100 or not netId or netId < 1 then
        notify(src, 'Quantité de carburant invalide.'); return
    end
    if payment ~= 'cash' and payment ~= 'bank' and payment ~= 'auto' then notify(src, 'Moyen de paiement invalide.'); return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local ped = GetPlayerPed(src)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not player or not ped or ped == 0 or not DoesEntityExist(ped) or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(src, 'Véhicule ou personnage introuvable.'); return
    end
    local playerCoords, vehicleCoords = GetEntityCoords(ped), GetEntityCoords(vehicle)
    if not isAtStation(playerCoords) or not isAtStation(vehicleCoords) or #(playerCoords - vehicleCoords) > 18.0 then
        notify(src, 'Vous devez être près d’une pompe et de votre véhicule.'); return
    end
    local amount = litres * PRICE_PER_LITRE
    local account = payment == 'auto' and (player.cash >= amount and 'cash' or 'bank') or payment
    local balance = account == 'cash' and player.cash or player.bank
    if balance < amount then
        notify(src, ('Fonds insuffisants : %s $ nécessaires (%s).'):format(amount, account == 'cash' and 'espèces' or 'banque'))
        return
    end

    local locks = { player.charId }
    if not exports['rp_core']:AcquireCharacterLock(locks) then notify(src, 'Votre compte est déjà utilisé. Réessayez.', 'warning'); return end
    local column = account == 'cash' and 'cash' or 'bank'
    local ok, affected = pcall(MySQL.update.await,
        ('UPDATE characters SET %s = %s - ? WHERE id = ? AND identifier = ? AND %s >= ?'):format(column, column, column),
        { amount, player.charId, player.identifier, amount })
    exports['rp_core']:ReleaseCharacterLock(locks)
    if not ok or tonumber(affected) ~= 1 then
        notify(src, 'Paiement refusé : solde insuffisant ou erreur bancaire.'); return
    end

    if account == 'cash' then player.cash = player.cash - amount else player.bank = player.bank - amount end
    local currentFuel = tonumber(rawCurrentFuel) or 0
    currentFuel = math.max(0, math.min(100, currentFuel))
    local newFuel = math.min(100, currentFuel + litres)
    Entity(vehicle).state:set('rpFuel', newFuel, true)
    TriggerClientEvent('rp_core:client:updateCash', src, player.cash)
    TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'withdraw', amount, 'Station-service', ('Achat de %s L de carburant'):format(litres))
    TriggerClientEvent('rp_fuel:client:purchaseResult', src, true,
        ('Plein effectué : %s L · %s $ payés par %s.'):format(litres, amount, account == 'cash' and 'espèces' or 'banque'),
        netId, newFuel)
end)
