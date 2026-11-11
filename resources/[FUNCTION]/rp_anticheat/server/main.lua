local detectionsLog = {}
local lastFlagAt = {}
local openStaff = {}
local adminInvulnerability = {}
local explosionWindows = {}
local spectateRequestAt = {}

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

local function safeReason(reason)
    if type(reason) ~= 'string' then return nil end
    reason = reason:gsub('[%c]', ' '):sub(1, 180)
    local allowed = {
        'GodMode / Invincible',
        'SpeedHack à pied',
        'Arme interdite détectée',
        'Vision thermique/nocturne non autorisée',
        'Explosion spam détecté'
    }
    for _, prefix in ipairs(allowed) do
        if reason:sub(1, #prefix) == prefix then return reason end
    end
    return nil
end

local function recordDetection(src, reason)
    local now = os.time()
    if not GetPlayerName(src) or (lastFlagAt[src] and now - lastFlagAt[src] < 5) then return false end
    local safe = safeReason(reason)
    if not safe then return false end
    lastFlagAt[src] = now

    local alert = {
        playerId = src,
        playerName = GetPlayerName(src) or 'Inconnu',
        reason = safe,
        time = os.date('%H:%M:%S')
    }
    table.insert(detectionsLog, 1, alert)
    if #detectionsLog > 100 then table.remove(detectionsLog) end

    for _, pid in ipairs(GetPlayers()) do
        local staffId = tonumber(pid)
        if staffId and isStaff(staffId) then
            TriggerClientEvent('rp_anticheat:notifyStaff', staffId, alert)
        end
    end
    return true
end

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
    for _, weaponHash in ipairs(Config.BlacklistedWeapons) do
        if weaponType == weaponHash then
            CancelEvent()
            recordDetection(src, 'Arme interdite détectée')
            return
        end
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

RegisterNetEvent('rp_anticheat:requestOpen', function()
    local src = source
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
            job = player and player.job or 'civilian'
        }
    end
    TriggerClientEvent('rp_anticheat:openUI', src, Config.Protections, playersList)
end)


RegisterNetEvent('rp_anticheat:closeUI', function()
    openStaff[source] = nil
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
                job = player and player.job or 'unemployed'
            }
        end
    end
    return playersList
end

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
    if not isStaff(src) or not canUseAnticheatTablet(src) then return end
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
    if not isStaff(src) or not canUseAnticheatTablet(src) then return end
    local targetId = tonumber(rawTargetId)
    if not targetId or targetId == src or not GetPlayerName(targetId) then
        notify(src, 'error', 'Joueur cible introuvable.')
        return
    end
    if punishType ~= 'kick' and punishType ~= 'ban' then return end

    local reason = type(rawReason) == 'string' and rawReason:gsub('[%c]', ' '):sub(1, 180) or 'Décision de modération.'
    if punishType == 'ban' then
        local identifier = getLicense(targetId)
        if not identifier then
            notify(src, 'error', 'Identifiant license introuvable : bannissement annulé.')
            return
        end
        local ok, err = pcall(function()
            MySQL.insert.await([[
                INSERT INTO player_bans (identifier, reason, banned_by)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), created_at = CURRENT_TIMESTAMP
            ]], { identifier, reason, getLicense(src) or ('server:' .. src) })
        end)
        if not ok then
            print('[rp_anticheat] Persistent ban failed: ' .. tostring(err))
            notify(src, 'error', 'Erreur SQL : le bannissement n’a pas été appliqué.')
            return
        end
        DropPlayer(targetId, '[ANTICHEAT - BAN PERMANENT] ' .. reason)
        notify(src, 'success', 'Joueur ID ' .. targetId .. ' banni durablement.')
        return
    end

    DropPlayer(targetId, '[ANTICHEAT] ' .. reason)
    notify(src, 'success', 'Joueur ID ' .. targetId .. ' expulsé.')
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
end)
