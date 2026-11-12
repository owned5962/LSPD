local JobsMap = {}

for _, job in ipairs(JobsList) do
    JobsMap[job.name] = job
end
JobsMap[DefaultJob.name] = DefaultJob

function GetJob(name)
    return JobsMap[name] or DefaultJob
end

function IsValidJob(name)
    return type(name) == 'string' and JobsMap[name] ~= nil
end

function GetJobGrade(jobName, grade)
    local job = GetJob(jobName)
    grade = tonumber(grade) or 0
    if job and job.grades and job.grades[grade] then
        return job.grades[grade]
    end
    return { label = "Grade " .. grade, salary = 200 }
end

function GetAllJobs()
    return JobsList
end

exports('GetJob', GetJob)
exports('IsValidJob', IsValidJob)
exports('GetJobGrade', GetJobGrade)
exports('GetAllJobs', GetAllJobs)

local function normalizeCustomJob(raw)
    if type(raw) ~= 'table' then return nil, 'Données invalides.' end
    local name = type(raw.name) == 'string' and raw.name:lower() or ''
    local label = type(raw.label) == 'string' and raw.label:gsub('[%c<>]', ' '):sub(1, 64) or ''
    local description = type(raw.description) == 'string' and raw.description:gsub('[%c<>]', ' '):sub(1, 255) or ''
    local category = type(raw.category) == 'string' and raw.category:lower() or 'custom'
    if not name:match('^[a-z][a-z0-9_]+
-- Persistent job-center choice statistics (one increment per successful application).
local JOB_STATS_TABLE = 'rp_job_selection_stats'
local jobStatsReady = false

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS %s (
                job_name VARCHAR(50) NOT NULL,
                selection_count BIGINT UNSIGNED NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (job_name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]):format(JOB_STATS_TABLE))
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_custom_jobs (
            name VARCHAR(40) NOT NULL PRIMARY KEY,
            label VARCHAR(64) NOT NULL,
            category VARCHAR(32) NOT NULL,
            description VARCHAR(255) NOT NULL,
            whitelisted TINYINT(1) NOT NULL DEFAULT 0,
            grades LONGTEXT NOT NULL,
            created_by VARCHAR(80) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        local rows = MySQL.query.await('SELECT name, label, category, description, whitelisted, grades FROM rp_custom_jobs') or {}
        for _, row in ipairs(rows) do
            local decodedOk, grades = pcall(json.decode, row.grades or '{}')
            if decodedOk and type(grades) == 'table' then
                RegisterRuntimeJob({ name=row.name, label=row.label, category=row.category, description=row.description,
                    icon='fas fa-briefcase', whitelisted=tonumber(row.whitelisted)==1, grades=grades })
            else
                print(('[rp_jobs] Invalid grade JSON for custom job %s; ignored.'):format(tostring(row.name)))
            end
        end
    end)
    jobStatsReady = ok
    if not ok then
        print(('[rp_jobs] Impossible de préparer les statistiques des métiers : %s'):format(tostring(err)))
    end
end)

local function RecordJobSelection(jobName)
    if not jobStatsReady then return false end
    local ok, err = pcall(function()
        MySQL.update.await(
            ('INSERT INTO %s (job_name, selection_count) VALUES (?, 1) ON DUPLICATE KEY UPDATE selection_count = selection_count + 1'):format(JOB_STATS_TABLE),
            { jobName }
        )
    end)
    if not ok then
        print(('[rp_jobs] Échec de comptabilisation du métier %s : %s'):format(jobName, tostring(err)))
    end
    return ok
end

local function SendJobStats(src)
    if not jobStatsReady then
        TriggerClientEvent('rp_jobs:client:jobStats', src, {})
        return
    end

    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT job_name, selection_count FROM %s'):format(JOB_STATS_TABLE))
    end)
    if not ok then
        print(('[rp_jobs] Impossible de récupérer les statistiques : %s'):format(tostring(rows)))
        TriggerClientEvent('rp_jobs:client:jobStats', src, {})
        return
    end

    local stats = {}
    for _, row in ipairs(rows or {}) do
        stats[row.job_name] = tonumber(row.selection_count) or 0
    end
    TriggerClientEvent('rp_jobs:client:jobStats', src, stats)
end

