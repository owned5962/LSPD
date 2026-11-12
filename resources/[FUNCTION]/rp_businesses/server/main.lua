local cachedLocations = {}
local LOCATION_TABLE = 'rp_world_locations'

local function addSeed(rows, locationType, key, name, style, icon, coords, blip)
    rows[#rows + 1] = {
        location_key = key,
        location_type = locationType,
        name = name,
        shop_style = style,
        icon = icon,
        x = tonumber(coords[1]),
        y = tonumber(coords[2]),
        z = tonumber(coords[3]),
        blip_enabled = blip.enabled ~= false,
        blip_sprite = tonumber(blip.sprite) or 1,
        blip_display = tonumber(blip.display) or 4,
        blip_scale = tonumber(blip.scale) or 0.7,
        blip_colour = tonumber(blip.colour) or 0,
        short_range = blip.shortRange ~= false
    }
end

local function buildSeedLocations()
    local rows = {}
    for _, category in ipairs(BusinessLocations or {}) do
        for index, point in ipairs(category.points or {}) do
            addSeed(rows, 'shop', ('shop:%s:%d'):format(category.id, index),
                category.label, category.id, category.icon or category.id, point,
                { sprite = category.sprite, colour = category.colour, scale = category.id == 'nightclub' and 0.9 or 0.72 })
        end
    end

    for index, point in ipairs(ATMBlipLocations or {}) do
        addSeed(rows, 'atm', ('atm:%d'):format(index), 'Distributeur automatique',
            nil, 'atm', point, { sprite = 277, colour = 2, scale = 0.55 })
    end

    for index, point in ipairs(BankLocations or {}) do
        addSeed(rows, 'bank', ('bank:%d'):format(index), point[4] or 'Guichet bancaire',
            nil, 'bank', point, { sprite = 108, colour = 2, scale = 0.8 })
    end

    for index, point in ipairs(GasStationLocations or {}) do
        addSeed(rows, 'gas_station', ('gas_station:%d'):format(index), 'Station-service',
            nil, 'fuel', point, { sprite = 361, colour = 5, scale = 0.68 })
    end
    return rows
end

local function loadLocations()
    local rows = MySQL.query.await(('SELECT location_key, location_type, name, shop_style, icon, x, y, z, blip_enabled, blip_sprite, blip_display, blip_scale, blip_colour, short_range FROM %s WHERE enabled = 1 ORDER BY location_type, location_key'):format(LOCATION_TABLE))
    cachedLocations = rows or {}
    print(('[rp_businesses] %d lieux chargés depuis MySQL.'):format(#cachedLocations))
end

local function initializeLocations()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS %s (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            location_key VARCHAR(100) NOT NULL,
            location_type ENUM('atm','bank','shop','gas_station') NOT NULL,
            name VARCHAR(120) NOT NULL,
            shop_style VARCHAR(60) NULL,
            icon VARCHAR(60) NOT NULL,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            blip_enabled TINYINT(1) NOT NULL DEFAULT 1,
            blip_sprite INT NOT NULL DEFAULT 1,
            blip_display INT NOT NULL DEFAULT 4,
            blip_scale DECIMAL(4,2) NOT NULL DEFAULT 0.70,
            blip_colour INT NOT NULL DEFAULT 0,
            short_range TINYINT(1) NOT NULL DEFAULT 1,
            enabled TINYINT(1) NOT NULL DEFAULT 1,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_rp_world_locations_key (location_key),
            KEY idx_rp_world_locations_type (location_type, enabled)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]):format(LOCATION_TABLE))

    local seeds = buildSeedLocations()
    for _, location in ipairs(seeds) do
        MySQL.insert.await(([[
            INSERT IGNORE INTO %s
                (location_key, location_type, name, shop_style, icon, x, y, z,
                 blip_enabled, blip_sprite, blip_display, blip_scale, blip_colour, short_range)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]]):format(LOCATION_TABLE), {
            location.location_key, location.location_type, location.name, location.shop_style,
            location.icon, location.x, location.y, location.z,
            location.blip_enabled and 1 or 0, location.blip_sprite, location.blip_display,
            location.blip_scale, location.blip_colour, location.short_range and 1 or 0
        })
    end
    loadLocations()
end

exports('GetLocations', function()
    local result = {}
    for index, row in ipairs(cachedLocations) do result[index] = row end
    return result
end)

