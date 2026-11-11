local RESOURCE = GetCurrentResourceName()
local sectorLocks = {}
local databaseReady = false
local DAY_SECONDS = 24 * 60 * 60

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
    return (dx * dx + dy * dy) <= (Config.ServerValidationDistance * Config.ServerValidationDistance)
end

local function GetActiveTerritories()
    local rows = MySQL.query.await(
        'SELECT sector_id, owner_name, color, expires_at FROM rp_territories WHERE expires_at > ?'
        { os.time() }
    )
    local result = {}
    for _, row in ipairs(rows or {}) do
        result[row.sector_id] = {
            ownerName = row.owner_name,
            color = tonumber(row.color),
            expiresAt = tonumber(row.expires_at)
        }
    end
    return result
end

local function BroadcastTerritories()
    local ok, territories = pcall(GetActiveTerritories)
    if not ok then
        print(('[%s] Impossible de charger les territoires: %s'):format(RESOURCE, tostring(territories)))
        return
    end
    TriggerClientEvent('rp_territories:client:sync', -1, territories)
end

local function GetSectorRow(sectorId)
    return MySQL.single.await(
        'SELECT sector_id, owner_identifier, owner_character_id, owner_name, color, expires_at FROM rp_territories WHERE sector_id = ? LIMIT 1',
        { sectorId }
    )
end

local function IsValidColor(colorId)
    colorId = tonumber(colorId)
    return colorId and colorId % 1 == 0 and Config.ColorById[colorId] ~= nil
end

local function CreateStorage()
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
    databaseReady = true
    BroadcastTerritories()
    print(('[%s] %d secteurs chargés, coût %d $, renouvellement tous les %d jours.')
        :format(RESOURCE, #Config.Sectors, Config.Price, Config.DurationDays))
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(500) end
    local ok, err = pcall(CreateStorage)
    if not ok then
        databaseReady = false
        print(('[%s] Erreur initialisation SQL: %s'):format(RESOURCE, tostring(err)))
    end
end)

RegisterNetEvent('rp_territories:server:requestSync', function()
    local src = source
    if not databaseReady then return end
    local ok, territories = pcall(GetActiveTerritories)
    if not ok then
        print(('[%s] Sync impossible pour %s: %s'):format(RESOURCE, tostring(src), tostring(territories)))
        return
    end
    TriggerClientEvent('rp_territories:client:sync', src, territories)
end)

RegisterNetEvent('rp_territories:server:requestOpen', function(rawSectorId)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'territory:open', 1200) then return end
    if not databaseReady then
        Notify(src, 'Le système de territoires est en cours de chargement.', 'warning')
        return
    end
    local sectorId = type(rawSectorId) == 'string' and rawSectorId or ''
    local sector = Config.SectorById[sectorId]
    local player = GetPlayer(src)
    if not sector or not player or not IsNearSector(src, sectorId) then
        Notify(src, 'Point de revendication invalide ou trop éloigné.', 'error')
        return
    end

    local ok, row = pcall(GetSectorRow, sectorId)
    if not ok then
        Notify(src, 'Impossible de consulter ce territoire.', 'error')
        print(('[%s] Sector lookup failed: %s'):format(RESOURCE, tostring(row)))
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
        color = active and tonumber(row.color) or nil,
        expiresAt = active and tonumber(row.expires_at) or nil
    }
    TriggerClientEvent('rp_territories:client:openMenu', src, info)
end)

RegisterNetEvent('rp_territories:server:claim', function(rawSectorId, rawColorId)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'territory:claim', 4000) then return end
    if not databaseReady then
        Notify(src, 'Le système de territoires est indisponible.', 'error')
        return
    end

    local sectorId = type(rawSectorId) == 'string' and rawSectorId or ''
    local colorId = tonumber(rawColorId)
    local player = GetPlayer(src)
    if not player or not Config.SectorById[sectorId] or not IsValidColor(colorId)
        or not IsNearSector(src, sectorId) then
        Notify(src, 'Demande de revendication invalide.', 'error')
        return
    end
    if sectorLocks[sectorId] then
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
            return { success = false, message = 'Ce secteur appartient déjà à ' .. tostring(current.owner_name or 'un autre joueur') .. '.' }
        end

        if type(player.removeCash) ~= 'function' or not player.removeCash(Config.Price) then
            return { success = false, message = ('Il te faut %d $ en liquide pour %s ce secteur.'):format(Config.Price, sameOwner and 'renouveler' or 'revendiquer') }
        end

        local expiresAt = now + (Config.DurationDays * DAY_SECONDS)
        local ownerName = (tostring(player.firstname or '') .. ' ' .. tostring(player.lastname or ''))
            :gsub('[%c<>]', ''):sub(1, 100)
        if ownerName == '' then ownerName = 'Joueur' end

        local saved, affected = pcall(MySQL.update.await, [[
            INSERT INTO rp_territories
                (sector_id, owner_identifier, owner_character_id, owner_name, color, claimed_at, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                owner_identifier = VALUES(owner_identifier),
                owner_character_id = VALUES(owner_character_id),
                owner_name = VALUES(owner_name),
                color = VALUES(color),
                claimed_at = VALUES(claimed_at),
                expires_at = VALUES(expires_at)
        ]], { sectorId, player.identifier, player.charId, ownerName, colorId, now, expiresAt })

        if not saved or type(affected) ~= 'number' or affected < 1 then
            local refunded = type(player.addCash) == 'function' and player.addCash(Config.Price)
            print(('[%s] Échec SQL pour %s; remboursement=%s; résultat=%s')
                :format(RESOURCE, sectorId, tostring(refunded), tostring(affected)))
            return { success = false, message = 'Erreur lors de la sauvegarde. Le paiement a été annulé si possible.' }
        end

        return {
            success = true,
            message = sameOwner and 'Territoire renouvelé pour 7 jours !' or 'Territoire revendiqué !',
            expiresAt = expiresAt
        }
    end)
    finish()

    if not ok then
        print(('[%s] Erreur revendication %s: %s'):format(RESOURCE, sectorId, tostring(result)))
        Notify(src, 'Une erreur est survenue. Aucun territoire ne doit être considéré comme acheté.', 'error')
        return
    end

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
                print(('[%s] %d territoire(s) expiré(s), remis en blanc.'):format(RESOURCE, affected))
                BroadcastTerritories()
            elseif not ok then
                print(('[%s] Nettoyage des expirations impossible: %s'):format(RESOURCE, tostring(affected)))
            end
        end
    end
end)
