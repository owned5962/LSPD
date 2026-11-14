local activeMissions = {}

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
    local grade = exports['rp_jobs']:GetJobGrade(player.job, player.jobGrade) or {}
    local roster = {}
    local allPlayers = exports['rp_core']:GetAllPlayers() or {}
    for id, member in pairs(allPlayers) do
        if member and member.job == player.job then
            roster[#roster + 1] = {
                id = tonumber(id) or 0,
                name = safeName(member),
                grade = (exports['rp_jobs']:GetJobGrade(member.job, member.jobGrade) or {}).label or 'Employé',
                duty = member.duty == true
            }
        end
    end
    table.sort(roster, function(a, b) return a.name < b.name end)

    local mission = activeMissions[src]
    if mission and (tonumber(mission.characterId) ~= tonumber(player.charId) or mission.jobName ~= player.job) then
        activeMissions[src] = nil
        mission = nil
    end

    return {
        job = tostring(job and job.label or player.job or 'Sans emploi'),
        jobName = tostring(player.job or 'unemployed'),
        grade = tostring(grade.label or 'Employé'),
        duty = player.duty == true,
        roster = roster,
        mission = mission,
        missionAvailable = player.job ~= 'unemployed'
    }
end

RegisterNetEvent('rp_tablet_job:server:requestSalaryStats', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'rp_tablet_job:salaryStats', 1500) then return end
    local player = getPlayer(src)
    if not player or type(player.job) ~= 'string' or player.job == '' then return end
    local ok, stats = pcall(MySQL.single.await, [[
        SELECT
            COALESCE(SUM(CASE WHEN bt.created_at >= CURDATE() THEN bt.amount ELSE 0 END), 0) AS today,
            COALESCE(SUM(CASE WHEN bt.created_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01') THEN bt.amount ELSE 0 END), 0) AS month,
            COALESCE(SUM(CASE WHEN bt.created_at >= MAKEDATE(YEAR(CURDATE()), 1) THEN bt.amount ELSE 0 END), 0) AS year,
            COALESCE(COUNT(CASE WHEN bt.created_at >= CURDATE() THEN 1 END), 0) AS paymentsToday
        FROM bank_transactions bt
        WHERE bt.type = 'salary' AND bt.reason = ?
    ]], { 'Salaire - ' .. player.job })
    if not ok or type(stats) ~= 'table' then
        print('[rp_tablet_job] Salary statistics query failed: ' .. tostring(stats))
        TriggerClientEvent('rp_tablet_job:client:salaryStats', src, {
            today = 0, month = 0, year = 0, paymentsToday = 0, unavailable = true
        })
        return
    end
    TriggerClientEvent('rp_tablet_job:client:salaryStats', src, {
        today = tonumber(stats.today) or 0,
        month = tonumber(stats.month) or 0,
        year = tonumber(stats.year) or 0,
        paymentsToday = tonumber(stats.paymentsToday) or 0
    })
end)

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

RegisterNetEvent('rp_tablet_job:server:startMission', function(title)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'rp_tablet_job:startMission', 2500) then return end
    local player = getPlayer(src)
    if not player or not player.charId or not player.job or player.job == 'unemployed' then return end
    if player.duty ~= true then
        TriggerClientEvent('rp_tablet_job:client:notify', src, 'Vous devez être en service pour accepter une mission.', 'warning')
        return
    end
    local existing = activeMissions[src]
    if existing and (tonumber(existing.characterId) ~= tonumber(player.charId) or existing.jobName ~= player.job) then
        activeMissions[src] = nil
        existing = nil
    end
    if existing then
        TriggerClientEvent('rp_tablet_job:client:notify', src, 'Terminez votre mission actuelle avant d’en accepter une autre.', 'warning')
        return
    end

    -- Mission titles and descriptions are both server-owned; client text is never persisted.
    local catalog = {
        police = {
            ['Patrouille de secteur'] = 'Effectuez une patrouille préventive dans votre secteur.',
            ['Sécurisation d’une zone'] = 'Assurez une présence visible et sécurisez le périmètre.'
        },
        ambulance = {
            ['Ronde de prévention'] = 'Effectuez une ronde de prévention et vérifiez les points de secours.',
            ['Intervention médicale'] = 'Préparez-vous à répondre à une demande d’assistance.'
        },
        firefighter = {
            ['Inspection de sécurité'] = 'Effectuez une inspection préventive de votre secteur.',
            ['Préparation intervention'] = 'Vérifiez le matériel et préparez une intervention.'
        },
        mechanic = {
            ['Contrôle atelier'] = 'Vérifiez les équipements et l’état de l’atelier.',
            ['Assistance dépannage'] = 'Préparez une mission d’assistance aux automobilistes.'
        },
        taxi = {
            ['Course de transport'] = 'Prenez en charge une demande de transport.',
            ['Mise à disposition'] = 'Assurez une présence dans les zones fréquentées.'
        },
        security = {
            ['Ronde de surveillance'] = 'Effectuez une ronde de surveillance de votre secteur.',
            ['Sécurisation de site'] = 'Assurez la sécurisation d’un site professionnel.'
        },
        delivery = {
            ['Tournée de livraison'] = 'Préparez une tournée de livraison de colis.',
            ['Collecte de colis'] = 'Effectuez une collecte auprès des partenaires.'
        },
        garbage = {
            ['Tournée de collecte'] = 'Préparez une tournée de collecte des déchets.',
            ['Contrôle de secteur'] = 'Vérifiez la propreté et les points de collecte.'
        }
    }
    local description = type(title) == 'string' and catalog[player.job] and catalog[player.job][title]
    if not description then
        TriggerClientEvent('rp_tablet_job:client:notify', src, 'Cette mission n’est pas disponible pour votre métier.', 'error')
        return
    end
    activeMissions[src] = {
        title = title,
        description = description,
        startedAt = os.time(),
        characterId = tonumber(player.charId),
        jobName = player.job
    }
    TriggerClientEvent('rp_tablet_job:client:notify', src, 'Mission acceptée : ' .. title, 'success')
    local data = buildData(src)
    if data then TriggerClientEvent('rp_tablet_job:client:refreshData', src, data) end
end)

RegisterNetEvent('rp_tablet_job:server:finishMission', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'rp_tablet_job:finishMission', 2500) then return end
    local player = getPlayer(src)
    local mission = activeMissions[src]
    if not player or not mission
        or tonumber(mission.characterId) ~= tonumber(player.charId)
        or mission.jobName ~= player.job then
        activeMissions[src] = nil
        TriggerClientEvent('rp_tablet_job:client:notify', src, 'Aucune mission active pour ce personnage.', 'warning')
        return
    end
    activeMissions[src] = nil
    TriggerClientEvent('rp_tablet_job:client:notify', src, 'Mission clôturée. Aucun paiement automatique n’est associé.', 'success')
    local data = buildData(src)
    if data then TriggerClientEvent('rp_tablet_job:client:refreshData', src, data) end
end)

AddEventHandler('playerDropped', function()
    activeMissions[source] = nil
end)

