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

local function RespondToJobSelection(src, success, message)
    TriggerClientEvent('rp_jobs:client:jobSelectionResult', src, success == true, message)
end

RegisterNetEvent('rp_jobs:server:chooseJob', function(jobName)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_center_hire', 5000) then
        RespondToJobSelection(src, false, 'Patientez quelques secondes avant une nouvelle candidature.')
        return
    end
    if type(jobName) ~= 'string' or #jobName > 50 then
        RespondToJobSelection(src, false, 'Nom de métier invalide.')
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then
        RespondToJobSelection(src, false, 'Votre personnage n’est pas chargé.')
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
