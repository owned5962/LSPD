local detectionsLog = {}
local lastFlagAt = {}
local adminActionAt = {}
local openRequestAt = {}
local openStaff = {}
local adminInvulnerability = {}
local explosionWindows = {}
local entityWindows = {}
local spectateRequestAt = {}
local totalDetections = 0
local activeJails = {}

local function detectionCategory(reason)
    if reason:find('GodMode', 1, true) then return 'godmode', 'critical' end
    if reason:find('Obtention', 1, true) then return 'money', 'critical' end
    if reason:find('Spawn de véhicule', 1, true) then return 'vehicle_spawn', 'high' end
    if reason:find('Modification de gravité', 1, true) then return 'gravity', 'high' end
    if reason:find('argent', 1, true) or reason:find('money', 1, true) then return 'money', 'critical' end
    if reason:find('véhicule', 1, true) or reason:find('vehicle', 1, true) then return 'vehicle_spawn', 'high' end
    if reason:find("Spawn d'arme", 1, true) then return 'weapon_spawn', 'critical' end
    if reason:find('Arme interdite', 1, true) then return 'weapon_blacklist', 'high' end
    if reason:find('SpeedHack', 1, true) then return 'speedhack', 'high' end
    if reason:find('gravité', 1, true) or reason:find('gravity', 1, true) then return 'gravity', 'high' end
    if reason:find('spam', 1, true) then return 'spam', 'medium' end
    if reason:find('Vision', 1, true) then return 'vision', 'medium' end
    return 'other', 'low'
end

