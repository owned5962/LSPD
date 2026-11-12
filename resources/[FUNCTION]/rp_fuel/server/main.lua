local pendingRefuels = {}
local vehicleFuel = {}
local lastFuelUpdate = {}
local nextRefuelId = 0

local function notify(src, message, kind)
    if src and GetPlayerName(src) then
        TriggerClientEvent('rp_core:client:notify', src, message, kind or 'error')
    end
end

local function isAtStation(coords)
    local ok, stations = pcall(function()
        return exports['rp_businesses']:GetLocationsByType('gas_station')
    end)
    if not ok or type(stations) ~= 'table' then return false end
    for _, station in ipairs(stations) do
        if #(coords - vector3(station.x, station.y, station.z)) <= FuelConfig.StationRadius then
            return true
        end
    end
    return false
end

local function validPayment(value)
    return value == 'cash' or value == 'bank' or value == 'auto'
end

local function updateBalanceClient(src, player)
    if not src or not GetPlayerName(src) or not player then return end
    TriggerClientEvent('rp_core:client:updateCash', src, player.cash)
    TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
end

local function refundPayment(pending, reason)
    local column = pending.account == 'cash' and 'cash' or 'bank'
    local locks = { pending.charId }

    CreateThread(function()
        for attempt = 1, 20 do
            if exports['rp_core']:AcquireCharacterLock(locks) then
                local ok, affected = pcall(MySQL.update.await,
                    ('UPDATE characters SET %s = %s + ? WHERE id = ? AND identifier = ?'):format(column, column),
                    { pending.amount, pending.charId, pending.identifier })
                exports['rp_core']:ReleaseCharacterLock(locks)

                if ok and tonumber(affected) == 1 then
                    local player = exports['rp_core']:GetPlayerFromId(pending.source)
                    if player and player.charId == pending.charId then
                        if pending.account == 'cash' then
                            player.cash = player.cash + pending.amount
                        else
                            player.bank = player.bank + pending.amount
                        end
                        updateBalanceClient(pending.source, player)
                        notify(pending.source, 'Paiement remboursé : ' .. pending.amount .. ' $ (' .. reason .. ').', 'warning')
                    end
                    TriggerEvent('rp_economy:server:logTransaction', pending.charId, 'fuel_refund',
                        pending.amount, 'Station-service', 'Remboursement : ' .. reason)
                    return
                end
            end
            Wait(250)
        end
        print(('[rp_fuel] CRITICAL: refund failed for character %s, amount %s'):format(
            tostring(pending.charId), tostring(pending.amount)))
    end)
end

local function cancelRefuel(netId, pending, reason)
    if pendingRefuels[netId] ~= pending then return end
    pendingRefuels[netId] = nil
    lastFuelUpdate[netId] = GetGameTimer()
    refundPayment(pending, reason)
    TriggerClientEvent('rp_fuel:client:purchaseResult', pending.source, false,
        'Ravitaillement annulé : ' .. reason .. '. Le remboursement est lancé.', netId)
end

local function completeRefuel(netId, pending)
    if pendingRefuels[netId] ~= pending then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        cancelRefuel(netId, pending, 'véhicule introuvable')
        return
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    if not isAtStation(vehicleCoords) or #(vehicleCoords - pending.vehicleStartCoords) > FuelConfig.VehicleMovementTolerance then
        cancelRefuel(netId, pending, 'le véhicule a été déplacé')
        return
    end

    local player = exports['rp_core']:GetPlayerFromId(pending.source)
    if not player or player.charId ~= pending.charId then
        cancelRefuel(netId, pending, 'le personnage a été déconnecté')
        return
    end

    local ped = GetPlayerPed(pending.source)
    if ped == 0 or not DoesEntityExist(ped)
        or #(GetEntityCoords(ped) - vehicleCoords) > FuelConfig.VehiclePlayerRadius then
        cancelRefuel(netId, pending, 'vous vous êtes éloigné du véhicule')
        return
    end

    local serverFuel = vehicleFuel[netId]
    if not serverFuel or math.abs(serverFuel - pending.startFuel) > 1.0 then
        cancelRefuel(netId, pending, 'le niveau du réservoir a changé')
        return
    end

    pendingRefuels[netId] = nil
    vehicleFuel[netId] = pending.newFuel
    lastFuelUpdate[netId] = GetGameTimer()
    Entity(vehicle).state:set('rpFuel', pending.newFuel, true)
    TriggerClientEvent('rp_fuel:client:setFuel', -1, netId, pending.newFuel)
    TriggerClientEvent('rp_fuel:client:purchaseResult', pending.source, true,
        ('Ravitaillement terminé : %d L ajoutés · %d $ payés par %s.'):format(
            pending.litres, pending.amount, pending.account == 'cash' and 'espèces' or 'la banque'),
        netId, pending.newFuel)
end

