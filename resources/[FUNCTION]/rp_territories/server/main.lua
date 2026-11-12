local RESOURCE = GetCurrentResourceName()
local sectorLocks = {}
local databaseReady = false
local DAY_SECONDS = 24 * 60 * 60

-- debug.getinfo(2) points to the exact source line that called this logger.
local function DebugLog(level, event, details)
    local caller = debug and debug.getinfo and debug.getinfo(2, 'Sl') or nil
    local source = caller and caller.short_src or 'server/main.lua'
    local line = caller and caller.currentline or 0
    local message = ('[rp_territories][SERVER][%s:%d][%s] %s')
        :format(source, line, tostring(event), tostring(details or ''))
    if level == 'error' then
        print(('^1%s^7'):format(message))
    elseif level == 'warn' then
        print(('^3%s^7'):format(message))
    else
        print(('^5%s^7'):format(message))
    end
end

DebugLog('info', 'BOOT', 'Initialisation du système de territoires')

local function Notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function GetPlayer(src)
    return exports['rp_core']:GetPlayerFromId(src)
end

local function IsNearSector(src, sectorId)
    local sector = Config.SectorById[sectorId]
    if not sector then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local coords = GetEntityCoords(ped)
    local dx, dy = coords.x - sector.x, coords.y - sector.y
    local horizontalNear = (dx * dx + dy * dy) <= (Config.ServerValidationDistance * Config.ServerValidationDistance)
    local verticalNear = math.abs(coords.z - sector.z) <= 2.0
    return horizontalNear and verticalNear
end

local function GetActiveTerritories()
    DebugLog('info', 'SQL_SELECT_ACTIVE', 'Chargement des territoires actifs')
    local rows = MySQL.query.await(
        'SELECT sector_id, owner_name, territory_name, color, expires_at FROM rp_territories WHERE expires_at > ?',
        { os.time() }
    )
    local result = {}
    for _, row in ipairs(rows or {}) do
        result[row.sector_id] = {
            ownerName = row.owner_name,
            territoryName = row.territory_name,
            color = tonumber(row.color),
            expiresAt = tonumber(row.expires_at)
        }
    end
    return result
end

local function BroadcastTerritories()
    local ok, territories = pcall(GetActiveTerritories)
    if not ok then
        DebugLog('error', 'SYNC_BROADCAST_FAILED', territories)
        return
    end
    DebugLog('info', 'SYNC_BROADCAST', ('Diffusion de %d territoire(s) actif(s)'):format((function() local n = 0 for _ in pairs(territories) do n = n + 1 end return n end)()))
    TriggerClientEvent('rp_territories:client:sync', -1, territories)
end

local function GetSectorRow(sectorId)
    return MySQL.single.await(
        'SELECT sector_id, owner_identifier, owner_character_id, owner_name, territory_name, color, expires_at FROM rp_territories WHERE sector_id = ? LIMIT 1',
        { sectorId }
    )
end

local function IsValidColor(colorId)
    colorId = tonumber(colorId)
    return colorId and colorId % 1 == 0 and Config.ColorById[colorId] ~= nil
end