local function ensureDetectionStatsTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS anticheat_detections (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            player_name VARCHAR(100) NOT NULL,
            detection_type VARCHAR(40) NOT NULL,
            reason VARCHAR(180) NOT NULL,
            severity VARCHAR(16) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_anticheat_created (created_at),
            INDEX idx_anticheat_type_created (detection_type, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS anticheat_event_log (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            player_id INT NOT NULL,
            player_identifier VARCHAR(80) NULL,
            player_name VARCHAR(100) NOT NULL,
            detection_type VARCHAR(40) NOT NULL,
            reason VARCHAR(180) NOT NULL,
            severity VARCHAR(16) NOT NULL,
            sanction VARCHAR(16) NOT NULL DEFAULT 'warn',
            items_snapshot LONGTEXT NULL,
            weapons_snapshot LONGTEXT NULL,
            cash_snapshot BIGINT NULL,
            bank_snapshot BIGINT NULL,
            job_name VARCHAR(50) NULL,
            job_label VARCHAR(100) NULL,
            job_grade INT NULL,
            job_grade_label VARCHAR(100) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_anticheat_event_created (created_at),
            INDEX idx_anticheat_event_player (player_identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local sanctionColumn = MySQL.query.await("SHOW COLUMNS FROM anticheat_event_log LIKE 'sanction'")
    if not sanctionColumn or #sanctionColumn == 0 then
        MySQL.query.await("ALTER TABLE anticheat_event_log ADD COLUMN sanction VARCHAR(16) NOT NULL DEFAULT 'warn'")
    end
    local snapshotColumns = {
        { 'items_snapshot', 'LONGTEXT NULL' },
        { 'weapons_snapshot', 'LONGTEXT NULL' },
        { 'cash_snapshot', 'BIGINT NULL' },
        { 'bank_snapshot', 'BIGINT NULL' },
        { 'job_name', 'VARCHAR(50) NULL' },
        { 'job_label', 'VARCHAR(100) NULL' },
        { 'job_grade', 'INT NULL' },
        { 'job_grade_label', 'VARCHAR(100) NULL' }
    }
    for _, column in ipairs(snapshotColumns) do
        local existing = MySQL.query.await(("SHOW COLUMNS FROM anticheat_event_log LIKE '%s'"):format(column[1]))
        if not existing or #existing == 0 then
            MySQL.query.await(('ALTER TABLE anticheat_event_log ADD COLUMN %s %s'):format(column[1], column[2]))
        end
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS anticheat_sanction_config (
            category VARCHAR(40) NOT NULL,
            sanction VARCHAR(16) NOT NULL DEFAULT 'warn',
            PRIMARY KEY (category)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS anticheat_weapon_rules (
            weapon_name VARCHAR(80) NOT NULL,
            enabled TINYINT(1) NOT NULL DEFAULT 1,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (weapon_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    for _, weapon in ipairs(Config.WeaponCatalog) do
        MySQL.insert.await(
            'INSERT IGNORE INTO anticheat_weapon_rules (weapon_name, enabled) VALUES (?, ?)',
            { weapon.name, weapon.enabled and 1 or 0 }
        )
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS anticheat_jails (
            identifier VARCHAR(80) NOT NULL,
            reason VARCHAR(180) NOT NULL,
            ends_at BIGINT UNSIGNED NOT NULL,
            jailed_by VARCHAR(80) NULL,
            PRIMARY KEY (identifier),
            INDEX idx_anticheat_jail_end (ends_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(tonumber(src))
end

local function isStaff(src)
    local player = getPlayer(src)
    return IsPlayerAceAllowed(src, 'rp_admin')
        or (player and (player.group == 'admin' or player.group == 'superadmin' or player.group == 'fondateur'))
end

local function canUseAnticheatTablet(src)
    local ok, allowed = pcall(function()
        return exports['rp_tablet_creator']:CanUseTablet(src, 'anticheat')
    end)
    return ok and allowed == true
end

local function notify(src, kind, message)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function getLicense(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return nil
end

local function capturePlayerSnapshot(src)
    local player = getPlayer(src)
    if not player then return nil end

    local items = {}
    local inventoryOk, inventory = pcall(function()
        return exports['rp_inventory']:GetPlayerInventory(src)
    end)
    if inventoryOk and type(inventory) == 'table' then
        for _, item in ipairs(inventory) do
            if type(item) == 'table' and type(item.name) == 'string' then
                items[#items + 1] = {
                    name = item.name,
                    label = tostring(item.label or item.name):sub(1, 100),
                    count = math.max(0, math.floor(tonumber(item.count) or 0))
                }
            end
        end
    else
        print(('[rp_anticheat] Inventaire indisponible pour le joueur %s: %s'):format(src, tostring(inventory)))
    end

    local weapons = {}
    for _, item in ipairs(items) do
        if item.name:lower():match('^weapon_') then
            weapons[#weapons + 1] = { name = item.name, label = item.label, count = item.count, source = 'inventory' }
        end
    end

    local ped = GetPlayerPed(src)
    -- Use the server-side weapon inventory native when the running FXServer
    -- artifact exposes it. Never trust a client-reported loadout for evidence.
    if ped and ped ~= 0 and type(GetPedWeapons) == 'function' then
        local weaponOk, weaponList, ammoByWeapon = pcall(function() return GetPedWeapons(ped) end)
        if weaponOk and type(weaponList) == 'table' then
            for key, rawWeapon in pairs(weaponList) do
                local weaponHash, ammo
                if type(rawWeapon) == 'table' then
                    weaponHash = tonumber(rawWeapon.hash or rawWeapon.weapon or rawWeapon.weaponHash)
                    ammo = tonumber(rawWeapon.ammo)
                else
                    weaponHash = tonumber(rawWeapon)
                end
                if weaponHash and weaponHash ~= 0 then
                    if ammo == nil and type(ammoByWeapon) == 'table' then
                        ammo = tonumber(ammoByWeapon[weaponHash] or ammoByWeapon[tostring(weaponHash)])
                    end
                    weapons[#weapons + 1] = {
                        name = ('hash:%s'):format(weaponHash),
                        label = 'Arme du personnage',
                        hash = weaponHash,
                        ammo = ammo,
                        source = 'ped'
                    }
                end
            end
        end
    end

    local jobName = tostring(player.job or 'unemployed')
    local grade = math.max(0, math.floor(tonumber(player.jobGrade) or 0))
    local jobLabel, gradeLabel = jobName, tostring(grade)
    local jobOk, job = pcall(function() return exports['rp_jobs']:GetJob(jobName) end)
    if jobOk and type(job) == 'table' then jobLabel = tostring(job.label or jobName) end
    local gradeOk, gradeData = pcall(function() return exports['rp_jobs']:GetJobGrade(jobName, grade) end)
    if gradeOk and type(gradeData) == 'table' then gradeLabel = tostring(gradeData.label or grade) end

    return {
        items = items,
        weapons = weapons,
        cash = math.max(0, math.floor(tonumber(player.cash) or 0)),
        bank = math.max(0, math.floor(tonumber(player.bank) or 0)),
        job = jobName,
        jobLabel = jobLabel,
        jobGrade = grade,
        jobGradeLabel = gradeLabel
    }
end

local function safeReason(reason, trustedServerEvent)
    if type(reason) ~= 'string' then return nil end
    reason = reason:gsub('[%c]', ' '):sub(1, 180)
    local allowed = {
        'GodMode / Invincible',
        'SpeedHack à pied',
        'Arme interdite détectée',
        'Vision thermique/nocturne non autorisée',
        'Explosion spam détecté',
        'Entity spam détecté'
    }
    for _, prefix in ipairs(allowed) do
        if reason:sub(1, #prefix) == prefix then return reason end
    end
    if trustedServerEvent then
        local serverOnly = {
            "Obtention d'argent non autorisée",
            "Spawn de véhicule non autorisé",
            "Spawn d'arme non autorisé",
            "Modification de gravité détectée"
        }
        for _, prefix in ipairs(serverOnly) do
            if reason:sub(1, #prefix) == prefix then return reason end
        end
    end
    return nil
end

local function savePersistentBan(targetId, reason, adminId)
    local identifier = getLicense(targetId)
    if not identifier then return false, 'Identifiant license introuvable.' end
    local adminIdentifier = tonumber(adminId) and tonumber(adminId) > 0 and getLicense(tonumber(adminId)) or nil
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO player_bans (identifier, reason, banned_by)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), created_at = CURRENT_TIMESTAMP
        ]], { identifier, reason, adminIdentifier or ('server:' .. tostring(adminId or 0)) })
    end)
    if not ok then
        print('[rp_anticheat] Persistent ban failed: ' .. tostring(err))
        return false, 'Erreur SQL : le bannissement n’a pas été appliqué.'
    end
    return true
end

local function applyPrison(targetId, reason, adminId, minutes)
    local identifier = getLicense(targetId)
    if not identifier then return false, 'Identifiant license introuvable : prison annulée.' end
    minutes = math.max(1, math.min(1440, math.floor(tonumber(minutes) or Config.PrisonMinutes or 30)))
    local adminIdentifier = tonumber(adminId) and tonumber(adminId) > 0 and getLicense(tonumber(adminId)) or nil
    local endsAt = os.time() + minutes * 60
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO anticheat_jails (identifier, reason, ends_at, jailed_by)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE reason = VALUES(reason), ends_at = VALUES(ends_at), jailed_by = VALUES(jailed_by)
        ]], { identifier, reason, endsAt, adminIdentifier or ('server:' .. tostring(adminId or 0)) })
    end)
    if not ok then
        print('[rp_anticheat] Prison persistence failed: ' .. tostring(err))
        return false, 'Erreur SQL : la mise en prison a échoué.'
    end
    local payload = { endsAt = endsAt, jail = Config.PrisonJailCoords, release = Config.PrisonReleaseCoords }
    activeJails[targetId] = { identifier = identifier, endsAt = endsAt, payload = payload }
    TriggerClientEvent('rp_anticheat:applyPrison', targetId, payload)
    return true
end

local function applyConfiguredSanction(targetId, alert)
    local sanction = alert.sanction or (Config.Sanctions and Config.Sanctions[alert.category]) or 'warn'
    local reason = 'AEGIS · ' .. tostring(alert.reason or 'Détection anticheat')
    if sanction == 'warn' then
        notify(targetId, 'warning', '[ANTICHEAT] Avertissement : ' .. reason)
    elseif sanction == 'kick' then
        DropPlayer(targetId, '[AEGIS - KICK] ' .. reason)
    elseif sanction == 'ban' then
        local ok, err = savePersistentBan(targetId, reason, 0)
        if ok then DropPlayer(targetId, '[AEGIS - BAN PERMANENT] ' .. reason)
        else print('[rp_anticheat] Auto-ban refusé: ' .. tostring(err)) end
    elseif sanction == 'prison' then
        local ok, err = applyPrison(targetId, reason, 0, Config.PrisonMinutes)
        if not ok then print('[rp_anticheat] Auto-prison refusée: ' .. tostring(err)) end
    end
end

local function loadDetectionHistory()
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT id, player_id AS playerId, player_name AS playerName,
                   detection_type AS category, reason, severity, sanction,
                   items_snapshot AS itemsSnapshot, weapons_snapshot AS weaponsSnapshot,
                   cash_snapshot AS cash, bank_snapshot AS bank,
                   job_name AS job, job_label AS jobLabel,
                   job_grade AS jobGrade, job_grade_label AS jobGradeLabel,
                   UNIX_TIMESTAMP(created_at) AS timestamp,
                   DATE_FORMAT(created_at, '%H:%i:%s') AS time
            FROM anticheat_event_log ORDER BY id DESC LIMIT 250
        ]])
    end)
    if not ok then
        print('[rp_anticheat] Chargement du registre impossible: ' .. tostring(rows))
        return
    end
    detectionsLog = rows or {}
    for _, row in ipairs(detectionsLog) do
        local itemsOk, items = pcall(json.decode, row.itemsSnapshot or '[]')
        local weaponsOk, weapons = pcall(json.decode, row.weaponsSnapshot or '[]')
        row.items = itemsOk and type(items) == 'table' and items or {}
        row.weapons = weaponsOk and type(weapons) == 'table' and weapons or {}
        row.snapshotAvailable = row.itemsSnapshot ~= nil or row.weaponsSnapshot ~= nil
            or row.cash ~= nil or row.bank ~= nil or row.job ~= nil
        row.cash, row.bank, row.jobGrade = tonumber(row.cash), tonumber(row.bank), tonumber(row.jobGrade)
        row.itemsSnapshot, row.weaponsSnapshot = nil, nil
    end
    local countOk, count = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM anticheat_event_log')
    end)
    if countOk then totalDetections = tonumber(count) or #detectionsLog end
