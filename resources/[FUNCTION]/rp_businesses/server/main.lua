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
            INSERT INTO %s
                (location_key, location_type, name, shop_style, icon, x, y, z,
                 blip_enabled, blip_sprite, blip_display, blip_scale, blip_colour, short_range)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                name = VALUES(name), shop_style = VALUES(shop_style), icon = VALUES(icon),
                x = VALUES(x), y = VALUES(y), z = VALUES(z),
                blip_enabled = VALUES(blip_enabled), blip_sprite = VALUES(blip_sprite),
                blip_display = VALUES(blip_display), blip_scale = VALUES(blip_scale),
                blip_colour = VALUES(blip_colour), short_range = VALUES(short_range), enabled = 1
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