RegisterNetEvent('rp_fuel:server:purchase', function(rawNetId, rawLitres, payment)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'fuel:purchase', 1500) then return end

    local litres, netId = tonumber(rawLitres), tonumber(rawNetId)
    if not litres or litres % 1 ~= 0 or litres < 1 or litres > 100
        or not netId or netId < 1 or netId % 1 ~= 0 then
        notify(src, 'Quantité de carburant ou véhicule invalide.')
        return
    end
    if not validPayment(payment) then
        notify(src, 'Moyen de paiement invalide.')
        return
    end
    if pendingRefuels[netId] then
        notify(src, 'Ce véhicule est déjà en cours de ravitaillement.', 'warning')
        return
    end

    local player = exports['rp_core']:GetPlayerFromId(src)
    local ped = GetPlayerPed(src)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not player or not ped or ped == 0 or not DoesEntityExist(ped)
        or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(src, 'Véhicule ou personnage introuvable.')
        return
    end

    local playerCoords, vehicleCoords = GetEntityCoords(ped), GetEntityCoords(vehicle)
    if not isAtStation(playerCoords) or not isAtStation(vehicleCoords)
        or #(playerCoords - vehicleCoords) > FuelConfig.VehiclePlayerRadius then
        notify(src, 'Placez votre véhicule près d’une pompe pour faire le plein.')
        return
    end

    -- The authoritative fuel value is maintained by this server resource.
    -- Entity state bags are only replicated to clients; they are not trusted as input.
    local currentFuel = vehicleFuel[netId]
    if currentFuel == nil then
        currentFuel = 100.0
        vehicleFuel[netId] = currentFuel
        lastFuelUpdate[netId] = GetGameTimer()
        Entity(vehicle).state:set('rpFuel', currentFuel, true)
    end
    if type(currentFuel) ~= 'number' or currentFuel ~= currentFuel
        or currentFuel < 0 or currentFuel > 100 then
        notify(src, 'Niveau de carburant serveur invalide. Réessayez plus tard.')
        return
    end
    local availableLitres = math.max(0, math.floor(100 - currentFuel))
    if litres > availableLitres then
        notify(src, ('Le réservoir ne peut recevoir que %d L supplémentaires.'):format(availableLitres))
        return
    end

    local amount = litres * FuelConfig.PricePerLitre
    local account = payment == 'auto' and (player.cash >= amount and 'cash' or 'bank') or payment
    local balance = account == 'cash' and player.cash or player.bank
    if balance < amount then
        notify(src, ('Fonds insuffisants : %d $ nécessaires.'):format(amount))
        return
    end

    local locks = { player.charId }
    if not exports['rp_core']:AcquireCharacterLock(locks) then
        notify(src, 'Votre compte est occupé. Réessayez dans un instant.', 'warning')
        return
    end

    local column = account == 'cash' and 'cash' or 'bank'
    local ok, affected = pcall(MySQL.update.await,
        ('UPDATE characters SET %s = %s - ? WHERE id = ? AND identifier = ? AND %s >= ?'):format(column, column, column),
        { amount, player.charId, player.identifier, amount })
    exports['rp_core']:ReleaseCharacterLock(locks)

    if not ok or tonumber(affected) ~= 1 then
        notify(src, 'Paiement refusé : solde insuffisant ou base de données indisponible.')
        return
    end

    if account == 'cash' then player.cash = player.cash - amount
    else player.bank = player.bank - amount end
    updateBalanceClient(src, player)
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'fuel', amount,
        'Station-service', ('Paiement de %d L de carburant'):format(litres))

    nextRefuelId = nextRefuelId + 1
    local durationMs = FuelConfig.BaseFillMilliseconds + (litres * FuelConfig.MillisecondsPerLitre)
    local pending = {
        id = nextRefuelId,
        source = src,
        charId = player.charId,
        identifier = player.identifier,
        account = account,
        amount = amount,
        litres = litres,
        startFuel = currentFuel,
        newFuel = math.min(100, currentFuel + litres),
        vehicleStartCoords = vehicleCoords,
        startedAt = os.time()
    }
    pendingRefuels[netId] = pending

    TriggerClientEvent('rp_fuel:client:fuelingStarted', src, netId, durationMs,
        litres, amount, account)
    SetTimeout(durationMs, function()
        if pendingRefuels[netId] == pending then completeRefuel(netId, pending) end
    end)
end)

CreateThread(function()
    -- Server-owned fuel simulation. Clients only receive the replicated value and
    -- can no longer raise their tank by writing an entity state bag.
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for _, vehicle in ipairs(GetAllVehicles()) do
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId and netId > 0 then
                    if vehicleFuel[netId] == nil then
                        vehicleFuel[netId] = 100.0
                        lastFuelUpdate[netId] = now
                        Entity(vehicle).state:set('rpFuel', 100.0, true)
                    elseif not pendingRefuels[netId] then
                        local previous = lastFuelUpdate[netId] or now
                        local elapsed = math.max(0, math.min(5000, now - previous)) / 1000.0
                        local current = vehicleFuel[netId]
                        local consumption = GetEntitySpeed(vehicle) * 0.00022 * elapsed
                        if consumption > 0 and current > 0 then
                            current = math.max(0.0, current - consumption)
                            vehicleFuel[netId] = current
                        end

                        -- Reassert the server value if the network owner tries to
                        -- overwrite the replicated state bag from a modified client.
                        if tonumber(Entity(vehicle).state.rpFuel) ~= current then
                            Entity(vehicle).state:set('rpFuel', current, true)
                        end
                        lastFuelUpdate[netId] = now
                    end
                end
            end
        end
    end
end)

AddEventHandler('entityRemoved', function(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId > 0 then
        vehicleFuel[netId] = nil
        lastFuelUpdate[netId] = nil
        pendingRefuels[netId] = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for netId, pending in pairs(pendingRefuels) do
        pendingRefuels[netId] = nil
        refundPayment(pending, 'redémarrage de la ressource')
    end
end)
