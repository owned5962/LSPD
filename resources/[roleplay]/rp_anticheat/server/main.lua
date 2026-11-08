local detectionsLog = {}
local lastFlagAt = {}

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(tonumber(src))
end

local function isStaff(src)
    local player = getPlayer(src)
    return IsPlayerAceAllowed(src, 'rp_admin')
        or (player and (player.group == 'admin' or player.group == 'superadmin'))
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
        'Vision thermique/nocturne non autorisée'
    }
    for _, prefix in ipairs(allowed) do
        if reason:sub(1, #prefix) == prefix then return reason end
    end
    return nil
end

RegisterNetEvent('rp_anticheat:requestOpen', function()
    local src = source
    if not isStaff(src) then
        notify(src, 'error', 'Accès réservé à l’équipe d’administration.')
        return
    end

    local playersList = {}
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        local player = getPlayer(id)
        local ped = GetPlayerPed(id)
        playersList[#playersList + 1] = {
            id = id,
            name = GetPlayerName(id),
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

RegisterNetEvent('rp_anticheat:toggleProtection', function(key, state)
    local src = source
    if not isStaff(src) then return end
    if type(key) ~= 'string' or type(state) ~= 'boolean' or not Config.Protections[key] then return end

    Config.Protections[key].enabled = state
    TriggerClientEvent('rp_anticheat:syncProtections', -1, Config.Protections)
    notify(src, 'info', 'Protection ' .. Config.Protections[key].label .. ' : ' .. (state and 'ACTIVÉE' or 'DÉSACTIVÉE'))
end)

RegisterNetEvent('rp_anticheat:flag', function(rawReason)
    local src = source
    local now = os.time()
    if lastFlagAt[src] and now - lastFlagAt[src] < 5 then return end
    local reason = safeReason(rawReason)
    if not reason then return end
    lastFlagAt[src] = now

    local alert = {
        playerId = src,
        playerName = GetPlayerName(src) or 'Inconnu',
        reason = reason,
        time = os.date('%H:%M:%S')
    }
    table.insert(detectionsLog, 1, alert)
    if #detectionsLog > 100 then table.remove(detectionsLog) end

    for _, pid in ipairs(GetPlayers()) do
        if isStaff(tonumber(pid)) then
            TriggerClientEvent('rp_anticheat:notifyStaff', tonumber(pid), alert)
        end
    end
end)

RegisterNetEvent('rp_anticheat:punish', function(rawTargetId, punishType, rawReason)
    local src = source
    if not isStaff(src) then return end
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
    local identifier = getLicense(src)
    if not identifier then return end

    deferrals.defer()
    Wait(0)
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
end)