RegisterNetEvent('rp_jobs:server:requestJobStats', function()
    local src = source
    local customOk, customRows = pcall(MySQL.query.await, 'SELECT name, label, category, description, whitelisted, grades FROM rp_custom_jobs')
    if customOk then
        local customJobs = {}
        for _, row in ipairs(customRows or {}) do
            local decodedOk, grades = pcall(json.decode, row.grades or '{}')
            if decodedOk and type(grades) == 'table' then
                customJobs[#customJobs + 1] = { name=row.name, label=row.label, category=row.category, description=row.description,
                    icon='fas fa-briefcase', whitelisted=tonumber(row.whitelisted)==1, grades=grades }
            end
        end
        TriggerClientEvent('rp_jobs:client:syncCustomJobs', src, customJobs)
    end
    if not exports['rp_core']:CanPerformAction(src, 'job_center_stats', 1000) then return end
    SendJobStats(src)
end)


-- Job applications are accepted only while the player is physically at the
-- employment center. Never trust the client-side marker or NUI state.
local JobCenterCoords = vector3(-268.3, -956.8, 31.2)

local function IsAtJobCenter(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local distance = #(GetEntityCoords(ped) - JobCenterCoords)
    return distance <= 5.0
end

local function RespondToJobSelection(src, success, message)
    TriggerClientEvent('rp_jobs:client:jobSelectionResult', src, success == true, message)
end

RegisterNetEvent('rp_jobs:server:chooseJob', function(jobName)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_center_hire', 5000) then
        RespondToJobSelection(src, false, 'Patientez quelques secondes avant une nouvelle candidature.')
        return
    end
    if not IsAtJobCenter(src) then
        RespondToJobSelection(src, false, 'Vous devez être au Pôle Emploi pour postuler à ce métier.')
        return
    end
    if type(jobName) ~= 'string' or #jobName > 50 then
        RespondToJobSelection(src, false, 'Nom de métier invalide.')
        return
    end
    -- Character selection and server-side player registration are asynchronous.
    -- Wait briefly for rp_core to publish the active character instead of failing
    -- immediately when the player clicks Apply just after entering the city.
    local player
    for attempt = 1, 24 do
        player = exports['rp_core']:GetPlayerFromId(src)
        if player and tonumber(player.charId) then break end
        player = nil
        Wait(250)
    end
    if not player then
        RespondToJobSelection(src, false, 'Votre personnage est encore en cours de chargement. Réessayez dans quelques secondes.')
        return
    end

    local job = JobsMap[jobName]
    if not job then
        RespondToJobSelection(src, false, 'Métier inexistant.')
        return
    end

    if job.whitelisted then
        RespondToJobSelection(src, false, 'Ce métier nécessite un recrutement. Contactez le service compétent.')
        return
    end

    local ok, applied = pcall(player.setJob, jobName, 0)
    if not ok then
        print(('[rp_jobs] Job application failed for player %s (%s): %s'):format(src, jobName, tostring(applied)))
        RespondToJobSelection(src, false, 'Erreur interne pendant l’embauche. Consultez la console serveur.')
        return
    end
    if applied ~= true then
        RespondToJobSelection(src, false, 'Votre embauche n’a pas pu être enregistrée. Vérifiez la base de données et les logs.')
        return
    end
    RecordJobSelection(jobName)
    local message = 'Félicitations ! Vous venez d\'être embauché en tant que ' .. job.label .. ' !'
    TriggerClientEvent('rp_core:client:notify', src, message, 'success')
    RespondToJobSelection(src, true, message)
end)

RegisterCommand('setjob', function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3]) or 0

    if not targetId or not jobName then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Usage: /setjob [ID] [jobName] [grade]', 'error')
        else
            print('Usage: setjob [ID] [jobName] [grade]')
        end
        return
    end

    local targetPlayer = exports['rp_core']:GetPlayerFromId(targetId)
    if not targetPlayer then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Joueur introuvable.', 'error')
        else
            print('Joueur introuvable.')
        end
        return
    end

    if not targetPlayer.setJob(jobName, grade) then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Modification du métier refusée ou non sauvegardée.', 'error')
        else
            print('Modification du métier refusée ou non sauvegardée.')
        end
        return
    end
    if src > 0 then
        TriggerClientEvent('rp_core:client:notify', src, 'Métier mis à jour pour ' .. targetPlayer.firstname .. ' ' .. targetPlayer.lastname, 'success')
    else
        print('Métier mis à jour.')
    end