end

local function restorePlayerPrison(targetId)
    if not GetPlayerName(targetId) then return end
    local identifier = getLicense(targetId)
    if not identifier then return end
    local ok, row = pcall(function()
        return MySQL.single.await('SELECT reason, ends_at FROM anticheat_jails WHERE identifier = ?', { identifier })
    end)
    if not ok then
        print('[rp_anticheat] Jail restore lookup failed: ' .. tostring(row))
        return
    end
    if not row then activeJails[targetId] = nil return end
    local endsAt = tonumber(row.ends_at) or 0
    if endsAt <= os.time() then
        MySQL.update('DELETE FROM anticheat_jails WHERE identifier = ?', { identifier })
        activeJails[targetId] = nil
        return
    end
    local payload = { endsAt = endsAt, jail = Config.PrisonJailCoords, release = Config.PrisonReleaseCoords }
    activeJails[targetId] = { identifier = identifier, endsAt = endsAt, payload = payload }
    TriggerClientEvent('rp_anticheat:applyPrison', targetId, payload)
end

local function recordDetection(src, reason, trustedServerEvent)
    local now = os.time()
    if not GetPlayerName(src) or (lastFlagAt[src] and now - lastFlagAt[src] < 5) then return false end
    local safe = safeReason(reason, trustedServerEvent == true)
    if not safe then return false end
    lastFlagAt[src] = now

    local alert = {
        playerId = src,
        playerName = GetPlayerName(src) or 'Inconnu',
        reason = safe,
        time = os.date('%H:%M:%S'),
        timestamp = now,
        severity = 'high'
    }
    alert.category, alert.severity = detectionCategory(safe)
    alert.sanction = (Config.Sanctions and Config.Sanctions[alert.category]) or 'warn'
    alert.snapshot = capturePlayerSnapshot(src)
    local snapshot = alert.snapshot or {}
    alert.items, alert.weapons = snapshot.items or {}, snapshot.weapons or {}
    alert.cash, alert.bank = snapshot.cash, snapshot.bank
    alert.job, alert.jobLabel = snapshot.job, snapshot.jobLabel
    alert.jobGrade, alert.jobGradeLabel = snapshot.jobGrade, snapshot.jobGradeLabel
    alert.snapshotAvailable = alert.snapshot ~= nil
    local persisted, persistError = pcall(function()
        MySQL.insert.await('INSERT INTO anticheat_detections (player_name, detection_type, reason, severity) VALUES (?, ?, ?, ?)',
            { alert.playerName, alert.category, alert.reason, alert.severity })
        alert.id = MySQL.insert.await([[
            INSERT INTO anticheat_event_log
                (player_id, player_identifier, player_name, detection_type, reason, severity, sanction,
                 items_snapshot, weapons_snapshot, cash_snapshot, bank_snapshot,
                 job_name, job_label, job_grade, job_grade_label)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            src, getLicense(src), alert.playerName, alert.category, alert.reason, alert.severity, alert.sanction,
            json.encode(snapshot.items or {}), json.encode(snapshot.weapons or {}),
            snapshot.cash, snapshot.bank, snapshot.job, snapshot.jobLabel,
            snapshot.jobGrade, snapshot.jobGradeLabel
        })
    end)
    if not persisted then
        print('[rp_anticheat][logs] Échec enregistrement du registre: ' .. tostring(persistError))
    else
        totalDetections = totalDetections + 1
    end
    table.insert(detectionsLog, 1, alert)
    if #detectionsLog > 250 then table.remove(detectionsLog) end

    for _, pid in ipairs(GetPlayers()) do
        local staffId = tonumber(pid)
        if staffId and isStaff(staffId) then
            TriggerClientEvent('rp_anticheat:notifyStaff', staffId, alert, totalDetections)
        end
    end
    applyConfiguredSanction(src, alert)
    return true
end

-- Server-side resources can report trusted detections without exposing a network event.
exports('RecordServerDetection', function(rawPlayerId, reason)
    local playerId = tonumber(rawPlayerId)
    if not playerId or not GetPlayerName(playerId) then return false end
    return recordDetection(playerId, reason, true)
end)

-- This is a local server event: clients cannot grant themselves this exemption.
-- Local server-only event (AddEventHandler, deliberately not RegisterNetEvent).
AddEventHandler('rp_anticheat:setAdminInvulnerability', function(rawTargetId, enabled)
    local targetId = tonumber(rawTargetId)
    if not targetId or type(enabled) ~= 'boolean' or not isStaff(targetId) then return end
    adminInvulnerability[targetId] = enabled and true or nil
end)

AddEventHandler('weaponDamageEvent', function(sender, data)
    if not Config.Protections.weapon_damage or not Config.Protections.weapon_damage.enabled then return end
    local src = tonumber(sender) or source
    if type(data) ~= 'table' then return end
    local weaponType = tonumber(data.weaponType)
    if not weaponType then return end
    local weaponName = Config.WeaponHashToName[weaponType]
    if weaponName and Config.WeaponPolicy[weaponName] ~= true then
        CancelEvent()
        recordDetection(src, 'Arme interdite détectée')
    end
end)

AddEventHandler('entityCreating', function(entity)
    if not Config.Protections.entity_spam or not Config.Protections.entity_spam.enabled then return end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local owner = tonumber(NetworkGetEntityOwner(entity))
    if not owner or owner < 1 or not GetPlayerName(owner) or isStaff(owner) then return end

    local now = os.time()
    local window = entityWindows[owner]
    if not window or now - window.startedAt >= (Config.EntityWindowSeconds or 10) then
        window = { startedAt = now, count = 0 }
        entityWindows[owner] = window
    end
    window.count = window.count + 1
    if window.count > (Config.MaxEntitiesPerWindow or 20) then
        CancelEvent()
        recordDetection(owner, 'Entity spam détecté')
    end
end)

AddEventHandler('explosionEvent', function(sender, eventData)
    if not Config.Protections.explosion_spam or not Config.Protections.explosion_spam.enabled then return end
    local src = tonumber(sender) or source
    if not GetPlayerName(src) or isStaff(src) then return end

    local now = os.time()
    local window = explosionWindows[src]
    if not window or now - window.startedAt >= (Config.ExplosionWindowSeconds or 5) then
        window = { startedAt = now, count = 0 }
        explosionWindows[src] = window
    end
    window.count = window.count + 1
    if window.count > (Config.MaxExplosionsPerWindow or 5) then
        CancelEvent()
        recordDetection(src, 'Explosion spam détecté')
    end
end)

local function rebuildWeaponLookups()
    Config.WeaponHashToName = {}
    Config.BlacklistedWeapons = {}
    for _, weapon in ipairs(Config.WeaponCatalog) do
        Config.WeaponHashToName[GetHashKey(weapon.name)] = weapon.name
        if Config.WeaponPolicy[weapon.name] ~= true then
            Config.BlacklistedWeapons[#Config.BlacklistedWeapons + 1] = GetHashKey(weapon.name)
        end
    end
end

local function loadWeaponPolicy()
    local rows = MySQL.query.await('SELECT weapon_name, enabled FROM anticheat_weapon_rules')
    local stored = {}
    for _, row in ipairs(rows or {}) do stored[row.weapon_name] = tonumber(row.enabled) == 1 end
    Config.WeaponPolicy = {}
    for _, weapon in ipairs(Config.WeaponCatalog) do
        local enabled = stored[weapon.name]
        if enabled == nil then enabled = weapon.enabled end
        Config.WeaponPolicy[weapon.name] = enabled
    end
    rebuildWeaponLookups()
    return Config.WeaponPolicy
end

local function getWeaponPolicyList()
    local list = {}
    for _, weapon in ipairs(Config.WeaponCatalog) do
        list[#list + 1] = {
            name = weapon.name, label = weapon.label, category = weapon.category,
            enabled = Config.WeaponPolicy[weapon.name] == true
        }
    end
    return list
end

exports('GetWeaponPolicy', getWeaponPolicyList)
exports('IsWeaponAllowed', function(rawName)
    if type(rawName) ~= 'string' then return false end
    return Config.WeaponPolicy[rawName:upper()] == true
end)
exports('SaveWeaponPolicy', function(src, rawPolicy)
    src = tonumber(src)
    if not src or not isStaff(src) then return false, 'Accès administrateur requis.' end
    local accessOk, allowed = pcall(function()
        return exports['rp_tablet_creator']:CanUseTablet(src, 'admin')
    end)
    if not accessOk or allowed ~= true then return false, 'Accès à la tablette administrateur désactivé.' end
    if type(rawPolicy) ~= 'table' then return false, 'Configuration invalide.' end

    local clean = {}
    for _, weapon in ipairs(Config.WeaponCatalog) do
        if type(rawPolicy[weapon.name]) ~= 'boolean' then
            return false, 'État invalide pour ' .. weapon.name .. '.'
        end
        clean[weapon.name] = rawPolicy[weapon.name]
    end
    for key in pairs(rawPolicy) do
        if not Config.WeaponHashToName or not (function()
            for _, weapon in ipairs(Config.WeaponCatalog) do if weapon.name == key then return true end end
            return false
        end)() then return false, 'Arme inconnue dans la configuration.' end
    end

    local ok, err = pcall(function()
        for _, weapon in ipairs(Config.WeaponCatalog) do
            MySQL.update.await(
                'UPDATE anticheat_weapon_rules SET enabled = ? WHERE weapon_name = ?',
                { clean[weapon.name] and 1 or 0, weapon.name }
            )
        end
    end)
    if not ok then
        print('[rp_anticheat] Enregistrement des règles d’armes impossible: ' .. tostring(err))
        return false, 'Erreur MySQL : configuration non enregistrée.'
    end
    Config.WeaponPolicy = clean
    rebuildWeaponLookups()
    TriggerClientEvent('rp_anticheat:syncWeaponPolicy', -1, Config.WeaponPolicy)
    return true, getWeaponPolicyList()
end)

RegisterNetEvent('rp_anticheat:requestOpen', function()
    local src = source
    local now = os.time()
    if openRequestAt[src] and now - openRequestAt[src] < 1 then return end
    openRequestAt[src] = now
    if not isStaff(src) then
        notify(src, 'error', 'Accès réservé à l’équipe d’administration.')
        return
    end

    local accessOk, tabletAllowed = pcall(function()
        return exports['rp_tablet_creator']:CanUseTablet(src, 'anticheat')
    end)
    if not accessOk or tabletAllowed ~= true then
        notify(src, 'error', 'Votre accès à la tablette anticheat est désactivé.')
        return
    end

    local playersList = {}
    openStaff[src] = true
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        local player = getPlayer(id)
        local ped = GetPlayerPed(id)
        playersList[#playersList + 1] = {
            id = id,
            name = player and ((player.firstname or '') .. ' ' .. (player.lastname or '')) or (GetPlayerName(id) or ('Joueur ' .. id)),
            rawName = GetPlayerName(id) or ('Joueur ' .. id),
            isSelf = id == src,
            ping = GetPlayerPing(id),
            health = ped ~= 0 and GetEntityHealth(ped) or 0,
            armor = ped ~= 0 and GetPedArmour(ped) or 0,
            cash = player and player.cash or 0,
            bank = player and player.bank or 0,
            job = player and player.job or 'civilian',
            routingBucket = GetPlayerRoutingBucket(id),
            snapshot = capturePlayerSnapshot(id)
        }
    end
    TriggerClientEvent('rp_anticheat:openUI', src, Config.Protections, playersList, detectionsLog, totalDetections, Config.WeaponPolicy)
end)


RegisterNetEvent('rp_anticheat:closeUI', function()
    openStaff[source] = nil
end)

local function allowStaffAction(src, action, cooldownSeconds)
    local now = os.time()
    adminActionAt[src] = adminActionAt[src] or {}
    local previous = adminActionAt[src][action] or 0
    if now - previous < (cooldownSeconds or 1) then return false end
    adminActionAt[src][action] = now
    return true
end

RegisterNetEvent('rp_anticheat:requestStatistics', function(period)
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'request_statistics', 2) then return end
    local formats = { day = '%Y-%m-%d', month = '%Y-%m', year = '%Y' }
    local format = formats[period]
    if not format then notify(src, 'error', 'Période statistique invalide.') return end
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT DATE_FORMAT(created_at, ?) AS bucket, detection_type AS category,
                   severity, COUNT(*) AS total
            FROM anticheat_detections
            WHERE created_at >= CASE
                WHEN ? = 'day' THEN DATE_SUB(NOW(), INTERVAL 30 DAY)
                WHEN ? = 'month' THEN DATE_SUB(NOW(), INTERVAL 12 MONTH)
                ELSE '1970-01-01 00:00:00'
            END
            GROUP BY bucket, detection_type, severity
            ORDER BY bucket ASC
         ]], { format, period, period })
    end)
    if not ok then
        print('[rp_anticheat][stats] Chargement des statistiques impossible: ' .. tostring(rows))
        notify(src, 'error', 'Impossible de charger les statistiques anticheat.')
        return
    end
    TriggerClientEvent('rp_anticheat:updateStatistics', src, { period = period, rows = rows or {} })
