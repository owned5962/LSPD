local function IsFounder(src)
    if IsPlayerAceAllowed(src, 'rp_founder') then return true end
    local codeAccessOk, codeAccess = pcall(function()
        return exports['rp_tablet_creator']:HasFounderCodeAccess(src)
    end)
    if codeAccessOk and codeAccess == true then return true end
    local ok, player = pcall(function()
        return exports['rp_core']:GetPlayerFromId(src)
    end)
    return ok and player ~= nil and player.group == 'fondateur'
end

RegisterNetEvent('rp_ui:server:requestDiagnosticsAccess', function()
    local src = source
    if not IsFounder(src) then
        TriggerClientEvent('rp_ui:client:denyFounderDiagnostics', src)
        return
    end
    if not exports['rp_core']:CanPerformAction(src, 'ui:founder_diagnostics_open', 1500) then return end
    TriggerClientEvent('rp_ui:client:openFounderDiagnostics', src)
end)

-- Server-side aggregate statistics for the F12 information panel.
-- Only aggregate counts are exposed; no character identifiers or personal data.

RegisterNetEvent('rp_ui:server:requestDiagnosticsStats', function()
    local src = source
    if not IsFounder(src) then return end
    if not exports['rp_core']:CanPerformAction(src, 'ui:diagnostics_stats', 3000) then return end

    local onlineJobs = {}
    local players = exports['rp_core']:GetAllPlayers() or {}
    for playerId, player in pairs(players) do
        if player and GetPlayerName(tonumber(playerId)) then
            local jobName = type(player.job) == 'string' and player.job or 'unemployed'
            local jobInfo = exports['rp_jobs']:GetJob(jobName)
            local label = jobInfo and jobInfo.label or jobName
            onlineJobs[jobName] = onlineJobs[jobName] or { name = jobName, label = label, count = 0 }
            onlineJobs[jobName].count = onlineJobs[jobName].count + 1
        end
    end

    local okCount, registeredCount = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM users')
    if not okCount then
        print('[rp_ui] Diagnostics account count query failed: ' .. tostring(registeredCount))
        registeredCount = nil
    end

    local okHistory, history = pcall(MySQL.query.await,
        'SELECT DATE_FORMAT(created_at, "%Y-%m-%d") AS day, COUNT(*) AS total FROM users GROUP BY DATE(created_at) ORDER BY DATE(created_at) DESC LIMIT 14')
    if not okHistory then
        print('[rp_ui] Diagnostics registration history query failed: ' .. tostring(history))
        history = {}
    end

    local jobs = {}
    for _, entry in pairs(onlineJobs) do jobs[#jobs + 1] = entry end
    table.sort(jobs, function(a, b)
        if a.count == b.count then return a.label < b.label end
        return a.count > b.count
    end)

    TriggerClientEvent('rp_ui:client:diagnosticsStats', src, {
        online = #GetPlayers(),
        ping = math.max(0, tonumber(GetPlayerPing(src)) or 0),
        registered = tonumber(registeredCount),
        registrationHistory = history or {},
        jobs = jobs,
        sampledAt = os.time()
    })
end)
