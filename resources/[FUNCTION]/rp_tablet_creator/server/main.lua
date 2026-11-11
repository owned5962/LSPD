local CanUseTablet

local function isCreator(src)
    if IsPlayerAceAllowed(src, 'rp_creator') then return true end
    local player = exports['rp_core']:GetPlayerFromId(src)
    return player ~= nil and (player.group == 'superadmin' or player.group == 'fondateur')
end

local function creatorAccessAllowed(src)
    return isCreator(src) and type(CanUseTablet) == 'function' and CanUseTablet(src, 'creator') == true
end

local function reply(src, message, success)
    TriggerClientEvent('rp_tablet_creator:client:result', src, message, success == true)
end

RegisterNetEvent('rp_tablet_creator:server:requestOpen', function()
    local src = source
    if not creatorAccessAllowed(src) then
        reply(src, 'Accès réservé aux créateurs et fondateurs.', false)
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local role = player and player.group or 'Créateur'
    TriggerClientEvent('rp_tablet_creator:client:open', src, role)
end)

RegisterNetEvent('rp_tablet_creator:server:setWorld', function(weather, rawHours, rawMinutes)
    local src = source
    if not creatorAccessAllowed(src) then return end

    local allowedWeather = {
        EXTRASUNNY = true, CLEAR = true, CLOUDS = true, SMOG = true, FOGGY = true,
        OVERCAST = true, RAIN = true, THUNDER = true, CLEARING = true, NEUTRAL = true,
        SNOW = true, BLIZZARD = true, SNOWLIGHT = true, XMAS = true, HALLOWEEN = true
    }
    local hasWeather = type(weather) == 'string' and weather ~= ''
    if hasWeather and not allowedWeather[weather] then
        reply(src, 'Type de météo non autorisé.', false)
        return
    end

    local hasTime = rawHours ~= nil or rawMinutes ~= nil
    local hours, minutes
    if hasTime then
        hours, minutes = tonumber(rawHours), tonumber(rawMinutes)
        if not hours or not minutes or hours % 1 ~= 0 or minutes % 1 ~= 0
            or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then
            reply(src, 'Heure invalide. Utilisez un format de 00:00 à 23:59.', false)
            return
        end
    end
    if not hasWeather and not hasTime then
        reply(src, 'Aucun changement demandé.', false)
        return
    end
    if hasWeather then TriggerClientEvent('rp_tablet_admin:client:syncWeather', -1, weather) end
    if hasTime then TriggerClientEvent('rp_tablet_admin:client:syncTime', -1, hours, minutes) end
    reply(src, 'Météo et heure du serveur mises à jour.', true)
end)

RegisterNetEvent('rp_tablet_creator:server:broadcast', function(rawMessage)
    local src = source
    if not creatorAccessAllowed(src) then return end
    if type(rawMessage) ~= 'string' then reply(src, 'Annonce invalide.', false); return end
    local message = rawMessage:gsub('[%c]', ' '):sub(1, 300)
    if message == '' then reply(src, 'Le message ne peut pas être vide.', false); return end
    TriggerClientEvent('chat:addMessage', -1, { color = { 80, 160, 255 }, args = { '[ANNONCE CRÉATEUR]', message } })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'info')
    reply(src, 'Annonce diffusée à tous les joueurs.', true)
end)