end)

RegisterNetEvent('rp_anticheat:requestLogs', function()
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'request_logs', 1) then return end
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT id, player_id AS playerId, player_name AS playerName,
                   detection_type AS category, reason, severity, sanction,
                   items_snapshot AS itemsSnapshot, weapons_snapshot AS weaponsSnapshot,
                   cash_snapshot AS cash, bank_snapshot AS bank,
                   job_name AS job, job_label AS jobLabel,
                   job_grade AS jobGrade, job_grade_label AS jobGradeLabel,
                   UNIX_TIMESTAMP(created_at) AS timestamp,
                   DATE_FORMAT(created_at, '%H:%i:%s') AS time
            FROM anticheat_event_log ORDER BY id DESC LIMIT 250
        ]])
    end)
    if ok then
        detectionsLog = rows or {}
        for _, row in ipairs(detectionsLog) do
            local itemsOk, items = pcall(json.decode, row.itemsSnapshot or '[]')
            local weaponsOk, weapons = pcall(json.decode, row.weaponsSnapshot or '[]')
            row.items = itemsOk and type(items) == 'table' and items or {}
            row.weapons = weaponsOk and type(weapons) == 'table' and weapons or {}
            row.snapshotAvailable = row.itemsSnapshot ~= nil or row.weaponsSnapshot ~= nil
                or row.cash ~= nil or row.bank ~= nil or row.job ~= nil
            row.cash = tonumber(row.cash)
            row.bank = tonumber(row.bank)
            row.jobGrade = tonumber(row.jobGrade)
            row.itemsSnapshot, row.weaponsSnapshot = nil, nil
        end
    end
    local countOk, count = pcall(function() return MySQL.scalar.await('SELECT COUNT(*) FROM anticheat_event_log') end)
    if countOk then totalDetections = tonumber(count) or totalDetections end
    TriggerClientEvent('rp_anticheat:updateLogs', src, { logs = detectionsLog, detectionCount = totalDetections })