end, true)
) or #name > 40 or #name < 3 or name == 'unemployed' or JobsMap[name] then
        return nil, 'Identifiant invalide ou déjà utilisé.'
    end
    if #label < 2 or #description < 3 or not category:match('^[a-z][a-z0-9_]+
-- Persistent job-center choice statistics (one increment per successful application).
local JOB_STATS_TABLE = 'rp_job_selection_stats'
local jobStatsReady = false

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS %s (
                job_name VARCHAR(50) NOT NULL,
                selection_count BIGINT UNSIGNED NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (job_name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]):format(JOB_STATS_TABLE))
    end)
    jobStatsReady = ok
    if not ok then
        print(('[rp_jobs] Impossible de préparer les statistiques des métiers : %s'):format(tostring(err)))
    end
end)

local function RecordJobSelection(jobName)
    if not jobStatsReady then return false end
    local ok, err = pcall(function()
        MySQL.update.await(
            ('INSERT INTO %s (job_name, selection_count) VALUES (?, 1) ON DUPLICATE KEY UPDATE selection_count = selection_count + 1'):format(JOB_STATS_TABLE),
            { jobName }
        )
    end)
    if not ok then
        print(('[rp_jobs] Échec de comptabilisation du métier %s : %s'):format(jobName, tostring(err)))
    end
    return ok
end

local function SendJobStats(src)
    if not jobStatsReady then
        TriggerClientEvent('rp_jobs:client:jobStats', src, {})
        return
    end

    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT job_name, selection_count FROM %s'):format(JOB_STATS_TABLE))
    end)
    if not ok then
        print(('[rp_jobs] Impossible de récupérer les statistiques : %s'):format(tostring(rows)))
        TriggerClientEvent('rp_jobs:client:jobStats', src, {})
        return
    end

    local stats = {}
    for _, row in ipairs(rows or {}) do
        stats[row.job_name] = tonumber(row.selection_count) or 0
    end
    TriggerClientEvent('rp_jobs:client:jobStats', src, stats)
end

RegisterNetEvent('rp_jobs:server:requestJobStats', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_center_stats', 1000) then return end
    SendJobStats(src)
end)


-- Job applications are accepted only while the player is physically at the
-- employment center. Never trust the client-side marker or NUI state.
local JobCenterCoords = vector3(-268.3, -956.8, 31.2)

local function IsAtJobCenter(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local distance = #(GetEntityCoords(ped) - JobCenterCoords)
    return distance <= 5.0
end

local function RespondToJobSelection(src, success, message)
    TriggerClientEvent('rp_jobs:client:jobSelectionResult', src, success == true, message)
end

RegisterNetEvent('rp_jobs:server:chooseJob', function(jobName)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_center_hire', 5000) then
        RespondToJobSelection(src, false, 'Patientez quelques secondes avant une nouvelle candidature.')
        return
    end
    if not IsAtJobCenter(src) then
        RespondToJobSelection(src, false, 'Vous devez être au Pôle Emploi pour postuler à ce métier.')
        return
    end
    if type(jobName) ~= 'string' or #jobName > 50 then
        RespondToJobSelection(src, false, 'Nom de métier invalide.')
        return
    end
    -- Character selection and server-side player registration are asynchronous.
    -- Wait briefly for rp_core to publish the active character instead of failing
    -- immediately when the player clicks Apply just after entering the city.
    local player
    for attempt = 1, 24 do
        player = exports['rp_core']:GetPlayerFromId(src)
        if player and tonumber(player.charId) then break end
        player = nil
        Wait(250)
    end
    if not player then
        RespondToJobSelection(src, false, 'Votre personnage est encore en cours de chargement. Réessayez dans quelques secondes.')
        return
    end

    local job = JobsMap[jobName]
    if not job then
        RespondToJobSelection(src, false, 'Métier inexistant.')
        return
    end

    if job.whitelisted then
        RespondToJobSelection(src, false, 'Ce métier nécessite un recrutement. Contactez le service compétent.')
        return
    end

    local ok, applied = pcall(player.setJob, jobName, 0)
    if not ok then
        print(('[rp_jobs] Job application failed for player %s (%s): %s'):format(src, jobName, tostring(applied)))
        RespondToJobSelection(src, false, 'Erreur interne pendant l’embauche. Consultez la console serveur.')
        return
    end
    if applied ~= true then
        RespondToJobSelection(src, false, 'Votre embauche n’a pas pu être enregistrée. Vérifiez la base de données et les logs.')
        return
    end
    RecordJobSelection(jobName)
    local message = 'Félicitations ! Vous venez d\'être embauché en tant que ' .. job.label .. ' !'
    TriggerClientEvent('rp_core:client:notify', src, message, 'success')
    RespondToJobSelection(src, true, message)
end)

RegisterCommand('setjob', function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3]) or 0

    if not targetId or not jobName then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Usage: /setjob [ID] [jobName] [grade]', 'error')
        else
            print('Usage: setjob [ID] [jobName] [grade]')
        end
        return
    end

    local targetPlayer = exports['rp_core']:GetPlayerFromId(targetId)
    if not targetPlayer then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Joueur introuvable.', 'error')
        else
            print('Joueur introuvable.')
        end
        return
    end

    if not targetPlayer.setJob(jobName, grade) then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Modification du métier refusée ou non sauvegardée.', 'error')
        else
            print('Modification du métier refusée ou non sauvegardée.')
        end
        return
    end
    if src > 0 then
        TriggerClientEvent('rp_core:client:notify', src, 'Métier mis à jour pour ' .. targetPlayer.firstname .. ' ' .. targetPlayer.lastname, 'success')
    else
        print('Métier mis à jour.')
    end