-- Persistent creator mapping and per-job blip configuration.
-- Curated GTA V / FiveM object catalogue. Model names are searchable in the creator tablet.
-- Based on public game-object references; avoid _lod, _proxy and _dummy helper models.
local PROP_CATALOG = {
    -- Roadworks, barriers and signage
    prop_barrier_work05 = true, prop_barrier_work06a = true, prop_roadcone02a = true,
    prop_mp_cone_02 = true, prop_worklight_03b = true, prop_mp_arrow_barrier_01 = true,
    prop_sign_road_01a = true, prop_bollard_02a = true, prop_roadpole_01a = true,
    prop_traffic_03a = true, prop_barrier_wat_03b = true, prop_roadcone01a = true,
    prop_barrier_work01a = true, prop_barrier_work02a = true, prop_barrier_work04a = true,
    prop_barrier_work06b = true, prop_consign_02a = true,
    -- City, construction and storage
    prop_container_05a = true, prop_dumpster_01a = true, prop_crate_11e = true,
    prop_toolchest_05 = true, prop_boxpile_07d = true, prop_worklight_04a = true,
    prop_parkingpay = true, prop_fnclink_03gate5 = true, prop_gate_airport_01 = true,
    prop_table_03b = true, prop_chair_01a = true, prop_bench_01a = true,
    prop_worklight_04b = true, prop_generator_03b = true, prop_generator_02a = true,
    prop_pallet_02a = true, prop_pallet_03a = true, prop_skid_box_06 = true,
    -- Roleplay, security and banking
    prop_atm_01 = true, prop_atm_02 = true, prop_atm_03 = true, prop_fleeca_atm = true,
    prop_ld_int_safe_01 = true, prop_money_bag_01 = true, prop_cash_pile_01 = true,
    prop_cash_case_01 = true, prop_security_case_01 = true, prop_cs_heist_bag_02 = true,
    prop_michael_backpack = true, prop_cs_cuffs_01 = true, prop_laptop_01a = true,
    prop_notepad_01 = true, prop_ld_ammo_pack_01 = true,
    -- Interior, leisure and food props
    prop_tv_flat_01 = true, prop_cs_burger_01 = true, prop_ld_flow_bottle = true,
    prop_ecola_can = true, prop_cs_beer_bot_01 = true, prop_wine_bot_01 = true,
    prop_cs_whiskey_bottle = true, prop_tequila_bottle = true, prop_shot_glass = true,
    prop_cs_ciggy_01 = true, prop_vend_soda_01 = true, prop_vend_snak_01 = true,
    prop_bbq_1 = true, prop_beach_fire = true, prop_weed_02 = true,
    -- Office and service furniture
    prop_off_chair_04 = true, prop_office_desk_01 = true, prop_monitor_01c = true,
    prop_keyboard_01a = true, prop_printer_01 = true, prop_cctv_cam_01a = true,
    prop_phone_ing = true, prop_fax_01 = true
}
local spawnedMapping = {}