end)

RegisterNetEvent('rp_anticheat:requestSanctionConfig', function()
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'request_sanction_config', 1) then return end
    TriggerClientEvent('rp_anticheat:updateSanctionConfig', src, {
        sanctions = Config.Sanctions or {},
        prisonMinutes = Config.PrisonMinutes or 30
    })
end)

RegisterNetEvent('rp_anticheat:saveSanctionConfig', function(rawSanctions, rawPrisonMinutes)
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'save_sanction_config', 2) then return end
    if type(rawSanctions) ~= 'table' then notify(src, 'error', 'Configuration de sanctions invalide.') return end
    local categories = { 'godmode', 'money', 'vehicle_spawn', 'weapon_spawn', 'weapon_blacklist', 'speedhack', 'gravity', 'spam', 'vision', 'other' }
    local allowed = { warn = true, kick = true, ban = true, prison = true }
    local clean = {}
    for _, category in ipairs(categories) do
        local action = rawSanctions[category]
        if not allowed[action] then
            notify(src, 'error', 'Sanction invalide pour la catégorie ' .. category .. '.')
            return
        end
        clean[category] = action
    end
    local minutes = tonumber(rawPrisonMinutes)
    if not minutes or minutes % 1 ~= 0 or minutes < 1 or minutes > 1440 then
        notify(src, 'error', 'La durée de prison doit être comprise entre 1 et 1440 minutes.')
        return
    end
    local ok, err = pcall(function()
        for _, category in ipairs(categories) do
            MySQL.insert.await([[
                INSERT INTO anticheat_sanction_config (category, sanction) VALUES (?, ?)
                ON DUPLICATE KEY UPDATE sanction = VALUES(sanction)
            ]], { category, clean[category] })
        end
    end)
    if not ok then
        print('[rp_anticheat] Sauvegarde des sanctions impossible: ' .. tostring(err))
        notify(src, 'error', 'Erreur SQL : configuration non enregistrée.')
        return
    end
    Config.Sanctions = clean
    Config.PrisonMinutes = minutes
    TriggerClientEvent('rp_anticheat:updateSanctionConfig', src, { sanctions = clean, prisonMinutes = minutes })
    notify(src, 'success', 'Configuration des sanctions enregistrée.')
