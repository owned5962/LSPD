local function IsExtendedAdmin(src)
    if IsPlayerAceAllowed(src, 'rp_admin') then return true end
    local player = exports['rp_core']:GetPlayerFromId(src)
    return player ~= nil and (player.group == 'admin' or player.group == 'superadmin')
end

local function AllowExtendedAction(src, action, cooldown)
    return IsExtendedAdmin(src) and exports['rp_core']:CanPerformAction(src, 'admin:' .. action, cooldown or 500)
end

local function NotifyExtended(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'error')
end

local function TargetId(raw)
    local id = tonumber(raw)
    if not id or id < 1 or id % 1 ~= 0 or not GetPlayerName(id) then return nil end
    return id
end

local function LogExtendedAction(src, action, targetId, details)
    local admin = exports['rp_core']:GetPlayerFromId(src)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId) or nil
    local adminName = admin and ((admin.firstname or '') .. ' ' .. (admin.lastname or '')) or (GetPlayerName(src) or 'Administrateur')
    local ok, err = pcall(MySQL.insert.await,
        'INSERT INTO admin_logs (admin_identifier, admin_name, action, target_identifier, details) VALUES (?, ?, ?, ?, ?)',
        { admin and admin.identifier or ('server:' .. tostring(src)), adminName:sub(1, 64),
          tostring(action):sub(1, 64), target and target.identifier or nil,
          tostring(details or ''):gsub('[%c]', ' '):sub(1, 500) })
    if not ok then print('[rp_tablet_admin] Audit log failed: ' .. tostring(err)) end
end

RegisterNetEvent('rp_tablet_admin:server:requestPlayerPositions', function()
    local src = source
    if not AllowExtendedAction(src, 'positions', 1800) then return end
    local players = {}
    for _, rawId in pairs(GetPlayers()) do
        local id = tonumber(rawId)
        if id then
            local player = exports['rp_core']:GetPlayerFromId(id)
            local ped = GetPlayerPed(id)
            local position
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                position = { x = coords.x, y = coords.y, z = coords.z }
            end
            local rawName = GetPlayerName(id) or ('Joueur ' .. id)
            local name = player and ((player.firstname or '') .. ' ' .. (player.lastname or '')) or rawName
            players[#players + 1] = {
                id = id, name = name, rawName = rawName, isSelf = id == src, position = position,
                job = player and player.job or 'unemployed',
                jobLabel = player and (exports['rp_jobs']:GetJob(player.job).label) or 'Sans emploi',
                grade = player and player.jobGrade or 0, cash = player and player.cash or 0,
                bank = player and player.bank or 0, group = player and player.group or 'user',
                ping = GetPlayerPing(id)
            }
        end
    end
    TriggerClientEvent('rp_tablet_admin:client:playerPositions', src, players)
end)

RegisterNetEvent('rp_tablet_admin:server:requestAuditLogs', function()
    local src = source
    if not AllowExtendedAction(src, 'audit_logs', 2000) then
        NotifyExtended(src, 'Accès aux journaux refusé ou demande trop fréquente.')
        return
    end
    local ok, logs = pcall(MySQL.query.await,
        'SELECT admin_name, action, target_identifier, details, created_at FROM admin_logs ORDER BY id DESC LIMIT 50')
    if not ok then
        print('[rp_tablet_admin] Audit log query failed: ' .. tostring(logs))
        NotifyExtended(src, 'Impossible de charger les journaux administrateur.')
        return
    end
    TriggerClientEvent('rp_tablet_admin:client:auditLogs', src, logs or {})
end)

RegisterNetEvent('rp_tablet_admin:server:spectatePlayer', function(rawTargetId)
    local src = source
    if not AllowExtendedAction(src, 'spectate', 500) then return end
    local targetId = TargetId(rawTargetId)
    if not targetId or targetId == src then NotifyExtended(src, 'Cible invalide pour la surveillance.'); return end
    LogExtendedAction(src, 'spectate', targetId, 'Début de surveillance')
    TriggerClientEvent('rp_tablet_admin:client:startSpectate', src, targetId)
end)

