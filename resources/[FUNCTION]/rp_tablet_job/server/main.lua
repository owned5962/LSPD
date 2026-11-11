local activeMissions = {}
local dutyStates = {}

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(src)
end

local function safeName(player)
    local first = tostring(player.firstname or '')
    local last = tostring(player.lastname or '')
    local full = (first .. ' ' .. last):gsub('^%s*(.-)%s*$', '%1')
    return full ~= '' and full or ('Citoyen #' .. tostring(player.source or '?'))
end

local function buildData(src)
    local player = getPlayer(src)
    if not player or not tonumber(player.charId) then return nil end

    local job = exports['rp_jobs']:GetJob(player.job)
    local grade = exports['rp_jobs']:GetJobGrade(player.job, player.jobGrade)
    local roster = {}
    local allPlayers = exports['rp_core']:GetAllPlayers() or {}
    for id, member in pairs(allPlayers) do
        if member and member.job == player.job then
            roster[#roster + 1] = {
                id = tonumber(id) or 0,
                name = safeName(member),
                grade = exports['rp_jobs']:GetJobGrade(member.job, member.jobGrade).label or 'Employé',
                duty = dutyStates[tonumber(id)] == true
            }
        end
    end
    table.sort(roster, function(a, b) return a.name < b.name end)

    return {
        job = tostring(job.label or player.job or 'Sans emploi'),
        jobName = tostring(player.job or 'unemployed'),
        grade = tostring(grade.label or 'Employé'),
        duty = dutyStates[src] == true,
        roster = roster,
        mission = activeMissions[src],
        missionAvailable = player.job ~= 'unemployed'
    }
end

RegisterNetEvent('rp_tablet_job:server:requestData', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'rp_tablet_job:requestData', 800) then return end
    local data = buildData(src)
    if not data then
        TriggerClientEvent('rp_tablet_job:client:notify', src, 'Personnage introuvable ou non chargé.', 'error')
        return
    end
    TriggerClientEvent('rp_tablet_job:client:openData', src, data)
end)

RegisterNetEvent('rp_tablet_job:server:startMission', function(title, description)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'rp_tablet_job:startMission', 2500) then return end
    local player = getPlayer(src)
    if not player or not player.job or player.job == 'unemployed' then return end
    if activeMissions[src] then
        TriggerClientEvent('rp_tablet_job:client:notify', src, 'Terminez votre mission actuelle avant d’en accepter une autre.', 'warning')
        return
    end
    if type(title) ~= 'string' or #title > 64 or type(description) ~= 'string' or #description > 240 then return end
    -- Mission entries are server-owned and tied to the current job; the client
    -- cannot set a reward, change another player's mission, or grant inventory.
    local allowed = {
        police = { ['Patrouille de secteur'] = true, ['Sécurisation d’une zone'] = true },
        ambulance = { ['Ronde de prévention'] = true, ['Intervention médicale'] = true },
        firefighter = { ['Inspection de sécurité'] = true, ['Préparation intervention'] = true },
        mechanic = { ['Contrôle atelier'] = true, ['Assistance dépannage'] = true },
        taxi = { ['Course de transport'] = true, ['Mise à disposition'] = true },
        security = { ['Ronde de surveillance'] = true, ['Sécurisation de site'] = true },
        delivery = { ['Tournée de livraison'] = true, ['Collecte de colis'] = true },
        garbage = { ['Tournée de collecte'] = true, ['Contrôle de secteur'] = true }
    }
    if not (allowed[player.job] and allowed[player.job][title]) then
        TriggerClientEvent('rp_tablet_job:client:notify', src, 'Cette mission n’est pas disponible pour votre métier.', 'error')
        return
    end
    activeMissions[src] = { title = title, description = description, startedAt = os.time() }
    TriggerClientEvent('rp_tablet_job:client:notify', src, 'Mission acceptée : ' .. title, 'success')
    local data = buildData(src)
    if data then TriggerClientEvent('rp_tablet_job:client:refreshData', src, data) end
end)

RegisterNetEvent('rp_tablet_job:server:finishMission', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'rp_tablet_job:finishMission', 2500) then return end
    if not activeMissions[src] then return end
    activeMissions[src] = nil
    TriggerClientEvent('rp_tablet_job:client:notify', src, 'Mission clôturée. Aucun paiement automatique n’est associé.', 'success')
    local data = buildData(src)
    if data then TriggerClientEvent('rp_tablet_job:client:refreshData', src, data) end
end)

AddEventHandler('playerDropped', function()
    activeMissions[source] = nil
    dutyStates[source] = nil
end)

-- Duty state is updated only from the matching job resource's server event.
-- Job resources remain authoritative for access checks and actual service state.
for _, job in ipairs(JobsList or {}) do
    AddEventHandler('job_' .. job.name .. ':dutyUpdated', function(src, status)
        src = tonumber(src)
        if src and type(status) == 'boolean' then dutyStates[src] = status end
    end)
end