end)

RegisterNetEvent('rp_anticheat:requestBans', function()
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'request_bans', 2) then return end
    local ok, bans = pcall(function()
        return MySQL.query.await(
            'SELECT identifier, reason, banned_by, created_at FROM player_bans ORDER BY created_at DESC LIMIT 100'
        )
    end)
    if not ok then
        print('[rp_anticheat] Ban list lookup failed: ' .. tostring(bans))
        notify(src, 'error', 'Impossible de charger la liste des bannissements.')
        return
    end
    TriggerClientEvent('rp_anticheat:updateBans', src, bans or {})
end)

RegisterNetEvent('rp_anticheat:unban', function(rawIdentifier)
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'unban', 2) then return end
    if type(rawIdentifier) ~= 'string' or #rawIdentifier > 64 or rawIdentifier:sub(1, 8) ~= 'license:' then
        notify(src, 'error', 'Identifiant de bannissement invalide.')
        return
    end
    local ok, affected = pcall(function()
        return MySQL.update.await('DELETE FROM player_bans WHERE identifier = ?', { rawIdentifier })
    end)
    if not ok then
        print('[rp_anticheat] Unban failed: ' .. tostring(affected))
        notify(src, 'error', 'Erreur SQL : bannissement non modifié.')
        return
    end
    notify(src, affected and affected > 0 and 'success' or 'info',
        affected and affected > 0 and 'Bannissement levé.' or 'Aucun bannissement trouvé.')
    local refreshOk, refreshedBans = pcall(function()
        return MySQL.query.await(
            'SELECT identifier, reason, banned_by, created_at FROM player_bans ORDER BY created_at DESC LIMIT 100'
        )
    end)
    if refreshOk then
        TriggerClientEvent('rp_anticheat:updateBans', src, refreshedBans or {})
    else
        print('[rp_anticheat] Ban list refresh failed: ' .. tostring(refreshedBans))
        notify(src, 'error', 'Bannissement levé, mais actualisation de la liste impossible.')
    end