end, true)
) or #category > 32 then
        return nil, 'Nom, catégorie ou description invalide.'
    end
    if type(raw.grades) ~= 'table' then return nil, 'Les cinq grades sont obligatoires.' end
    local grades = {}
    for grade = 0, 4 do
        local entry = raw.grades[grade] or raw.grades[tostring(grade)]
        local gradeLabel = type(entry) == 'table' and tostring(entry.label or ''):gsub('[%c<>]', ' '):sub(1, 48) or ''
        local salary = type(entry) == 'table' and tonumber(entry.salary) or nil
        if #gradeLabel < 2 or not salary or salary % 1 ~= 0 or salary < 0 or salary > 100000 then
            return nil, ('Grade %d invalide.'):format(grade)
        end
        grades[grade] = { label = gradeLabel, salary = salary }
    end
    return { name=name, label=label, description=description, category=category, icon='fas fa-briefcase',
        whitelisted=raw.whitelisted == true, grades=grades }
end

local function RegisterRuntimeJob(job)
    JobsMap[job.name] = job
    for _, current in ipairs(JobsList) do if current.name == job.name then return end end
    JobsList[#JobsList + 1] = job
end

local function CreateCustomJob(raw, createdBy)
    local job, validationError = normalizeCustomJob(raw)
    if not job then return false, validationError end
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO rp_custom_jobs (name, label, category, description, whitelisted, grades, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { job.name, job.label, job.category, job.description, job.whitelisted and 1 or 0, json.encode(job.grades), tostring(createdBy or 'Creator'):sub(1, 80) })
    if not ok or not id then
        print(('[rp_jobs] Custom job save failed: %s'):format(tostring(id)))
        return false, 'Erreur SQL : métier non enregistré.'
    end
    RegisterRuntimeJob(job)
    TriggerClientEvent('rp_jobs:client:syncCustomJobs', -1, { job })
    return true, job
end
exports('CreateCustomJob', CreateCustomJob)

-- Persistent job-center choice statistics (one increment per successful application).
local JOB_STATS_TABLE = 'rp_job_selection_stats'
local jobStatsReady = false

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS %s (
                job_name VARCHAR(50) NOT NULL,
                selection_count BIGINT UNSIGNED NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (job_name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]):format(JOB_STATS_TABLE))
    end)
    jobStatsReady = ok
    if not ok then
        print(('[rp_jobs] Impossible de préparer les statistiques des métiers : %s'):format(tostring(err)))
    end
end)

local function RecordJobSelection(jobName)
    if not jobStatsReady then return false end
    local ok, err = pcall(function()
        MySQL.update.await(
            ('INSERT INTO %s (job_name, selection_count) VALUES (?, 1) ON DUPLICATE KEY UPDATE selection_count = selection_count + 1'):format(JOB_STATS_TABLE),
            { jobName }
        )
    end)
    if not ok then
        print(('[rp_jobs] Échec de comptabilisation du métier %s : %s'):format(jobName, tostring(err)))
    end
    return ok
end