exports('GetLocationsByType', function(locationType)
    local result = {}
    for _, row in ipairs(cachedLocations) do
        if row.location_type == locationType then result[#result + 1] = row end
    end
    return result
end)

RegisterNetEvent('rp_businesses:server:requestLocations', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'businesses:locations', 1000) then return end
    TriggerClientEvent('rp_businesses:client:locations', src, cachedLocations)
end)

MySQL.ready(function()
    local ok, err = pcall(initializeLocations)
    if not ok then
        print(('[rp_businesses] Initialisation MySQL impossible: %s'):format(tostring(err)))
    end
end)


-- Catalogue Ammu-Nation : prix, armes et munitions définis exclusivement côté serveur.
local AMMUNATION_INTERACTION_RADIUS = 1.5
local AMMUNATION_VERTICAL_TOLERANCE = 2.0
local AMMUNATION_WEAPONS = {
    weapon_pistol = { label = 'Pistolet standard', weapon = 'WEAPON_PISTOL', price = 500, ammo = 60, category = 'Pistolets', image = '🔫' },
    weapon_mp5 = { label = 'MP5', weapon = 'WEAPON_SMG', price = 2500, ammo = 30, category = 'Mitraillettes', image = '🔫' },
    weapon_knife = { label = 'Couteau', weapon = 'WEAPON_KNIFE', price = 250, ammo = 0, category = 'Corps-à-corps', image = '🔪' },
    weapon_nightstick = { label = 'Matraque', weapon = 'WEAPON_NIGHTSTICK', price = 200, ammo = 0, category = 'Corps-à-corps', image = '🦯' },
    weapon_bat = { label = 'Batte de baseball', weapon = 'WEAPON_BAT', price = 150, ammo = 0, category = 'Corps-à-corps', image = '🏏' },
    weapon_crowbar = { label = 'Pied-de-biche', weapon = 'WEAPON_CROWBAR', price = 180, ammo = 0, category = 'Corps-à-corps', image = '🔧' },
    weapon_hammer = { label = 'Marteau', weapon = 'WEAPON_HAMMER', price = 150, ammo = 0, category = 'Corps-à-corps', image = '🔨' },
    weapon_golfclub = { label = 'Club de golf', weapon = 'WEAPON_GOLFCLUB', price = 220, ammo = 0, category = 'Corps-à-corps', image = '⛳' },
    weapon_knuckle = { label = 'Poing américain', weapon = 'WEAPON_KNUCKLE', price = 300, ammo = 0, category = 'Corps-à-corps', image = '🥊' },
    weapon_machete = { label = 'Machette', weapon = 'WEAPON_MACHETE', price = 350, ammo = 0, category = 'Corps-à-corps', image = '🗡️' },
    weapon_flashlight = { label = 'Lampe torche', weapon = 'WEAPON_FLASHLIGHT', price = 100, ammo = 0, category = 'Corps-à-corps', image = '🔦' },
    weapon_bottle = { label = 'Bouteille cassée', weapon = 'WEAPON_BOTTLE', price = 50, ammo = 0, category = 'Corps-à-corps', image = '🍾' },
    weapon_dagger = { label = 'Dague antique', weapon = 'WEAPON_DAGGER', price = 400, ammo = 0, category = 'Corps-à-corps', image = '🗡️' },
    weapon_hatchet = { label = 'Hachette', weapon = 'WEAPON_HATCHET', price = 300, ammo = 0, category = 'Corps-à-corps', image = '🪓' },
    weapon_switchblade = { label = 'Couteau à cran d’arrêt', weapon = 'WEAPON_SWITCHBLADE', price = 350, ammo = 0, category = 'Corps-à-corps', image = '🔪' },
    weapon_poolcue = { label = 'Queue de billard', weapon = 'WEAPON_POOLCUE', price = 150, ammo = 0, category = 'Corps-à-corps', image = '🎱' },
    weapon_wrench = { label = 'Clé à molette', weapon = 'WEAPON_WRENCH', price = 180, ammo = 0, category = 'Corps-à-corps', image = '🔧' },
    weapon_battleaxe = { label = 'Hache de combat', weapon = 'WEAPON_BATTLEAXE', price = 500, ammo = 0, category = 'Corps-à-corps', image = '🪓' },
    weapon_stone_hatchet = { label = 'Hachette en pierre', weapon = 'WEAPON_STONE_HATCHET', price = 450, ammo = 0, category = 'Corps-à-corps', image = '🪓' },
    weapon_candycane = { label = 'Canne en sucre', weapon = 'WEAPON_CANDYCANE', price = 100, ammo = 0, category = 'Corps-à-corps', image = '🍬' }
}

