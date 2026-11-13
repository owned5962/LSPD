local rentals = {}

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function findLocation(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    for key, location in pairs(Config.Locations) do
        local point = location.ped
        local dx, dy = coords.x - point.x, coords.y - point.y
        local horizontalDistance = math.sqrt(dx * dx + dy * dy)
        local verticalDistance = math.abs(coords.z - point.z)
        if horizontalDistance <= (tonumber(Config.InteractionDistance) or 2.0) and verticalDistance <= 3.0 then
            return key
        end
    end
    return nil
end

local function getVehicle(model)
    if type(model) ~= 'string' then return nil end
    for _, vehicle in ipairs(Config.Vehicles) do
        if vehicle.model == model then return vehicle end
    end
    return nil
end

local function validDuration(rawMinutes)
    local minutes = tonumber(rawMinutes)
    if not minutes or minutes % 1 ~= 0 or minutes < Config.MinMinutes
        or minutes > Config.MaxHours * 60 or minutes % 10 ~= 0 then return nil end
    return minutes
end

local function rentalCost(minutes)
    return math.floor(minutes / 10) * Config.PricePerTenMinutes
end

local function chargePlayer(src, amount, reason)
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or type(player.removeCash) ~= 'function' then return false end
    if (tonumber(player.cash) or 0) < amount then return false end
    local ok, result = pcall(player.removeCash, amount)
    if not ok then
        print(('[rp_vehicle_rental] Cash debit failed for %s: %s'):format(src, tostring(result)))
        return false
    end
    if result ~= true then return false end
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'withdraw', amount,
        'Location de véhicules', reason)
    return true, player
end

local function refundRental(src, rental, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return true end

    local player = exports['rp_core']:GetPlayerFromId(src)
    if player and player.charId == rental.charId and type(player.addCash) == 'function' then
        local ok, refunded = pcall(player.addCash, amount, reason or 'Remboursement location', 'deposit')
        if ok and refunded == true then
            TriggerEvent('rp_economy:server:logTransaction', rental.charId, 'deposit', amount,
                'Location de véhicules', reason or 'Remboursement location')
            return true
        end
        print(('[rp_vehicle_rental] CRITICAL: refund failed for player %s, amount %s'):format(src, amount))
        return false
    end

    local ok, affected = pcall(MySQL.update.await,
        'UPDATE characters SET cash = cash + ? WHERE id = ? AND identifier = ?',
        { amount, rental.charId, rental.identifier })
    if ok and tonumber(affected) == 1 then
        TriggerEvent('rp_economy:server:logTransaction', rental.charId, 'deposit', amount,
            'Location de véhicules', reason or 'Remboursement location')
        return true
    end

    print(('[rp_vehicle_rental] CRITICAL: offline refund failed for character %s, amount %s'):format(
        tostring(rental.charId), amount))
    return false
end

local function closeRental(src, reason, refundAmount)
    local rental = rentals[src]
    if not rental then return end
    rentals[src] = nil
    if rental.netId then
        local entity = NetworkGetEntityFromNetworkId(rental.netId)
        if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    if refundAmount and refundAmount > 0 then
        refundRental(src, rental, refundAmount, reason or 'Location annulée')
    end
    TriggerClientEvent('rp_vehicle_rental:client:forceReturn', src, rental.netId, reason or 'Location terminée')
end

RegisterNetEvent('rp_vehicle_rental:server:openTablet', function(locationKey)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'vehicle_rental:open', 1000) then
        TriggerClientEvent('rp_vehicle_rental:client:openDenied', src, 'Patientez avant de rouvrir la location.')
        return
    end
    local actualLocation = findLocation(src)
    if not actualLocation or actualLocation ~= locationKey then
        TriggerClientEvent('rp_vehicle_rental:client:openDenied', src,
            'Approchez-vous du vendeur situé devant le bâtiment de location.')
        return
    end
    if rentals[src] then
        TriggerClientEvent('rp_vehicle_rental:client:openDenied', src,
            'Vous avez déjà un véhicule en location.')
        return
    end
    TriggerClientEvent('rp_vehicle_rental:client:openTablet', src, false, Config.Vehicles,
        Config.PricePerTenMinutes, Config.MaxHours, nil, actualLocation)
end)

RegisterNetEvent('rp_vehicle_rental:server:rent', function(locationKey, model, rawMinutes)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'vehicle_rental:rent', 1500) then
        notify(src, 'Patientez avant de confirmer une nouvelle location.', 'warning')
        return
    end
    local actualLocation = findLocation(src)
    local vehicle = getVehicle(model)
    local minutes = validDuration(rawMinutes)
    if not actualLocation or actualLocation ~= locationKey or not vehicle or not minutes then
        notify(src, 'Demande de location invalide.', 'error')
        return
    end
    if rentals[src] then
        notify(src, 'Une location est déjà active.', 'error')
        return
    end

    local cost = rentalCost(minutes)
    local paid, player = chargePlayer(src, cost, ('Location %s - %s minutes'):format(vehicle.label, minutes))
    if not paid or not player then
        notify(src, 'Fonds insuffisants ou débit impossible.', 'error')
        return
    end

    local expiresAt = os.time() + (minutes * 60)
    rentals[src] = {
        charId = player.charId,
        identifier = player.identifier,
        location = actualLocation,
        model = vehicle.model,
        label = vehicle.label,
        minutes = minutes,
        expiresAt = expiresAt,
        netId = nil,
        amount = cost,
        graceUntil = nil
    }
    TriggerClientEvent('rp_vehicle_rental:client:spawnRental', src, {
        model = vehicle.model,
        label = vehicle.label,
        location = Config.Locations[actualLocation].vehicle,
        expiresAt = expiresAt,
        minutes = minutes
    })
    notify(src, ('Location confirmée : %s pour %d minutes (%d $).'):format(vehicle.label, minutes, cost), 'success')
