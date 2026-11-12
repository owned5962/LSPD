local pendingPurchases = {}
local plateLocks = {}

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function findDealer(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    for _, dealer in ipairs(Config.Dealerships) do
        if #(coords - dealer.coords) <= Config.ServerInteractionDistance then
            return dealer
        end
    end
    return nil
end

local function findVehicle(model)
    if type(model) ~= 'string' then return nil end
    for _, vehicle in ipairs(Config.Vehicles) do
        if vehicle.model == model then return vehicle end
    end
    return nil
end

local function generatePlate()
    local alphabet = 'ABCDEFGHJKLMNPRSTUVWXYZ'
    for _ = 1, 30 do
        local letters = ''
        for i = 1, 3 do
            local index = math.random(1, #alphabet)
            letters = letters .. alphabet:sub(index, index)
        end
        local plate = ('%s %03d'):format(letters, math.random(0, 999))
        local exists = MySQL.scalar.await('SELECT 1 FROM rp_owned_vehicles WHERE plate = ? LIMIT 1', { plate })
        if not exists and not plateLocks[plate] then
            plateLocks[plate] = true
            return plate
        end
    end
    return nil
end

local function refundPurchase(src, purchase, reason)
    pendingPurchases[src] = nil
    if purchase and purchase.plate then plateLocks[purchase.plate] = nil end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if player and type(player.addBank) == 'function' then
        local ok, refunded = pcall(player.addBank, purchase.price, 'Remboursement achat véhicule', 'deposit')
        if not ok or refunded ~= true then
            print(('[rp_vehicle_dealership] Échec remboursement joueur %s : %s'):format(src, tostring(reason)))
        end
    end
    TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src,
        reason or 'La création du véhicule a échoué. Votre paiement a été remboursé.')
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS rp_owned_vehicles (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                character_id BIGINT UNSIGNED NOT NULL,
                identifier VARCHAR(80) NOT NULL,
                plate VARCHAR(12) NOT NULL,
                model VARCHAR(60) NOT NULL,
                label VARCHAR(120) NOT NULL,
                price INT UNSIGNED NOT NULL,
                dealership VARCHAR(80) NOT NULL,
                stored TINYINT(1) NOT NULL DEFAULT 0,
                vehicle_props LONGTEXT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_rp_owned_vehicles_plate (plate),
                KEY idx_rp_owned_vehicles_character (character_id),
                KEY idx_rp_owned_vehicles_identifier (identifier)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end)
    if not ok then
        print(('[rp_vehicle_dealership] Initialisation SQL impossible : %s'):format(tostring(err)))
    else
        print('[rp_vehicle_dealership] Registre des véhicules personnels prêt.')
    end
end)

RegisterNetEvent('rp_vehicle_dealership:server:open', function(dealerId)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'vehicle_dealership:open', 1200) then
        TriggerClientEvent('rp_vehicle_dealership:client:openDenied', src, 'Patientez avant de rouvrir le catalogue.')
        return
    end
    local dealer = findDealer(src)
    if not dealer or dealer.id ~= dealerId then
        TriggerClientEvent('rp_vehicle_dealership:client:openDenied', src,
            'Vous devez être à moins de 1,5 mètre du point d’accueil du concessionnaire.')
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then
        TriggerClientEvent('rp_vehicle_dealership:client:openDenied', src, 'Votre personnage n’est pas encore chargé.')
        return
    end
    TriggerClientEvent('rp_vehicle_dealership:client:open', src, {
        dealer = dealer.id,
        label = dealer.label,
        bank = tonumber(player.bank) or 0,
        vehicles = Config.Vehicles
    })
end)

