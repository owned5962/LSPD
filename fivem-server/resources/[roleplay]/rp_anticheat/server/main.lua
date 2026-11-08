local detectionsLog = {}

RegisterNetEvent('rp_anticheat:requestOpen', function()
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player or player.group ~= 'admin' and player.group ~= 'superadmin' then
        TriggerClientEvent('rp_core:notify', src, 'error', 'Accès réservé à l\'équipe d\'administration.')
        return
    end

    local playersList = {}
    for _, pid in ipairs(GetPlayers()) do
        local p = exports['rp_core']:GetPlayer(tonumber(pid))
        local ped = GetPlayerPed(pid)
        table.insert(playersList, {
            id = pid,
            name = GetPlayerName(pid),
            ping = GetPlayerPing(pid),
            health = GetEntityHealth(ped),
            armor = GetPedArmour(ped),
            cash = p and p.cash or 0,
            bank = p and p.bank or 0,
            job = p and p.job or 'civilian'
        })
    end

    TriggerClientEvent('rp_anticheat:openUI', src, Config.Protections, playersList)
end)

RegisterNetEvent('rp_anticheat:toggleProtection', function(key, state)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player or player.group ~= 'admin' and player.group ~= 'superadmin' then return end

    if Config.Protections[key] then
        Config.Protections[key].enabled = state
        TriggerClientEvent('rp_core:notify', src, 'info', 'Protection ' .. Config.Protections[key].label .. ' : ' .. (state and 'ACTIVÉE' or 'DÉSACTIVÉE'))
    end
end)

RegisterNetEvent('rp_anticheat:flag', function(reason)
    local src = source
    local name = GetPlayerName(src) or 'Inconnu'
    local alert = {
        playerId = src,
        playerName = name,
        reason = reason,
        time = os.date('%H:%M:%S')
    }
    table.insert(detectionsLog, 1, alert)

    -- Broadcast to all online Staff
    for _, pid in ipairs(GetPlayers()) do
        local staff = exports['rp_core']:GetPlayer(tonumber(pid))
        if staff and (staff.group == 'admin' or staff.group == 'superadmin') then
            TriggerClientEvent('rp_anticheat:notifyStaff', pid, alert)
        end
    end
end)

RegisterNetEvent('rp_anticheat:punish', function(targetId, punishType, reason)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player or player.group ~= 'admin' and player.group ~= 'superadmin' then return end

    if punishType == 'kick' then
        DropPlayer(targetId, '[ANTICHEAT] ' .. (reason or 'Expulsé par un modérateur.'))
        TriggerClientEvent('rp_core:notify', src, 'success', 'Joueur ID ' .. targetId .. ' expulsé.')
    elseif punishType == 'ban' then
        DropPlayer(targetId, '[ANTICHEAT - BAN PERMANENT] ' .. (reason or 'Triche avérée.'))
        TriggerClientEvent('rp_core:notify', src, 'success', 'Joueur ID ' .. targetId .. ' banni.')
    end
end)
