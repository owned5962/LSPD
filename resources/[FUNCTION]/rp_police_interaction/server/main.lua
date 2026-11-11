local lastReport = {}
local alerts = {}
local nextAlertId = 0

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(src)
end

local function safeName(player, src)
    local first = tostring(player.firstname or '')
    local last = tostring(player.lastname or '')
    local name = (first .. ' ' .. last):gsub('^%s*(.-)%s*$', '%1')
    return name ~= '' and name or (GetPlayerName(src) or ('Citoyen #' .. src))
end

local function isValidPosition(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    local coords = GetEntityCoords(ped)
    return coords and coords.x == coords.x and coords.y == coords.y and coords.z == coords.z
end

local function broadcastAlert(alert)
    for _, rawId in ipairs(GetPlayers()) do
        local officer = tonumber(rawId)
        local player = officer and getPlayer(officer)
        if player and player.job == 'police' then
            local ok, onDuty = pcall(function()
                return exports['job_police']:IsOnDuty(officer)
            end)
            if ok and onDuty == true then
                TriggerClientEvent('rp_core:client:notify', officer,
                    ('Dispatch LSPD : %s - Suspect %s'):format(alert.title, alert.suspect), 'warning')
                TriggerClientEvent('rp_tablet_job:client:policeAlert', officer, alert)
            end
        end
    end
end

RegisterNetEvent('rp_police_interaction:server:reportOffence', function(offence)
    local src = source
    if type(offence) ~= 'string' or not Config.Offences[offence] then return end
    if not exports['rp_core']:CanPerformAction(src, 'rp_police_interaction:reportOffence', 1500) then return end

    local player = getPlayer(src)
    if not player or player.job == 'police' or not isValidPosition(src) then return end

    local now = GetGameTimer()
    if lastReport[src] and now - lastReport[src] < Config.CooldownMs then return end
    lastReport[src] = now

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local details = Config.Offences[offence]
    TriggerClientEvent('rp_police_interaction:client:interpellation', src, {
        offence = offence,
        label = details.label,
        severity = details.severity,
        officer = 'Agent LSPD',
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })
end)

RegisterNetEvent('rp_police_interaction:server:refused', function(offence)
    local src = source
    if type(offence) ~= 'string' or not Config.Offences[offence] then return end
    local player = getPlayer(src)
    if not player or not isValidPosition(src) then return end
    if not exports['rp_core']:CanPerformAction(src, 'rp_police_interaction:refused', 5000) then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    nextAlertId = nextAlertId + 1
    local alert = {
        id = nextAlertId,
        title = Config.Offences[offence].label,
        severity = Config.Offences[offence].severity,
        suspect = safeName(player, src),
        playerId = src,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        createdAt = os.time(),
        status = 'En cours'
    }
    alerts[#alerts + 1] = alert
    while #alerts > Config.AlertLimit do table.remove(alerts, 1) end
    broadcastAlert(alert)
end)

RegisterNetEvent('rp_police_interaction:server:requestAlerts', function()
    local src = source
    local player = getPlayer(src)
    if not player or player.job ~= 'police' then return end
    local ok, onDuty = pcall(function()
        return exports['job_police']:IsOnDuty(src)
    end)
    if not ok or onDuty ~= true then return end
    TriggerClientEvent('rp_tablet_job:client:policeAlerts', src, alerts)
end)

RegisterNetEvent('rp_police_interaction:server:markAlert', function(alertId, status)
    local src = source
    local player = getPlayer(src)
    if not player or player.job ~= 'police' or (status ~= 'Pris en charge' and status ~= 'Clôturée') then return end
    local ok, onDuty = pcall(function()
        return exports['job_police']:IsOnDuty(src)
    end)
    if not ok or onDuty ~= true then return end
    for _, alert in ipairs(alerts) do
        if alert.id == tonumber(alertId) then
            alert.status = status
            broadcastAlert(alert)
            return
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastReport[source] = nil
end)