RegisterNetEvent('rp_vehicle_dealership:server:purchase', function(dealerId, model)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'vehicle_dealership:purchase', Config.PurchaseCooldown) then
        TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src, 'Veuillez patienter avant un nouvel achat.')
        return
    end
    if pendingPurchases[src] then
        TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src, 'Un achat est déjà en cours.')
        return
    end

    local dealer = findDealer(src)
    local vehicle = findVehicle(model)
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not dealer or dealer.id ~= dealerId or not vehicle or not player then
        TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src, 'Demande d’achat invalide.')
        return
    end
    if not MySQL.scalar.await("SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'rp_owned_vehicles'") then
        TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src, 'Le registre des véhicules est indisponible. Réessayez plus tard.')
        return
    end
    if (tonumber(player.bank) or 0) < vehicle.price then
        TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src, 'Solde bancaire insuffisant.')
        return
    end

    local plate = generatePlate()
    if not plate then
        TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src, 'Impossible de générer une plaque. Réessayez.')
        return
    end

    local ok, paid = pcall(player.removeBank, vehicle.price, ('Achat %s'):format(vehicle.label), 'withdraw')
    if not ok or paid ~= true then
        plateLocks[plate] = nil
        TriggerClientEvent('rp_vehicle_dealership:client:purchaseFailed', src, 'Le paiement bancaire a échoué. Aucun achat effectué.')
        return
    end

    pendingPurchases[src] = {
        charId = player.charId,
        identifier = player.identifier,
        dealer = dealer,
        model = vehicle.model,
        label = vehicle.label,
        price = vehicle.price,
        plate = plate,
        createdAt = os.time()
    }
    TriggerClientEvent('rp_vehicle_dealership:client:spawnPurchased', src, {
        model = vehicle.model,
        plate = plate,
        spawn = dealer.spawn
    })
end)

RegisterNetEvent('rp_vehicle_dealership:server:registerPurchasedVehicle', function(netId)
    local src = source
    local purchase = pendingPurchases[src]
    netId = tonumber(netId)
    if not purchase or os.time() - purchase.createdAt > 45 or not netId or netId < 1 or netId % 1 ~= 0 then
        if purchase then refundPurchase(src, purchase, 'La validation du véhicule a expiré. Paiement remboursé.') end
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local expected = purchase.dealer.spawn
    if entity == 0 or not DoesEntityExist(entity)
        or GetEntityModel(entity) ~= joaat(purchase.model)
        or NetworkGetEntityOwner(entity) ~= src
        or #(GetEntityCoords(entity) - vector3(expected.x, expected.y, expected.z)) > 35.0 then
        refundPurchase(src, purchase, 'Le véhicule n’a pas pu être validé. Paiement remboursé.')
        return
    end

    local ok, inserted = pcall(MySQL.insert.await, [[
        INSERT INTO rp_owned_vehicles
            (character_id, identifier, plate, model, label, price, dealership, stored, vehicle_props)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
    ]], {
        purchase.charId, purchase.identifier, purchase.plate, purchase.model,
        purchase.label, purchase.price, purchase.dealer.id,
        json.encode({ model = purchase.model, plate = purchase.plate })
    })
    if not ok or not inserted then
        refundPurchase(src, purchase, 'Enregistrement impossible en base de données. Paiement remboursé.')
        print(('[rp_vehicle_dealership] SQL ownership insert failed: %s'):format(tostring(inserted)))
        return
    end

    pendingPurchases[src] = nil
    plateLocks[purchase.plate] = nil
    TriggerClientEvent('rp_vehicle_dealership:client:purchaseConfirmed', src, purchase.plate)
    -- removeBank() journalise déjà le débit dans rp_economy.
    print(('[rp_vehicle_dealership] %s purchased %s (%s), character %s'):format(
        GetPlayerName(src) or src, purchase.model, purchase.plate, purchase.charId))
end)

RegisterNetEvent('rp_vehicle_dealership:server:spawnFailed', function()
    local src = source
    local purchase = pendingPurchases[src]
    if purchase then refundPurchase(src, purchase, 'Le véhicule n’a pas pu sortir du magasin. Paiement remboursé.') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local purchase = pendingPurchases[src]
    if purchase then
        -- If the player disconnects during delivery, the purchase is cancelled and refunded.
        refundPurchase(src, purchase, 'Achat annulé après déconnexion.')
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, purchase in pairs(pendingPurchases) do
            if now - purchase.createdAt > 45 then
                refundPurchase(src, purchase, 'Délai dépassé : achat annulé et remboursé.')
            end
        end
    end
end)

exports('GetOwnedVehicles', function(characterId)
    characterId = tonumber(characterId)
    if not characterId then return {} end
    return MySQL.query.await(
        'SELECT id, plate, model, label, price, dealership, stored, created_at FROM rp_owned_vehicles WHERE character_id = ? ORDER BY id DESC',
        { characterId }
    ) or {}
end)