local function getAmmunationLocations()
    local locations = {}
    for _, location in ipairs(cachedLocations) do
        if location.location_type == 'shop' and location.shop_style == 'ammunation' then
            locations[#locations + 1] = location
        end
    end
    for _, category in ipairs(BusinessLocations or {}) do
        if category.id == 'ammunation' then
            for index, point in ipairs(category.points or {}) do
                locations[#locations + 1] = {
                    location_type = 'shop', shop_style = 'ammunation',
                    location_key = ('shop:ammunation:%d'):format(index),
                    x = point[1], y = point[2], z = point[3]
                }
            end
        end
    end
    return locations
end

local function getPlayerAtAmmunation(src)
    local player = exports['rp_core']:GetPlayerFromId(src)
    local ped = GetPlayerPed(src)
    if not player or ped == 0 or not DoesEntityExist(ped) then return nil end
    local playerCoords = GetEntityCoords(ped)
    for _, location in ipairs(getAmmunationLocations()) do
        local x, y, z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
        if x and y and z then
            local dx, dy = playerCoords.x - x, playerCoords.y - y
            if math.sqrt(dx * dx + dy * dy) <= AMMUNATION_INTERACTION_RADIUS
                and math.abs(playerCoords.z - z) <= AMMUNATION_VERTICAL_TOLERANCE then
                return player
            end
        end
    end
    return nil
end

local function buildAmmunationCatalog()
    local products = {}
    for itemName, weapon in pairs(AMMUNATION_WEAPONS) do
        products[#products + 1] = {
            item = itemName, label = weapon.label, price = weapon.price,
            category = weapon.category, image = weapon.image
        }
    end
    table.sort(products, function(a, b)
        if a.category == b.category then return a.label < b.label end
        return a.category < b.category
    end)
    return products
end

RegisterNetEvent('rp_businesses:server:requestAmmunation', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'businesses:open_ammunation', 1000) then
        TriggerClientEvent('rp_businesses:client:openDenied', src, 'Patientez avant de rouvrir Ammu-Nation.')
        return
    end
    local player = getPlayerAtAmmunation(src)
    if not player then
        TriggerClientEvent('rp_businesses:client:openDenied', src, 'Vous devez être à moins de 1,5 mètre du comptoir Ammu-Nation.')
        return
    end
    TriggerClientEvent('rp_businesses:client:openAmmunation', src,
        tonumber(player.cash) or 0, buildAmmunationCatalog())
end)

local function purchaseAmmunationWeapon(src, itemName)
    local definition = type(itemName) == 'string' and AMMUNATION_WEAPONS[itemName] or nil
    if not definition then
        TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
            success = false, message = 'Arme inconnue dans le catalogue Ammu-Nation.'
        })
        return
    end
    if not exports['rp_core']:CanPerformAction(src, 'businesses:buy_ammunation_weapon', 1500) then
        TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
            success = false, message = 'Veuillez patienter avant de renouveler votre achat.'
        })
        return
    end
    local player = getPlayerAtAmmunation(src)
    if not player then
        TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
            success = false, message = 'Achat refusé : vous êtes trop éloigné de l’armurerie.'
        })
        return
    end
    local cash = tonumber(player.cash) or 0
    if cash < definition.price then
        TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
            success = false, message = ('Fonds insuffisants. %s coûte %d $.'):format(definition.label, definition.price),
            cash = cash
        })
        return
    end

    local locks = { player.charId }
    if not exports['rp_core']:AcquireCharacterLock(locks) then
        TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
            success = false, message = 'Votre compte est en cours de sauvegarde. Réessayez dans un instant.',
            cash = cash
        })
        return
    end

    local weaponName = definition.weapon
    local metadata = {}
    for key, value in pairs(player.metadata or {}) do metadata[key] = value end
    metadata.weapons = {}
    for _, entry in ipairs(type(player.metadata) == 'table' and type(player.metadata.weapons) == 'table' and player.metadata.weapons or {}) do
        if type(entry) == 'table' then
            metadata.weapons[#metadata.weapons + 1] = { name = entry.name, ammo = tonumber(entry.ammo) or 0 }
        end
    end

    local existingWeapon
    for _, entry in ipairs(metadata.weapons) do
        if entry.name == weaponName then existingWeapon = entry; break end
    end
    if existingWeapon and definition.ammo <= 0 then
        exports['rp_core']:ReleaseCharacterLock(locks)
        TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
            success = false, message = 'Vous possédez déjà cette arme.', cash = cash
        })
        return
    end
    local deliveredAmmo = definition.ammo
    if existingWeapon then
        existingWeapon.ammo = math.min(9999, (tonumber(existingWeapon.ammo) or 0) + definition.ammo)
        deliveredAmmo = existingWeapon.ammo
    else
        metadata.weapons[#metadata.weapons + 1] = { name = weaponName, ammo = definition.ammo }
    end

    local ok, affected = pcall(MySQL.update.await, [[
        UPDATE characters
        SET cash = cash - ?, metadata = ?
        WHERE id = ? AND identifier = ? AND cash >= ?
    ]], { definition.price, json.encode(metadata), player.charId, player.identifier, definition.price })
    exports['rp_core']:ReleaseCharacterLock(locks)
    if not ok or tonumber(affected) ~= 1 then
        TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
            success = false, message = 'Le paiement n’a pas pu être enregistré. Aucun achat effectué.',
            cash = cash
        })
        print(('[rp_businesses] Ammu-Nation purchase failed src=%s item=%s: %s'):format(src, itemName, tostring(affected)))
        return
    end

    player.cash = cash - definition.price
    player.metadata = metadata
    TriggerClientEvent('rp_core:client:updateCash', src, player.cash)
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'ammunation',
        definition.price, 'Ammu-Nation', 'Achat ' .. definition.label)
    TriggerClientEvent('rp_businesses:client:weaponPurchased', src, weaponName, deliveredAmmo)
    TriggerClientEvent('rp_businesses:client:purchaseResult', src, {
        success = true, message = ('%s acheté pour %d $.'):format(definition.label, definition.price),
        cash = player.cash
    })