local function SendJobStats(src)
    if not jobStatsReady then
        TriggerClientEvent('rp_jobs:client:jobStats', src, {})
        return
    end

    local ok, rows = pcall(function()
        return MySQL.query.await(('SELECT job_name, selection_count FROM %s'):format(JOB_STATS_TABLE))
    end)
    if not ok then
        print(('[rp_jobs] Impossible de récupérer les statistiques : %s'):format(tostring(rows)))
        TriggerClientEvent('rp_jobs:client:jobStats', src, {})
        return
    end

    local stats = {}
    for _, row in ipairs(rows or {}) do
        stats[row.job_name] = tonumber(row.selection_count) or 0
    end
    TriggerClientEvent('rp_jobs:client:jobStats', src, stats)
end

RegisterNetEvent('rp_jobs:server:requestJobStats', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_center_stats', 1000) then return end
    SendJobStats(src)
end)


-- Job applications are accepted only while the player is physically at the
-- employment center. Never trust the client-side marker or NUI state.
local JobCenterCoords = vector3(-268.3, -956.8, 31.2)

local function IsAtJobCenter(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local distance = #(GetEntityCoords(ped) - JobCenterCoords)
    return distance <= 5.0
end

local function RespondToJobSelection(src, success, message)
    TriggerClientEvent('rp_jobs:client:jobSelectionResult', src, success == true, message)
end

RegisterNetEvent('rp_jobs:server:chooseJob', function(jobName)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_center_hire', 5000) then
        RespondToJobSelection(src, false, 'Patientez quelques secondes avant une nouvelle candidature.')
        return
    end
    if not IsAtJobCenter(src) then
        RespondToJobSelection(src, false, 'Vous devez être au Pôle Emploi pour postuler à ce métier.')
        return
    end
    if type(jobName) ~= 'string' or #jobName > 50 then
        RespondToJobSelection(src, false, 'Nom de métier invalide.')
        return
    end
    -- Character selection and server-side player registration are asynchronous.
    -- Wait briefly for rp_core to publish the active character instead of failing
    -- immediately when the player clicks Apply just after entering the city.
    local player
    for attempt = 1, 24 do
        player = exports['rp_core']:GetPlayerFromId(src)
        if player and tonumber(player.charId) then break end
        player = nil
        Wait(250)
    end
    if not player then
        RespondToJobSelection(src, false, 'Votre personnage est encore en cours de chargement. Réessayez dans quelques secondes.')
        return
    end

    local job = JobsMap[jobName]
    if not job then
        RespondToJobSelection(src, false, 'Métier inexistant.')
        return
    end

    if job.whitelisted then
        RespondToJobSelection(src, false, 'Ce métier nécessite un recrutement. Contactez le service compétent.')
        return
    end

    local ok, applied = pcall(player.setJob, jobName, 0)
    if not ok then
        print(('[rp_jobs] Job application failed for player %s (%s): %s'):format(src, jobName, tostring(applied)))
        RespondToJobSelection(src, false, 'Erreur interne pendant l’embauche. Consultez la console serveur.')
        return
    end
    if applied ~= true then
        RespondToJobSelection(src, false, 'Votre embauche n’a pas pu être enregistrée. Vérifiez la base de données et les logs.')
        return
    end
    RecordJobSelection(jobName)
    local message = 'Félicitations ! Vous venez d\'être embauché en tant que ' .. job.label .. ' !'
    TriggerClientEvent('rp_core:client:notify', src, message, 'success')
    RespondToJobSelection(src, true, message)
end)

RegisterCommand('setjob', function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3]) or 0

    if not targetId or not jobName then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Usage: /setjob [ID] [jobName] [grade]', 'error')
        else
            print('Usage: setjob [ID] [jobName] [grade]')
        end
        return
    end

    local targetPlayer = exports['rp_core']:GetPlayerFromId(targetId)
    if not targetPlayer then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Joueur introuvable.', 'error')
        else
            print('Joueur introuvable.')
        end
        return
    end

    if not targetPlayer.setJob(jobName, grade) then
        if src > 0 then
            TriggerClientEvent('rp_core:client:notify', src, 'Modification du métier refusée ou non sauvegardée.', 'error')
        else
            print('Modification du métier refusée ou non sauvegardée.')
        end
        return
    end
    if src > 0 then
        TriggerClientEvent('rp_core:client:notify', src, 'Métier mis à jour pour ' .. targetPlayer.firstname .. ' ' .. targetPlayer.lastname, 'success')
    else
        print('Métier mis à jour.')
    end
end, true)