RegisterNetEvent('rp_tablet_admin:server:stopSpectate', function()
    local src = source
    if not AllowExtendedAction(src, 'stop_spectate', 500) then return end
    TriggerClientEvent('rp_tablet_admin:client:stopSpectate', src)
end)

RegisterNetEvent('rp_tablet_admin:server:toggleNoclip', function()
    local src = source
    if not AllowExtendedAction(src, 'noclip', 500) then return end
    LogExtendedAction(src, 'noclip', nil, 'Bascule du mode NoClip')
    TriggerClientEvent('rp_tablet_admin:client:toggleNoclip', src)
end)

RegisterNetEvent('rp_tablet_admin:server:toggleGodmode', function()
    local src = source
    if not AllowExtendedAction(src, 'godmode', 500) then return end
    LogExtendedAction(src, 'godmode', nil, 'Bascule du GodMode')
    TriggerClientEvent('rp_tablet_admin:client:toggleGodmode', src)
end)

RegisterNetEvent('rp_tablet_admin:server:spawnVehicle', function(rawModel)
    local src = source
    if not AllowExtendedAction(src, 'spawn_vehicle', 1000) then return end
    if type(rawModel) ~= 'string' or #rawModel < 2 or #rawModel > 40 or not rawModel:match('^[%w_]+$') then
        NotifyExtended(src, 'Modèle de véhicule invalide.')
        return
    end
    LogExtendedAction(src, 'spawn_vehicle', nil, rawModel)
    TriggerClientEvent('rp_tablet_admin:client:spawnVehicle', src, rawModel)
end)

RegisterNetEvent('rp_tablet_admin:server:banPlayer', function(rawTargetId, rawReason)
    local src = source
    if not AllowExtendedAction(src, 'ban', 1500) then return end
    local targetId = TargetId(rawTargetId)
    if not targetId or targetId == src then NotifyExtended(src, 'Joueur cible invalide.'); return end
    local reason = type(rawReason) == 'string' and rawReason:gsub('[%c]', ' '):sub(1, 180) or ''
    if reason == '' then NotifyExtended(src, 'Un motif de bannissement est obligatoire.'); return end
    local license
    for _, identifier in ipairs(GetPlayerIdentifiers(targetId)) do
        if identifier:sub(1, 8) == 'license:' then license = identifier; break end
    end
    if not license then NotifyExtended(src, 'Identifiant license introuvable : bannissement annulé.'); return end
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO player_bans (identifier, reason, banned_by)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), created_at = CURRENT_TIMESTAMP
        ]], { license, reason, (function()
            for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
                if identifier:sub(1, 8) == 'license:' then return identifier end
            end
            return 'server:' .. tostring(src)
        end)() })
    end)
    if not ok then
        print('[rp_tablet_admin] Persistent ban failed: ' .. tostring(err))
        NotifyExtended(src, 'Erreur SQL : bannissement annulé.')
        return
    end
    LogExtendedAction(src, 'ban', targetId, reason)
    DropPlayer(targetId, '[ADMINISTRATION - BAN PERMANENT] ' .. reason)
    NotifyExtended(src, 'Joueur ' .. targetId .. ' banni durablement.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:healPlayer', function(rawTargetId)
    local src = source
    if not AllowExtendedAction(src, 'heal', 500) then return end
    local targetId = TargetId(rawTargetId)
    if not targetId then NotifyExtended(src, 'Joueur cible introuvable.'); return end
    LogExtendedAction(src, 'heal', targetId, 'Soin administrateur')
    TriggerClientEvent('rp_tablet_admin:client:heal', targetId)
    NotifyExtended(src, 'Joueur ' .. targetId .. ' soigné.', 'success')
end)