end

RegisterNetEvent('rp_businesses:server:buyAmmunationWeapon', function(itemName)
    purchaseAmmunationWeapon(source, itemName)
end)

-- Compatibilité avec les anciens clients qui achètent encore le pistolet.
RegisterNetEvent('rp_businesses:server:buyPistol', function()
    purchaseAmmunationWeapon(source, 'weapon_pistol')
end)


-- Catalogue des supérettes : prix et objets autorisés exclusivement côté serveur.
local STORE_PRODUCTS = {
    bread = 8, burger_bleeder = 18, pizza_pepperoni = 14,
    sandwich_poulet = 12, tacos_viande = 16, hotdog = 10,
    donut = 6, cookie_chocolat = 5, pomme = 4, salade_cesar = 15,
    water = 5, soda_ecola = 7, soda_sprunk = 7, energy_drink = 12,
    coffee = 8, the_glace = 9, jus_orange = 10, milkshake_vanille = 13
}
local STORE_LABELS = {
    bread='Pain de campagne', burger_bleeder='Burger Bleeder', pizza_pepperoni='Pizza pepperoni',
    sandwich_poulet='Sandwich poulet', tacos_viande='Tacos XL', hotdog='Hot-dog',
    donut='Donut', cookie_chocolat='Cookie chocolat', pomme='Pomme rouge',
    salade_cesar='Salade César', water='Eau minérale', soda_ecola='eCola',
    soda_sprunk='Sprunk', energy_drink='Junk Energy', coffee='Café',
    the_glace='Thé glacé', jus_orange='Jus d’orange', milkshake_vanille='Milkshake vanille'
}
local STORE_ICONS = {
    bread='🥖', burger_bleeder='🍔', pizza_pepperoni='🍕', sandwich_poulet='🥪',
    tacos_viande='🌮', hotdog='🌭', donut='🍩', cookie_chocolat='🍪',
    pomme='🍎', salade_cesar='🥗', water='💧', soda_ecola='🥤',
    soda_sprunk='🧃', energy_drink='⚡', coffee='☕', the_glace='🧋',
    jus_orange='🍊', milkshake_vanille='🥛'
}
local storePurchaseLocks = {}

