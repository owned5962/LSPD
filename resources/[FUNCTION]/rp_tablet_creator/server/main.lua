local function isCreator(src)
    if IsPlayerAceAllowed(src, 'rp_creator') then return true end
    local player = exports['rp_core']:GetPlayerFromId(src)
    return player ~= nil and (player.group == 'superadmin' or player.group == 'fondateur')
end

local function reply(src, message, success)
    TriggerClientEvent('rp_tablet_creator:client:result', src, message, success == true)
end

RegisterNetEvent('rp_tablet_creator:server:requestOpen', function()
    local src = source
    if not isCreator(src) then
        reply(src, 'Accès réservé aux créateurs et fondateurs.', false)
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local role = player and player.group or 'Créateur'
    TriggerClientEvent('rp_tablet_creator:client:open', src, role)
end)

RegisterNetEvent('rp_tablet_creator:server:setWorld', function(weather, rawHours, rawMinutes)
    local src = source
    if not isCreator(src) then return end

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
    if not isCreator(src) then return end
    if type(rawMessage) ~= 'string' then reply(src, 'Annonce invalide.', false); return end
    local message = rawMessage:gsub('[%c]', ' '):sub(1, 300)
    if message == '' then reply(src, 'Le message ne peut pas être vide.', false); return end
    TriggerClientEvent('chat:addMessage', -1, { color = { 80, 160, 255 }, args = { '[ANNONCE CRÉATEUR]', message } })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'info')
    reply(src, 'Annonce diffusée à tous les joueurs.', true)
end)


-- Persistent creator mapping and per-job blip configuration.
local PROP_CATALOG = {
    prop_barrier_work05 = true, prop_barrier_work06a = true, prop_roadcone02a = true,
    prop_mp_cone_02 = true, prop_worklight_03b = true, prop_mp_arrow_barrier_01 = true,
    prop_sign_road_01a = true, prop_container_05a = true, prop_dumpster_01a = true,
    prop_bollard_02a = true, prop_gate_airport_01 = true, prop_fnclink_03gate5 = true,
    prop_crate_11e = true, prop_toolchest_05 = true, prop_table_03b = true,
    prop_chair_01a = true, prop_roadpole_01a = true, prop_traffic_03a = true,
    prop_consign_02a = true, prop_parkingpay = true, prop_boxpile_07d = true,
    prop_worklight_04a = true, prop_barrier_wat_03b = true, prop_roadcone01a = true
}
local spawnedMapping = {}

local function ensureCreatorTables()
    pcall(function()
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
    end)
end

local function spawnSavedMapping()
    local rows = MySQL.query.await('SELECT id, model, x, y, z, heading FROM rp_creator_mapping ORDER BY id ASC') or {}
    for _, row in ipairs(rows) do
        local model = tostring(row.model or '')
        if PROP_CATALOG[model] then
            local entity = CreateObjectNoOffset(GetHashKey(model), tonumber(row.x), tonumber(row.y), tonumber(row.z), true, true, false)
            if entity and entity ~= 0 then
                SetEntityHeading(entity, tonumber(row.heading) or 0.0)
                FreezeEntityPosition(entity, true)
                spawnedMapping[tonumber(row.id)] = entity
            end
        end
    end
end

CreateThread(function()
    Wait(1500)
    ensureCreatorTables()
    Wait(1000)
    local ok, err = pcall(spawnSavedMapping)
    if not ok then print('[rp_tablet_creator] Mapping restore failed: ' .. tostring(err)) end
    local rowsOk, rows = pcall(MySQL.query.await, 'SELECT job, label, x, y, z, sprite, color, scale, enabled FROM rp_creator_job_blips')
    if rowsOk then TriggerClientEvent('rp_tablet_creator:client:syncJobBlips', -1, rows or {}) end
end)

RegisterNetEvent('rp_tablet_creator:server:requestTools', function()
    local src = source
    if not isCreator(src) then return end
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
    if not isCreator(src) then return end
    if type(rawModel) ~= 'string' or not PROP_CATALOG[rawModel] then
        reply(src, 'Objet non autorisé. Choisissez un modèle du catalogue.', false); return
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
    if not isCreator(src) then return end
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
    if not isCreator(src) then return end
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