local function CreateStorage()
    DebugLog('info', 'SQL_CREATE_TABLE', 'Vérification/création de rp_territories')
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS rp_territories (
            sector_id VARCHAR(16) NOT NULL,
            owner_identifier VARCHAR(100) NOT NULL,
            owner_character_id INT NOT NULL,
            owner_name VARCHAR(100) NOT NULL,
            color INT NOT NULL,
            claimed_at BIGINT UNSIGNED NOT NULL,
            expires_at BIGINT UNSIGNED NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (sector_id),
            INDEX idx_rp_territories_expiry (expires_at),
            INDEX idx_rp_territories_owner (owner_identifier, owner_character_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    local nameColumn = MySQL.query.await("SHOW COLUMNS FROM rp_territories LIKE 'territory_name'")
    if not nameColumn or #nameColumn == 0 then
        MySQL.query.await("ALTER TABLE rp_territories ADD COLUMN territory_name VARCHAR(64) NOT NULL DEFAULT '' AFTER owner_name")
    end
    databaseReady = true
    BroadcastTerritories()
    DebugLog('info', 'STORAGE_READY', ('%d secteurs | prix=%d$ | durée=%dj'):format(#Config.Sectors, Config.Price, Config.DurationDays))
end

CreateThread(function()
    DebugLog('info', 'WAIT_OXMYSQL', 'Attente du démarrage de oxmysql')
    while GetResourceState('oxmysql') ~= 'started' do Wait(500) end
    DebugLog('info', 'OXMYSQL_READY', 'oxmysql est démarré')
    local ok, err = pcall(CreateStorage)
    if not ok then
        databaseReady = false
        DebugLog('error', 'STORAGE_INIT_FAILED', err)
    end
end)

RegisterNetEvent('rp_territories:server:requestSync', function()
    local src = source
    if not databaseReady then
        DebugLog('warn', 'SYNC_NOT_READY', 'Synchronisation demandée avant disponibilité SQL')
        return
    end
    DebugLog('info', 'SYNC_REQUEST', 'Demande de synchronisation client')
    local ok, territories = pcall(GetActiveTerritories)
    if not ok then
        DebugLog('error', 'SYNC_REQUEST_FAILED', territories)
        return
    end
    DebugLog('info', 'SYNC_REQUEST_OK', 'Synchronisation envoyée au client')
    TriggerClientEvent('rp_territories:client:sync', src, territories)
end)

RegisterNetEvent('rp_territories:server:requestOpen', function(rawSectorId)
    local src = source
    DebugLog('info', 'OPEN_REQUEST', ('Demande ouverture secteur=%s'):format(tostring(rawSectorId)))
    if not exports['rp_core']:CanPerformAction(src, 'territory:open', 1200) then
        DebugLog('warn', 'OPEN_RATE_LIMIT', 'Action refusée par CanPerformAction')
        return
    end
    if not databaseReady then
        DebugLog('warn', 'OPEN_DATABASE_NOT_READY', 'Base SQL non disponible')
        Notify(src, 'Le système de territoires est en cours de chargement.', 'warning')
        return
    end
    local sectorId = type(rawSectorId) == 'string' and rawSectorId or ''
    local sector = Config.SectorById[sectorId]
    local player = GetPlayer(src)
    if not sector or not player or not IsNearSector(src, sectorId) then
        DebugLog('warn', 'OPEN_VALIDATION_FAILED', ('secteur=%s | joueur chargé=%s | proximité=%s'):format(sectorId, tostring(player ~= nil), tostring(sector ~= nil and player ~= nil and IsNearSector(src, sectorId))))
        Notify(src, 'Point de revendication invalide ou trop éloigné.', 'error')
        return
    end

    local ok, row = pcall(GetSectorRow, sectorId)
    if not ok then
        Notify(src, 'Impossible de consulter ce territoire.', 'error')
        DebugLog('error', 'SECTOR_LOOKUP_FAILED', row)
        return
    end

    local active = row and tonumber(row.expires_at) and tonumber(row.expires_at) > os.time()
    local sameOwner = active and row.owner_identifier == player.identifier
        and tonumber(row.owner_character_id) == tonumber(player.charId)
    local info = {
        sectorId = sectorId,
        price = Config.Price,
        durationDays = Config.DurationDays,
        colors = Config.Colors,
        occupied = active == true,
        isOwner = sameOwner == true,
        ownerName = active and tostring(row.owner_name or 'Joueur') or nil,
        territoryName = active and tostring(row.territory_name or '') or '',
        bankBalance = tonumber(player.bank) or 0,
        color = active and tonumber(row.color) or nil,
        expiresAt = active and tonumber(row.expires_at) or nil
    }
    DebugLog('info', 'OPEN_MENU_SENT', ('secteur=%s | occupé=%s | propriétaire actuel=%s'):format(sectorId, tostring(info.occupied), tostring(info.ownerName or 'aucun')))
    TriggerClientEvent('rp_territories:client:openMenu', src, info)
end)

RegisterNetEvent('rp_territories:server:claim', function(rawSectorId, rawColorId, rawTerritoryName)
    local src = source
    DebugLog('info', 'CLAIM_REQUEST', ('secteur=%s | couleur=%s'):format(tostring(rawSectorId), tostring(rawColorId)))
    if not exports['rp_core']:CanPerformAction(src, 'territory:claim', 4000) then
        DebugLog('warn', 'CLAIM_RATE_LIMIT', 'Action refusée par CanPerformAction')
        return
    end
    if not databaseReady then
        DebugLog('error', 'CLAIM_DATABASE_NOT_READY', 'Base SQL non disponible')
        Notify(src, 'Le système de territoires est indisponible.', 'error')
        return
    end

    local sectorId = type(rawSectorId) == 'string' and rawSectorId or ''
    local colorId = tonumber(rawColorId)
    local territoryName = type(rawTerritoryName) == 'string' and rawTerritoryName:gsub('[%c<>]', ' '):sub(1, 64) or ''
    local player = GetPlayer(src)
    if not player or not Config.SectorById[sectorId] or not IsValidColor(colorId)
        or #territoryName < 2 or not IsNearSector(src, sectorId) then
        DebugLog('warn', 'CLAIM_VALIDATION_FAILED', ('secteur=%s | joueur chargé=%s | couleur valide=%s | proximité=%s'):format(sectorId, tostring(player ~= nil), tostring(IsValidColor(colorId)), tostring(Config.SectorById[sectorId] ~= nil and player ~= nil and IsNearSector(src, sectorId))))
        Notify(src, 'Demande de revendication invalide.', 'error')
        return
    end
    if sectorLocks[sectorId] then
        DebugLog('warn', 'CLAIM_LOCKED', ('secteur=%s déjà en cours de traitement'):format(sectorId))
        Notify(src, 'Cette parcelle est déjà en cours de revendication. Réessaie.', 'warning')
        return
    end

    sectorLocks[sectorId] = true
    local function finish()
        sectorLocks[sectorId] = nil
    end

    local ok, result = pcall(function()
        local current = GetSectorRow(sectorId)
        local now = os.time()
        local active = current and tonumber(current.expires_at) and tonumber(current.expires_at) > now
        local sameOwner = active and current.owner_identifier == player.identifier
            and tonumber(current.owner_character_id) == tonumber(player.charId)
        if active and not sameOwner then
            DebugLog('warn', 'CLAIM_ALREADY_OWNED', ('secteur=%s | propriétaire=%s'):format(sectorId, tostring(current.owner_name)))
            return { success = false, message = 'Ce secteur appartient déjà à ' .. tostring(current.owner_name or 'un autre joueur') .. '.' }
        end

        if type(player.removeBank) ~= 'function' or not player.removeBank(Config.Price, 'Achat du territoire ' .. territoryName, 'territory_purchase') then
            DebugLog('warn', 'CLAIM_PAYMENT_REFUSED', ('secteur=%s | montant=%d$ | fonction removeBank disponible=%s'):format(sectorId, Config.Price, tostring(type(player.removeBank) == 'function')))
            return { success = false, message = ('Il te faut %d $ sur ton compte bancaire pour %s ce secteur.'):format(Config.Price, sameOwner and 'renouveler' or 'revendiquer') }
        end

        local expiresAt = now + (Config.DurationDays * DAY_SECONDS)
        local ownerName = (tostring(player.firstname or '') .. ' ' .. tostring(player.lastname or ''))
            :gsub('[%c<>]', ''):sub(1, 100)
        if ownerName == '' then ownerName = 'Joueur' end

        DebugLog('info', 'CLAIM_SQL_WRITE', ('Sauvegarde secteur=%s | renouvellement=%s'):format(sectorId, tostring(sameOwner == true)))
        local saved, affected = pcall(MySQL.update.await, [[
            INSERT INTO rp_territories
                (sector_id, owner_identifier, owner_character_id, owner_name, territory_name, color, claimed_at, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                owner_identifier = VALUES(owner_identifier),
                owner_character_id = VALUES(owner_character_id),
                owner_name = VALUES(owner_name),
                territory_name = VALUES(territory_name),
                color = VALUES(color),
                claimed_at = VALUES(claimed_at),
                expires_at = VALUES(expires_at)
        ]], { sectorId, player.identifier, player.charId, ownerName, territoryName, colorId, now, expiresAt })

        if not saved or type(affected) ~= 'number' or affected < 1 then
            local refunded = type(player.addBank) == 'function' and player.addBank(Config.Price, 'Remboursement achat territoire', 'territory_refund')
            DebugLog('error', 'CLAIM_SQL_WRITE_FAILED', ('secteur=%s | remboursement=%s | résultat=%s'):format(sectorId, tostring(refunded), tostring(affected)))
            return { success = false, message = 'Erreur lors de la sauvegarde. Le paiement a été annulé si possible.' }
        end

        DebugLog('info', 'CLAIM_SQL_WRITE_OK', ('secteur=%s | expiration=%s'):format(sectorId, tostring(expiresAt)))
        return {
            success = true,
            message = sameOwner and 'Territoire renouvelé pour 7 jours !' or 'Territoire revendiqué !',
            expiresAt = expiresAt,
            territoryName = territoryName,
            ownerName = ownerName,
            color = colorId
        }
    end)
    finish()

    if not ok then
        DebugLog('error', 'CLAIM_UNHANDLED_ERROR', ('secteur=%s | %s'):format(sectorId, tostring(result)))
        Notify(src, 'Une erreur est survenue. Aucun territoire ne doit être considéré comme acheté.', 'error')
        return
    end

    DebugLog(result.success and 'info' or 'warn', result.success and 'CLAIM_COMPLETED' or 'CLAIM_REJECTED', ('secteur=%s | %s'):format(sectorId, tostring(result.message)))
    Notify(src, result.message, result.success and 'success' or 'error')
    TriggerClientEvent('rp_territories:client:claimResult', src, result)
    if result.success then BroadcastTerritories() end
end)

AddEventHandler('playerDropped', function()
    -- No per-player in-memory ownership state: all ownership is persisted in SQL.
end)

CreateThread(function()
    while true do
        Wait(30000)
        if databaseReady then
            local ok, affected = pcall(MySQL.update.await,
                'DELETE FROM rp_territories WHERE expires_at <= ?', { os.time() })
            if ok and type(affected) == 'number' and affected > 0 then
                DebugLog('info', 'TERRITORIES_EXPIRED', ('%d territoire(s) supprimé(s), remis en blanc'):format(affected))
                BroadcastTerritories()
            elseif not ok then
                DebugLog('error', 'EXPIRY_CLEANUP_FAILED', affected)
            end
        end
    end
end)