end)

local function BuildSurveillanceSnapshot()
    local playersList = {}
    for _, rawId in ipairs(GetPlayers()) do
        local id = tonumber(rawId)
        if id then
            local player = getPlayer(id)
            local ped = GetPlayerPed(id)
            playersList[#playersList + 1] = {
                id = id,
                name = player and ((player.firstname or '') .. ' ' .. (player.lastname or '')) or (GetPlayerName(id) or ('Joueur ' .. id)),
                rawName = GetPlayerName(id) or ('Joueur ' .. id),
                isSelf = false,
                ping = GetPlayerPing(id),
                health = ped ~= 0 and GetEntityHealth(ped) or 0,
                armor = ped ~= 0 and GetPedArmour(ped) or 0,
                cash = player and player.cash or 0,
                bank = player and player.bank or 0,
                job = player and player.job or 'unemployed',
                routingBucket = GetPlayerRoutingBucket(id)
            }
        end
    end
    return playersList
end

CreateThread(function()
    Wait(1000)
    local ok, err = pcall(ensureDetectionStatsTable)
    if not ok then
        print('[rp_anticheat] Initialisation SQL impossible: ' .. tostring(err))
        return
    end
    loadDetectionHistory()
    local weaponOk, weaponErr = pcall(loadWeaponPolicy)
    if not weaponOk then
        print('[rp_anticheat] Chargement des règles d’armes impossible: ' .. tostring(weaponErr))
        return
    end
    TriggerClientEvent('rp_anticheat:syncWeaponPolicy', -1, Config.WeaponPolicy)
    local configOk, configRows = pcall(function()
        return MySQL.query.await('SELECT category, sanction FROM anticheat_sanction_config')
    end)
    if configOk then
        for _, row in ipairs(configRows or {}) do
            if Config.Sanctions[row.category] and (row.sanction == 'warn' or row.sanction == 'kick' or row.sanction == 'ban' or row.sanction == 'prison') then
                Config.Sanctions[row.category] = row.sanction
            end
        end
    else
        print('[rp_anticheat] Chargement configuration sanctions impossible: ' .. tostring(configRows))
    end
    for _, rawId in ipairs(GetPlayers()) do
        local id = tonumber(rawId)
        if id then restorePlayerPrison(id) end
    end
    while true do
        Wait(5000)
        for playerId, jail in pairs(activeJails) do
            if not GetPlayerName(playerId) then
                activeJails[playerId] = nil
            elseif jail.endsAt <= os.time() then
                activeJails[playerId] = nil
                MySQL.update('DELETE FROM anticheat_jails WHERE identifier = ?', { jail.identifier })
                TriggerClientEvent('rp_anticheat:releasePrison', playerId)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local hasOpenStaff = false
        for staffId in pairs(openStaff) do
            if not GetPlayerName(staffId) or not isStaff(staffId) then
                openStaff[staffId] = nil
            else
                hasOpenStaff = true
            end
        end

        -- Build the player snapshot once per second, not once for every staff member.
        if hasOpenStaff then
            local snapshot = BuildSurveillanceSnapshot()
            for staffId in pairs(openStaff) do
                TriggerClientEvent('rp_anticheat:updatePlayers', staffId, snapshot)
            end
        end
    end
end)

RegisterNetEvent('rp_anticheat:toggleProtection', function(key, state)
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'toggle_protection', 1) then return end
    if type(key) ~= 'string' or type(state) ~= 'boolean' or not Config.Protections[key] then return end

    Config.Protections[key].enabled = state
    TriggerClientEvent('rp_anticheat:syncProtections', -1, Config.Protections)
    notify(src, 'info', 'Protection ' .. Config.Protections[key].label .. ' : ' .. (state and 'ACTIVÉE' or 'DÉSACTIVÉE'))