end)

RegisterNetEvent('rp_vehicle_rental:server:registerVehicle', function(netId)
    local src = source
    local rental = rentals[src]
    netId = tonumber(netId)
    if not rental or not netId or netId < 1 or netId % 1 ~= 0 then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityModel(entity) ~= joaat(rental.model)
        or NetworkGetEntityOwner(entity) ~= src
        or #(GetEntityCoords(entity) - vector3(Config.Locations[rental.location].vehicle.x,
            Config.Locations[rental.location].vehicle.y, Config.Locations[rental.location].vehicle.z)) > 60.0 then
        -- Never delete an arbitrary client-owned entity from an untrusted netId.
        closeRental(src, 'Le véhicule n’a pas pu être enregistré. Paiement remboursé.', rental.amount)
        return
    end
    rental.netId = netId
end)

RegisterNetEvent('rp_vehicle_rental:server:spawnFailed', function()
    local src = source
    local rental = rentals[src]
    if not rental or rental.netId then return end
    closeRental(src, 'Location annulée : le véhicule n’a pas pu être créé. Paiement remboursé.', rental.amount)
    notify(src, 'Location annulée : le véhicule n’a pas pu être créé. Votre paiement a été remboursé.', 'error')
end)

RegisterNetEvent('rp_vehicle_rental:server:renew', function(rawMinutes)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'vehicle_rental:renew', 1500) then
        notify(src, 'Patientez avant de confirmer la prolongation.', 'warning')
        return
    end
    local rental = rentals[src]
    local minutes = validDuration(rawMinutes)
    if not rental or not rental.graceUntil or os.time() > rental.graceUntil or not minutes then
        notify(src, 'Le délai de prolongation est dépassé.', 'error')
        closeRental(src, 'Délai de prolongation dépassé')
        return
    end
    local cost = rentalCost(minutes)
    if not chargePlayer(src, cost, ('Prolongation location %s - %s minutes'):format(rental.label, minutes)) then
        notify(src, 'Fonds insuffisants pour prolonger la location.', 'error')
        return
    end
    rental.expiresAt = os.time() + (minutes * 60)
    rental.graceUntil = nil
    rental.minutes = minutes
    rental.amount = cost
    TriggerClientEvent('rp_vehicle_rental:client:renewed', src, rental.expiresAt, minutes)
    notify(src, ('Location prolongée de %d minutes pour %d $.'):format(minutes, cost), 'success')
end)

RegisterNetEvent('rp_vehicle_rental:server:decline', function()
    local src = source
    local rental = rentals[src]
    if not rental or not rental.graceUntil then return end
    closeRental(src, 'Vous avez refusé la prolongation')
end)

local function calculateUnusedRefund(rental, now)
    local duration = math.max(1, (tonumber(rental.minutes) or 1) * 60)
    local remaining = rental.netId and math.max(0, math.min(duration, (tonumber(rental.expiresAt) or now) - now)) or duration
    return math.floor((tonumber(rental.amount) or 0) * remaining / duration)
end

AddEventHandler('playerDropped', function()
    local src = source
    local rental = rentals[src]
    if rental then
        if rental.netId then
            local entity = NetworkGetEntityFromNetworkId(rental.netId)
            if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
        end
        local refund = calculateUnusedRefund(rental, os.time())
        if refund > 0 then refundRental(src, rental, refund, 'Remboursement après déconnexion') end
    end
    rentals[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local now = os.time()
    for src, rental in pairs(rentals) do
        if rental.netId then
            local entity = NetworkGetEntityFromNetworkId(rental.netId)
            if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
        end
        local refund = calculateUnusedRefund(rental, now)
        if refund > 0 then refundRental(src, rental, refund, 'Remboursement après redémarrage de la location') end
        rentals[src] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for src, rental in pairs(rentals) do
            if not GetPlayerName(src) then
                rentals[src] = nil
            elseif rental.expiresAt and now >= rental.expiresAt and not rental.graceUntil then
                rental.graceUntil = now + Config.ExpiryGraceSeconds
                TriggerClientEvent('rp_vehicle_rental:client:renewalRequired', src, Config.ExpiryGraceSeconds,
                    rental.label, Config.PricePerTenMinutes, Config.MaxHours)
            elseif rental.graceUntil and now >= rental.graceUntil then
                closeRental(src, 'Temps de prolongation écoulé')
            end
        end
    end
end)
