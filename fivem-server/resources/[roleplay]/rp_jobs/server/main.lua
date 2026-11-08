local JobsMap = {}

for _, job in ipairs(JobsList) do
    JobsMap[job.name] = job
end
JobsMap[DefaultJob.name] = DefaultJob

function GetJob(name)
    return JobsMap[name] or DefaultJob
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
exports('GetJobGrade', GetJobGrade)
exports('GetAllJobs', GetAllJobs)

RegisterNetEvent('rp_jobs:server:chooseJob', function(jobName)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then return end

    local job = JobsMap[jobName]
    if not job then
        TriggerClientEvent('rp_core:client:notify', src, 'Métier inexistant.', 'error')
        return
    end

    if job.whitelisted then
        TriggerClientEvent('rp_core:client:notify', src, 'Ce métier nécessite un recrutement (Whitelist). Postulez auprès des services compétents !', 'warning')
        return
    end

    player.setJob(jobName, 0)
    TriggerClientEvent('rp_core:client:notify', src, 'Félicitations ! Vous venez d\'être embauché en tant que ' .. job.label .. ' !', 'success')
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

    targetPlayer.setJob(jobName, grade)
    if src > 0 then
        TriggerClientEvent('rp_core:client:notify', src, 'Métier mis à jour pour ' .. targetPlayer.firstname .. ' ' .. targetPlayer.lastname, 'success')
    else
        print('Métier mis à jour.')
    end
end, true)