local function getStoreLocations()
    local locations = {}
    for _, location in ipairs(cachedLocations) do
        if location.location_type == 'shop' and location.shop_style == 'food' then
            locations[#locations + 1] = location
        end
    end

    -- Merge all shared base coordinates even when SQL has only partially
    -- seeded the registry. Extra SQL-defined shop points remain supported.
    for _, category in ipairs(BusinessLocations or {}) do
        if category.id == 'food' then
            for index, point in ipairs(category.points or {}) do
                locations[#locations + 1] = {
                    location_type = 'shop', shop_style = 'food',
                    location_key = ('shop:food:%d'):format(index),
                    x = point[1], y = point[2], z = point[3]
                }
            end
        end
    end
    return locations
end

local function getPlayerAtStore(src, maxDistance)
    local player = exports['rp_core']:GetPlayerFromId(src)
    local ped = GetPlayerPed(src)
    if not player or ped == 0 or not DoesEntityExist(ped) then return nil end

    local coords = GetEntityCoords(ped)
    for _, location in ipairs(getStoreLocations()) do
        local point = vector3(
            tonumber(location.x) or 0.0,
            tonumber(location.y) or 0.0,
            tonumber(location.z) or 0.0
        )
        if #(coords - point) <= maxDistance then return player end
    end
    return nil
end

local function buildStoreCatalog()
    local products = {}
    for itemName, price in pairs(STORE_PRODUCTS) do
        products[#products + 1] = {
            item = itemName, label = STORE_LABELS[itemName] or itemName,
            price = price, image = STORE_ICONS[itemName] or '🛒'
        }
    end
    table.sort(products, function(a, b) return a.label < b.label end)
    return products
end

RegisterNetEvent('rp_businesses:server:requestStore', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'businesses:open_store', 1000) then return end
    local player = getPlayerAtStore(src, 1.5)
    if not player then
        TriggerClientEvent('rp_core:client:notify', src, 'Approchez-vous du vendeur de la supérette.', 'error')
        return
    end
    TriggerClientEvent('rp_businesses:client:openStore', src, {
        cash = tonumber(player.cash) or 0, storeName = 'SUPÉRETTE LOS SANTOS',
        products = buildStoreCatalog()
    })
end)

RegisterNetEvent('rp_businesses:server:buyStoreItem', function(itemName)
    local src = source
    if type(itemName) ~= 'string' or #itemName > 48 or not STORE_PRODUCTS[itemName] then return end
    if storePurchaseLocks[src] then return end

    if not exports['rp_core']:CanPerformAction(src, 'businesses:buy_store_item', 900) then
        TriggerClientEvent('rp_businesses:client:storePurchaseResult', src, {
            success = false, message = 'Patientez avant un nouvel achat.'
        })
        return
    end

    local player = getPlayerAtStore(src, 1.5)
    if not player then
        TriggerClientEvent('rp_businesses:client:storePurchaseResult', src, {
            success = false, message = 'Achat refusé : vous êtes trop loin de la boutique.',
            cash = 0
        })
        return
    end

    local price = STORE_PRODUCTS[itemName]
    local cash = tonumber(player.cash) or 0
    if cash < price then
        TriggerClientEvent('rp_businesses:client:storePurchaseResult', src, {
            success = false, message = 'Vous n’avez pas assez d’argent en espèces.',
            cash = cash
        })
        return
    end

    -- Lock before charging to prevent two simultaneous requests from spending
    -- the same balance before the inventory write finishes.
    storePurchaseLocks[src] = true
    local debitOk, debited = pcall(player.removeCash, price)
    if not debitOk or debited ~= true then
        storePurchaseLocks[src] = nil
        TriggerClientEvent('rp_businesses:client:storePurchaseResult', src, {
            success = false, message = 'Le paiement a échoué. Aucun achat effectué.',
            cash = tonumber(player.cash) or cash
        })
        return
    end

    local inventoryOk, added = pcall(function()
        return exports['rp_inventory']:AddItem(src, itemName, 1)
    end)

    if not inventoryOk or added ~= true then
        local refundOk, refunded = pcall(player.addCash, price)
        local refundSucceeded = refundOk and refunded == true
        if not refundSucceeded then
            print(('[rp_businesses] ÉCHEC remboursement achat boutique joueur=%s item=%s prix=%s'):format(src, itemName, price))
        end
        storePurchaseLocks[src] = nil
        TriggerClientEvent('rp_businesses:client:storePurchaseResult', src, {
            success = false,
            message = refundSucceeded
                and 'Inventaire plein ou sauvegarde impossible : paiement remboursé.'
                or 'Échec de livraison et de remboursement. Contactez un administrateur.',
            cash = tonumber(player.cash) or 0
        })
        return
    end

    storePurchaseLocks[src] = nil
    TriggerClientEvent('rp_businesses:client:storePurchaseResult', src, {
        success = true,
        message = (STORE_LABELS[itemName] or itemName) .. ' acheté.',
        cash = tonumber(player.cash) or math.max(0, cash - price)
    })
end)

AddEventHandler('playerDropped', function()
    storePurchaseLocks[source] = nil
end)