end)

RegisterNetEvent('rp_anticheat:flag', function(rawReason)
    local src = source
    local reason = safeReason(rawReason)
    if not reason then return end
    if reason:sub(1, #'GodMode / Invincible') == 'GodMode / Invincible' and adminInvulnerability[src] then return end
    recordDetection(src, reason)
end)

RegisterNetEvent('rp_anticheat:requestSpectate', function(rawTargetId)
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not Config.Protections.spectate_monitoring.enabled then
        notify(src, 'error', 'Surveillance non autorisée.')
        return
    end
    local now = os.time()
    if spectateRequestAt[src] and now - spectateRequestAt[src] < 1 then return end
    spectateRequestAt[src] = now

    local targetId = tonumber(rawTargetId)
    if not targetId or targetId == src or not GetPlayerName(targetId) then
        notify(src, 'error', 'Joueur cible introuvable.')
        return
    end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId) then
        notify(src, 'error', 'Le joueur se trouve dans une instance différente.')
        return
    end
    local ped = GetPlayerPed(targetId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        notify(src, 'error', 'Position du joueur indisponible.')
        return
    end
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('rp_anticheat:startSpectate', src, targetId, { x = coords.x, y = coords.y, z = coords.z })
end)

RegisterNetEvent('rp_anticheat:punish', function(rawTargetId, punishType, rawReason)
    local src = source
    if not isStaff(src) or not canUseAnticheatTablet(src) or not allowStaffAction(src, 'punish', 2) then return end
    local targetId = tonumber(rawTargetId)
    if not targetId or targetId == src or not GetPlayerName(targetId) then
        notify(src, 'error', 'Joueur cible introuvable.')
        return
    end
    if punishType ~= 'warn' and punishType ~= 'kick' and punishType ~= 'ban' and punishType ~= 'prison' then return end
    local reason = type(rawReason) == 'string' and rawReason:gsub('[%c]', ' '):sub(1, 180) or 'Décision de modération.'
    if punishType == 'warn' then
        notify(targetId, 'warning', '[ANTICHEAT] Avertissement : ' .. reason)
        notify(src, 'success', 'Avertissement envoyé au joueur ID ' .. targetId .. '.')
    elseif punishType == 'prison' then
        local ok, err = applyPrison(targetId, reason, src, Config.PrisonMinutes)
        if not ok then notify(src, 'error', err) return end
        notify(src, 'success', 'Joueur ID ' .. targetId .. ' placé en prison pour ' .. Config.PrisonMinutes .. ' minutes.')
    elseif punishType == 'ban' then
        local ok, err = savePersistentBan(targetId, reason, src)
        if not ok then notify(src, 'error', err) return end
        DropPlayer(targetId, '[ANTICHEAT - BAN PERMANENT] ' .. reason)
        notify(src, 'success', 'Joueur ID ' .. targetId .. ' banni durablement.')
    else
        DropPlayer(targetId, '[ANTICHEAT] ' .. reason)
        notify(src, 'success', 'Joueur ID ' .. targetId .. ' expulsé.')
    end
end)

RegisterNetEvent('rp_anticheat:prisonExpired', function()
    local src = source
    local jail = activeJails[src]
    if not jail or jail.endsAt > os.time() then return end
    activeJails[src] = nil
    MySQL.update('DELETE FROM anticheat_jails WHERE identifier = ?', { jail.identifier })
    TriggerClientEvent('rp_anticheat:releasePrison', src)
end)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(5000, function()
        if GetPlayerName(src) then restorePlayerPrison(src) end
    end)
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    local identifier = getLicense(src)
    if not identifier then
        deferrals.done('Impossible de vérifier votre identifiant FiveM. Réessayez.')
        return
    end
    local ok, ban = pcall(function()
        return MySQL.single.await('SELECT reason FROM player_bans WHERE identifier = ?', { identifier })
    end)
    if not ok then
        print('[rp_anticheat] Ban lookup failed; connection refused: ' .. tostring(ban))
        deferrals.done('Vérification de sécurité indisponible. Réessayez dans quelques minutes.')
        return
    end
    if ban then
        deferrals.done('Vous êtes banni de ce serveur. Motif : ' .. tostring(ban.reason))
        return
    end
    deferrals.done()
end)

RegisterCommand('rp_unban', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'rp_admin') then return end
    local identifier = args[1]
    if type(identifier) ~= 'string' or identifier:sub(1, 8) ~= 'license:' then
        if src > 0 then notify(src, 'error', 'Usage : /rp_unban license:...') end
        return
    end
    MySQL.update('DELETE FROM player_bans WHERE identifier = ?', { identifier }, function(affected)
        local message = affected and affected > 0 and 'Bannissement levé.' or 'Aucun bannissement trouvé.'
        if src > 0 then notify(src, 'info', message) else print(message) end
    end)
end, true)

AddEventHandler('playerDropped', function()
    lastFlagAt[source] = nil
    openStaff[source] = nil
    adminInvulnerability[source] = nil
    explosionWindows[source] = nil
    spectateRequestAt[source] = nil
    entityWindows[source] = nil
    adminActionAt[source] = nil
    openRequestAt[source] = nil
    activeJails[source] = nil
end)