local function ensureCreatorTables()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_creator_mapping (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            model VARCHAR(64) NOT NULL,
            x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            created_by VARCHAR(80) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_creator_job_blips (
            job VARCHAR(64) NOT NULL PRIMARY KEY,
            label VARCHAR(80) NOT NULL,
            x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
            sprite INT NOT NULL DEFAULT 1,
            color INT NOT NULL DEFAULT 0,
            scale FLOAT NOT NULL DEFAULT 0.7,
            enabled TINYINT(1) NOT NULL DEFAULT 1,
            updated_by VARCHAR(80) NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_creator_settings (
            setting_key VARCHAR(64) NOT NULL PRIMARY KEY,
            setting_value VARCHAR(255) NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_creator_module_state (
            resource_name VARCHAR(64) NOT NULL PRIMARY KEY,
            enabled TINYINT(1) NOT NULL DEFAULT 1,
            updated_by VARCHAR(80) NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_creator_player_access (
            identifier VARCHAR(80) NOT NULL PRIMARY KEY,
            admin_enabled TINYINT(1) NOT NULL DEFAULT 1,
            anticheat_enabled TINYINT(1) NOT NULL DEFAULT 1,
            creator_enabled TINYINT(1) NOT NULL DEFAULT 1,
            updated_by VARCHAR(80) NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end)
    if not ok then print('[rp_tablet_creator] Table initialization failed: ' .. tostring(err)) end
    return ok
end

local function spawnSavedMapping()
    local rows = MySQL.query.await('SELECT id, model, x, y, z, heading FROM rp_creator_mapping ORDER BY id ASC') or {}
    for index, row in ipairs(rows) do
        local model = tostring(row.model or '')
        if PROP_CATALOG[model] then
            local entity = CreateObjectNoOffset(GetHashKey(model), tonumber(row.x), tonumber(row.y), tonumber(row.z), true, true, false)
            if entity and entity ~= 0 then
                SetEntityHeading(entity, tonumber(row.heading) or 0.0)
                FreezeEntityPosition(entity, true)
                spawnedMapping[tonumber(row.id)] = entity
            end
        end
        if index % 15 == 0 then Wait(0) end
    end
end

CreateThread(function()
    Wait(1500)
    if not ensureCreatorTables() then return end
    ApplyStoredCreatorSettings()
    Wait(500)
    local ok, err = pcall(spawnSavedMapping)
    if not ok then print('[rp_tablet_creator] Mapping restore failed: ' .. tostring(err)) end
    local rowsOk, rows = pcall(MySQL.query.await, 'SELECT job, label, x, y, z, sprite, color, scale, enabled FROM rp_creator_job_blips')
    if rowsOk then TriggerClientEvent('rp_tablet_creator:client:syncJobBlips', -1, rows or {}) end
end)

RegisterNetEvent('rp_tablet_creator:server:requestTools', function()
    local src = source
    if not creatorAccessAllowed(src) then return end
    local jobs = exports['rp_jobs']:GetAllJobs() or {}
    local jobList = {}
    for key, job in pairs(jobs) do local name = job.name or key; jobList[#jobList + 1] = { name = name, label = job.label or name } end
    table.sort(jobList, function(a, b) return a.label < b.label end)
    local blips = MySQL.query.await('SELECT job, label, x, y, z, sprite, color, scale, enabled FROM rp_creator_job_blips') or {}
    local mapping = MySQL.query.await('SELECT id, model, x, y, z, heading FROM rp_creator_mapping ORDER BY id DESC LIMIT 100') or {}
    TriggerClientEvent('rp_tablet_creator:client:toolsData', src, jobList, blips, mapping, PROP_CATALOG)
end)

RegisterNetEvent('rp_tablet_creator:server:spawnProp', function(rawModel)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:spawn_prop', 700) then return end
    if type(rawModel) ~= 'string' or not PROP_CATALOG[rawModel] then
        reply(src, 'Objet non autorisé. Choisissez un modèle du catalogue.', false); return
    end
    local countOk, count = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM rp_creator_mapping')
    if not countOk or tonumber(count) >= 300 then
        reply(src, 'Limite de 300 objets de mapping atteinte ou base indisponible.', false)
        return
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then reply(src, 'Position du créateur introuvable.', false); return end
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.5, 0.0)
    local heading = GetEntityHeading(ped)
    local object = CreateObjectNoOffset(GetHashKey(rawModel), coords.x, coords.y, coords.z, true, true, false)
    if not object or object == 0 then reply(src, 'Le serveur n’a pas pu créer cet objet.', false); return end
    SetEntityHeading(object, heading)
    FreezeEntityPosition(object, true)
    local creator = GetPlayerName(src) or ('ID ' .. src)
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO rp_creator_mapping (model, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?)',
        { rawModel, coords.x, coords.y, coords.z, heading, creator })
    if not ok or not id then DeleteEntity(object); reply(src, 'Objet créé mais sauvegarde impossible : création annulée.', false); return end
    spawnedMapping[tonumber(id)] = object
    reply(src, ('Objet %s placé et sauvegardé (ID %s).'):format(rawModel, id), true)
    TriggerClientEvent('rp_tablet_creator:client:mappingAdded', src, { id = id, model = rawModel, x = coords.x, y = coords.y, z = coords.z, heading = heading })
end)

RegisterNetEvent('rp_tablet_creator:server:deleteProp', function(rawId)
    local src = source
    if not creatorAccessAllowed(src) then return end
    local id = tonumber(rawId)
    if not id or id % 1 ~= 0 or id < 1 then reply(src, 'ID de mapping invalide.', false); return end
    local ok, affected = pcall(MySQL.update.await, 'DELETE FROM rp_creator_mapping WHERE id = ?', { id })
    if not ok or tonumber(affected) ~= 1 then reply(src, 'Objet introuvable ou suppression impossible.', false); return end
    local entity = spawnedMapping[id]
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    spawnedMapping[id] = nil
    reply(src, 'Objet de mapping supprimé.', true)
    TriggerClientEvent('rp_tablet_creator:client:mappingRemoved', src, id)
end)

RegisterNetEvent('rp_tablet_creator:server:saveJobBlip', function(data)
    local src = source
    if not creatorAccessAllowed(src) then return end
    if type(data) ~= 'table' then reply(src, 'Configuration de blip invalide.', false); return end
    local jobName = type(data.job) == 'string' and data.job:sub(1, 64) or ''
    local job = exports['rp_jobs']:GetJob(jobName)
    if not job then reply(src, 'Métier inconnu.', false); return end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local sprite, color, scale = tonumber(data.sprite), tonumber(data.color), tonumber(data.scale)
    local label = type(data.label) == 'string' and data.label:gsub('[%c]', ' '):sub(1, 80) or ''
    if not x or not y or not z or x < -5000 or x > 5000 or y < -5000 or y > 5000 or z < -100 or z > 2000
        or not sprite or sprite % 1 ~= 0 or sprite < 1 or sprite > 1000
        or not color or color % 1 ~= 0 or color < 0 or color > 85
        or not scale or scale < 0.2 or scale > 2.0 or label == '' or type(data.enabled) ~= 'boolean' then
        reply(src, 'Coordonnées, nom ou style de blip invalide.', false); return
    end
    local creator = GetPlayerName(src) or ('ID ' .. src)
    local ok, err = pcall(MySQL.insert.await, [[
        INSERT INTO rp_creator_job_blips (job, label, x, y, z, sprite, color, scale, enabled, updated_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label=VALUES(label), x=VALUES(x), y=VALUES(y), z=VALUES(z),
            sprite=VALUES(sprite), color=VALUES(color), scale=VALUES(scale), enabled=VALUES(enabled), updated_by=VALUES(updated_by)
    ]], { jobName, label, x, y, z, sprite, color, scale, data.enabled and 1 or 0, creator })
    if not ok then reply(src, 'Erreur SQL : blip non sauvegardé.', false); print('[rp_tablet_creator] Blip save failed: ' .. tostring(err)); return end
    local rows = MySQL.query.await('SELECT job, label, x, y, z, sprite, color, scale, enabled FROM rp_creator_job_blips') or {}
    TriggerClientEvent('rp_tablet_creator:client:syncJobBlips', -1, rows)
    reply(src, 'Blip du métier sauvegardé et synchronisé.', true)
end)


RegisterNetEvent('rp_tablet_creator:server:requestJobBlips', function()
    local src = source
    local ok, rows = pcall(MySQL.query.await, 'SELECT job, label, x, y, z, sprite, color, scale, enabled FROM rp_creator_job_blips')
    if ok then TriggerClientEvent('rp_tablet_creator:client:jobBlips', src, rows or {}) end
end)


-- Server and connected-player controls are exposed only to the founder console.
local OPTIONAL_MODULES = {
    rp_world = 'Monde & densité',
    rp_clothing = 'Vêtements',
    rp_interactions = 'Interactions',
    rp_fuel = 'Carburant',
    rp_vehicle_loot = 'Butin des véhicules'
}
local TABLET_COLUMNS = { admin = 'admin_enabled', anticheat = 'anticheat_enabled', creator = 'creator_enabled' }
local ROLE_RANK = { user = 0, moderator = 1, admin = 2, fondateur = 3, superadmin = 4 }

local function CreatorLicense(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier and identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return nil
end

local function IsManagedCreatorModule(name)
    if type(name) ~= 'string' then return false end
    if OPTIONAL_MODULES[name] then return true end
    return name:sub(1, 4) == 'job_' and GetResourceState(name) ~= 'missing'
end

CanUseTablet = function(src, tablet)
    local column = TABLET_COLUMNS[tablet]
    local identifier = CreatorLicense(tonumber(src))
    if not column or not identifier then return false end
    local ok, row = pcall(MySQL.single.await,
        ('SELECT %s FROM rp_creator_player_access WHERE identifier = ?'):format(column),
        { identifier })
    if not ok then
        print('[rp_tablet_creator] Tablet access lookup failed: ' .. tostring(row))
        return false
    end
    return not row or tonumber(row[column]) == 1
end
exports('CanUseTablet', function(src, tablet)
    if type(CanUseTablet) ~= 'function' then return false end
    return CanUseTablet(src, tablet)
end)

local function GetCreatorModules()
    local names = {}
    for name, label in pairs(OPTIONAL_MODULES) do names[name] = label end
    for index = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(index)
        if name and name:sub(1, 4) == 'job_' then
            names[name] = 'Métier · ' .. name:sub(5):gsub('_', ' ')
        end
    end
    local modules = {}
    for name, label in pairs(names) do
        local state = GetResourceState(name)
        modules[#modules + 1] = { name = name, label = label, state = state, enabled = state == 'started' }
    end
    table.sort(modules, function(a, b) return a.label < b.label end)
    return modules
end

local function GetCreatorPlayers()
    local players, identifiers = {}, {}
    for _, rawId in ipairs(GetPlayers()) do
        local id = tonumber(rawId)
        local player = id and exports['rp_core']:GetPlayerFromId(id)
        if id and player and player.identifier then
            identifiers[#identifiers + 1] = player.identifier
            local y, m, d = tostring(player.dateofbirth or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)')
            local age = 25
            if y then
                local today = os.date('*t')
                age = today.year - tonumber(y)
                if today.month < tonumber(m) or (today.month == tonumber(m) and today.day < tonumber(d)) then age = age - 1 end
            end
            players[#players + 1] = {
                id = id, name = (tostring(player.firstname or '') .. ' ' .. tostring(player.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
                firstname = player.firstname or '', lastname = player.lastname or '', age = age,
                gender = player.sex == 'f' and 'f' or 'm', cash = tonumber(player.cash) or 0,
                bank = tonumber(player.bank) or 0, job = player.job or 'unemployed',
                grade = tonumber(player.jobGrade) or 0, group = player.group or 'user',
                identifier = player.identifier
            }
        end
    end

    local accessMap = {}
    if #identifiers > 0 then
        local placeholders = {}
        for index = 1, #identifiers do placeholders[index] = '?' end
        local query = 'SELECT identifier, admin_enabled, anticheat_enabled, creator_enabled FROM rp_creator_player_access WHERE identifier IN (' .. table.concat(placeholders, ',') .. ')'
        local ok, rows = pcall(MySQL.query.await, query, identifiers)
        if ok then
            for _, row in ipairs(rows or {}) do accessMap[row.identifier] = row end
        else
            print('[rp_tablet_creator] Tablet access list failed: ' .. tostring(rows))
        end
    end
    for _, player in ipairs(players) do
        local access = accessMap[player.identifier]
        player.tablets = {
            admin = not access or tonumber(access.admin_enabled) == 1,
            anticheat = not access or tonumber(access.anticheat_enabled) == 1,
            creator = not access or tonumber(access.creator_enabled) == 1
        }
        player.identifier = nil
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    return players
end

local function GetCreatorJobs()
    local jobs = exports['rp_jobs']:GetAllJobs() or {}
    local list = {}
    for key, job in pairs(jobs) do
        local name = job.name or key
        local grades = {}
        for gradeId, grade in pairs(job.grades or {}) do
            grades[#grades + 1] = { grade = tonumber(gradeId) or 0, label = grade.label or ('Grade ' .. tostring(gradeId)) }
        end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        list[#list + 1] = { name = name, label = job.label or name, grades = grades }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function GetCreatorSettings()
    local settings = { name = GetConvar('sv_hostname', 'Los Santos Stories'), slots = GetConvarInt('sv_maxclients', 64) }
    local ok, rows = pcall(MySQL.query.await, 'SELECT setting_key, setting_value FROM rp_creator_settings')
    if ok then
        for _, row in ipairs(rows or {}) do
            if row.setting_key == 'server_name' then settings.name = row.setting_value end
            if row.setting_key == 'max_slots' then settings.slots = tonumber(row.setting_value) or settings.slots end
        end
    end
    return settings
end

function ApplyStoredCreatorSettings()
    local ok, rows = pcall(MySQL.query.await, 'SELECT setting_key, setting_value FROM rp_creator_settings')
    if ok then
        for _, row in ipairs(rows or {}) do
            if row.setting_key == 'server_name' and type(row.setting_value) == 'string' then
                SetConvar('sv_hostname', row.setting_value)
            elseif row.setting_key == 'max_slots' then
                local slots = tonumber(row.setting_value)
                if slots and slots >= 1 and slots <= 1024 then SetConvar('sv_maxclients', tostring(math.floor(slots))) end
            end
        end
    end
    local stateOk, states = pcall(MySQL.query.await, 'SELECT resource_name, enabled FROM rp_creator_module_state')
    if not stateOk then return end
    local processed = 0
    for _, row in ipairs(states or {}) do
        local name = tostring(row.resource_name or '')
        if IsManagedCreatorModule(name) then
            local wanted = tonumber(row.enabled) == 1
            local state = GetResourceState(name)
            if wanted and state ~= 'started' then StartResource(name)
            elseif not wanted and state == 'started' then StopResource(name) end
            processed = processed + 1
            if processed % 5 == 0 then Wait(0) end
        end
    end
end

local function LogCreatorAction(src, action, targetId, details)
    local actor = exports['rp_core']:GetPlayerFromId(src)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId) or nil
    print(('[rp_tablet_creator] %s (%s) -> %s: %s %s'):format(
        actor and (actor.firstname .. ' ' .. actor.lastname) or (GetPlayerName(src) or tostring(src)),
        tostring(src),
        target and (target.firstname .. ' ' .. target.lastname) or (targetId and tostring(targetId) or 'serveur'),
        tostring(action), tostring(details or '')
    ))
end

RegisterNetEvent('rp_tablet_creator:server:requestAdminTools', function()
    local src = source
    if not creatorAccessAllowed(src) or not CanUseTablet(src, 'creator') then return end
    local ok, data = pcall(function()
        return {
            players = GetCreatorPlayers(),
            items = exports['rp_inventory']:GetItemCatalog() or {},
            settings = GetCreatorSettings(),
            modules = GetCreatorModules(),
            jobs = GetCreatorJobs()
        }
    end)
    if not ok then
        print('[rp_tablet_creator] Admin tools data failed: ' .. tostring(data))
        reply(src, 'Impossible de charger les données de gestion.', false)
        return
    end
    TriggerClientEvent('rp_tablet_creator:client:adminToolsData', src, data)
end)

RegisterNetEvent('rp_tablet_creator:server:setServerSettings', function(data)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:server_settings', 1000) or type(data) ~= 'table' then return end
    local name = type(data.name) == 'string' and data.name:gsub('[%c]', ' '):gsub('^%s*(.-)%s*$', '%1'):sub(1, 64) or ''
    local slots = tonumber(data.slots)
    if #name < 3 or not slots or slots % 1 ~= 0 or slots < 1 or slots > 1024 then
        reply(src, 'Nom du serveur ou nombre de slots invalide.', false)
        return
    end
    local ok, result = pcall(MySQL.transaction.await, {
        { query = 'INSERT INTO rp_creator_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)', values = { 'server_name', name } },
        { query = 'INSERT INTO rp_creator_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)', values = { 'max_slots', tostring(slots) } }
    })
    if not ok or result ~= true then
        print('[rp_tablet_creator] Server settings save failed: ' .. tostring(result))
        reply(src, 'Impossible de sauvegarder la configuration serveur.', false)
        return
    end
    SetConvar('sv_hostname', name)
    SetConvar('sv_maxclients', tostring(slots))
    reply(src, 'Nom du serveur appliqué. La capacité maximale nécessite un redémarrage du serveur.', true)
    LogCreatorAction(src, 'server_settings', nil, ('name=%s slots=%d'):format(name, slots))
end)

RegisterNetEvent('rp_tablet_creator:server:setModuleState', function(resourceName, enabled)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:module_state', 1500) then return end
    if type(enabled) ~= 'boolean' or not IsManagedCreatorModule(resourceName) then
        reply(src, 'Module inconnu ou protégé.', false)
        return
    end
    local state = GetResourceState(resourceName)
    if (enabled and state == 'started') or (not enabled and state ~= 'started') then
        reply(src, 'Ce module est déjà dans cet état.', true)
        return
    end
    local ok, err = pcall(function()
        if enabled then StartResource(resourceName) else StopResource(resourceName) end
    end)
    if not ok then reply(src, 'Action impossible sur le module : ' .. tostring(err), false); return end
    Wait(250)
    if (GetResourceState(resourceName) == 'started') ~= enabled then
        reply(src, 'Le module n’a pas changé d’état. Vérifiez ses dépendances dans la console.', false)
        return
    end
    local saved, saveErr = pcall(MySQL.insert.await,
        'INSERT INTO rp_creator_module_state (resource_name, enabled, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE enabled=VALUES(enabled), updated_by=VALUES(updated_by)',
        { resourceName, enabled and 1 or 0, GetPlayerName(src) or ('ID ' .. src) })
    if not saved then
        print('[rp_tablet_creator] Module state persistence failed: ' .. tostring(saveErr))
        reply(src, 'Module modifié, mais son état ne sera pas restauré au prochain redémarrage.', false)
        return
    end
    reply(src, (enabled and 'Module démarré : ' or 'Module arrêté : ') .. resourceName, true)
    TriggerClientEvent('rp_tablet_creator:client:refreshAdminTools', src)
    LogCreatorAction(src, 'module', nil, resourceName .. '=' .. tostring(enabled))
end)

RegisterNetEvent('rp_tablet_creator:server:updatePlayerIdentity', function(data)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:player_identity', 1000) or type(data) ~= 'table' then return end
    local targetId = tonumber(data.playerId)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)
    if not target or not GetPlayerName(targetId) then reply(src, 'Joueur introuvable ou personnage non chargé.', false); return end
    local firstname = type(data.firstname) == 'string' and data.firstname:gsub('^%s*(.-)%s*$', '%1') or ''
    local lastname = type(data.lastname) == 'string' and data.lastname:gsub('^%s*(.-)%s*$', '%1') or ''
    local age = tonumber(data.age)
    if #firstname < 2 or #firstname > 32 or #lastname < 2 or #lastname > 32
        or firstname:find('[%c<>]') or lastname:find('[%c<>]')
        or not age or age % 1 ~= 0 or age < 18 or age > 90 then
        reply(src, 'Prénom, nom ou âge invalide (18 à 90 ans).', false)
        return
    end
    local newGroup = tostring(data.group or target.group or 'user')
    if not ROLE_RANK[newGroup] or newGroup == 'superadmin' then reply(src, 'Rôle non autorisé.', false); return end
    local actor = exports['rp_core']:GetPlayerFromId(src)
    local actorGroup = actor and actor.group or 'user'
    if newGroup ~= target.group then
        if actorGroup ~= 'fondateur' and actorGroup ~= 'superadmin' then reply(src, 'Seul un fondateur peut modifier les rôles.', false); return end
        if (ROLE_RANK[newGroup] or 0) >= (ROLE_RANK[actorGroup] or 0) then reply(src, 'Vous ne pouvez pas attribuer un rôle égal ou supérieur au vôtre.', false); return end
    end
    local gender = target.sex == 'f' and 'f' or 'm'
    local skin = type(target.skin) == 'table' and target.skin or {}
    if data.skinPreset == 'male' then gender, skin = 'm', {}
    elseif data.skinPreset == 'female' then gender, skin = 'f', {}
    elseif data.skinPreset ~= 'keep' then reply(src, 'Choix de skin invalide.', false); return end
    local today = os.date('*t')
    local dateofbirth = ('%04d-%02d-%02d'):format(today.year - age, today.month, math.min(today.day, 28))
    local queries = {{
        query = 'UPDATE characters SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, skin = ? WHERE id = ? AND identifier = ?',
        values = { firstname, lastname, dateofbirth, gender, json.encode(skin), target.charId, target.identifier }
    }}
    if newGroup ~= target.group then
        queries[#queries + 1] = { query = "UPDATE users SET `group` = ? WHERE identifier = ?", values = { newGroup, target.identifier } }
    end
    local ok, result = pcall(MySQL.transaction.await, queries)
    if not ok or result ~= true then reply(src, 'Erreur SQL : identité non sauvegardée.', false); return end
    target.firstname, target.lastname, target.dateofbirth = firstname, lastname, dateofbirth
    target.sex, target.skin, target.group = gender, skin, newGroup
    pcall(SetPlayerName, targetId, firstname .. ' ' .. lastname)
    if target.syncClient then target.syncClient() end
    TriggerClientEvent('rp_characters:client:adminApplySkin', targetId, gender, skin)
    TriggerClientEvent('rp_core:client:notify', targetId, 'Votre identité a été mise à jour par l’équipe du serveur.', 'info')
    reply(src, 'Identité, âge, skin et rôle mis à jour.', true)
    LogCreatorAction(src, 'identity', targetId, firstname .. ' ' .. lastname .. ' / ' .. age .. ' ans / ' .. newGroup)
end)

RegisterNetEvent('rp_tablet_creator:server:updatePlayerBalances', function(data)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:player_balances', 1000) or type(data) ~= 'table' then return end
    local targetId = tonumber(data.playerId)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)
    local cash, bank = tonumber(data.cash), tonumber(data.bank)
    if not target or not cash or not bank or cash % 1 ~= 0 or bank % 1 ~= 0
        or cash < 0 or bank < 0 or cash > 100000000 or bank > 100000000 then
        reply(src, 'Joueur ou montants invalides (maximum 100 000 000).', false)
        return
    end
    local oldCash, oldBank = target.cash, target.bank
    target.cash, target.bank = cash, bank
    if not target.save() then
        target.cash, target.bank = oldCash, oldBank
        reply(src, 'Sauvegarde financière impossible.', false)
        return
    end
    TriggerClientEvent('rp_core:client:updateCash', targetId, cash)
    TriggerClientEvent('rp_core:client:updateBank', targetId, bank)
    reply(src, 'Argent liquide et compte bancaire mis à jour.', true)
    LogCreatorAction(src, 'balances', targetId, ('cash=%d bank=%d'):format(cash, bank))
end)

RegisterNetEvent('rp_tablet_creator:server:updatePlayerJob', function(data)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:player_job', 800) or type(data) ~= 'table' then return end
    local targetId = tonumber(data.playerId)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)
    local grade = tonumber(data.grade)
    if not target or not grade or grade % 1 ~= 0 then reply(src, 'Joueur ou grade invalide.', false); return end
    if target.setJob(tostring(data.jobName or ''), grade) then
        reply(src, 'Métier du joueur mis à jour.', true)
        LogCreatorAction(src, 'job', targetId, tostring(data.jobName) .. ' grade ' .. grade)
    else
        reply(src, 'Métier ou grade invalide.', false)
    end
end)

RegisterNetEvent('rp_tablet_creator:server:updatePlayerInventory', function(data)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:player_inventory', 1000) or type(data) ~= 'table' then return end
    local targetId = tonumber(data.playerId)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)
    if not target then reply(src, 'Joueur introuvable.', false); return end
    local ok, result = pcall(function()
        return exports['rp_inventory']:AdminSetItem(targetId, tostring(data.itemName or ''), data.operation, data.count)
    end)
    if not ok or result ~= true then reply(src, 'Modification impossible : objet inconnu, quantité insuffisante ou poids maximal atteint.', false); return end
    reply(src, 'Inventaire du joueur mis à jour.', true)
    LogCreatorAction(src, 'inventory', targetId, tostring(data.operation) .. ' ' .. tostring(data.itemName) .. ' x' .. tostring(data.count))
end)

RegisterNetEvent('rp_tablet_creator:server:updatePlayerAccess', function(data)
    local src = source
    if not creatorAccessAllowed(src) or not exports['rp_core']:CanPerformAction(src, 'creator:player_access', 1000) or type(data) ~= 'table' then return end
    local targetId = tonumber(data.playerId)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)
    if not target or type(data.admin) ~= 'boolean' or type(data.anticheat) ~= 'boolean' or type(data.creator) ~= 'boolean' then
        reply(src, 'Joueur ou autorisations invalides.', false)
        return
    end
    if targetId == src and data.creator == false then
        reply(src, 'Vous ne pouvez pas désactiver votre propre tablette créateur depuis cette interface.', false)
        return
    end
    local ok, err = pcall(MySQL.insert.await, [[
        INSERT INTO rp_creator_player_access (identifier, admin_enabled, anticheat_enabled, creator_enabled, updated_by)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE admin_enabled=VALUES(admin_enabled), anticheat_enabled=VALUES(anticheat_enabled),
            creator_enabled=VALUES(creator_enabled), updated_by=VALUES(updated_by)
    ]], { target.identifier, data.admin and 1 or 0, data.anticheat and 1 or 0, data.creator and 1 or 0, GetPlayerName(src) or ('ID ' .. src) })
    if not ok then reply(src, 'Impossible de sauvegarder les accès aux tablettes.', false); return end
    reply(src, 'Autorisations des tablettes mises à jour.', true)
    LogCreatorAction(src, 'tablet_access', targetId, 'admin=' .. tostring(data.admin) .. ' anticheat=' .. tostring(data.anticheat) .. ' creator=' .. tostring(data.creator))
end)


-- Re-apply persisted module states after server.cfg has finished starting its resources.
CreateThread(function()
    Wait(15000)
    ApplyStoredCreatorSettings()
end)
