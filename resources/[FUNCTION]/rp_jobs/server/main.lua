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
    local job = JobsMap[jobName]
    grade = tonumber(grade)
    if not job or not grade or grade % 1 ~= 0 or not job.grades then
        return nil
    end
    return job.grades[grade]
end

function GetAllJobs()
    return JobsList
end

exports('GetJob', GetJob)
exports('IsValidJob', IsValidJob)
exports('GetJobGrade', GetJobGrade)
exports('GetAllJobs', GetAllJobs)

local JobCenterCoords = vector3(-268.3, -956.8, 31.2)

local function IsAtJobCenter(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    return #(GetEntityCoords(ped) - JobCenterCoords) <= 5.0
end

RegisterNetEvent('rp_jobs:server:chooseJob', function(jobName)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_center_hire', 5000) then return end
    if type(jobName) ~= 'string' or #jobName > 50 then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then return end
    if not IsAtJobCenter(src) then
        TriggerClientEvent('rp_core:client:notify', src, 'Vous devez être au Pôle Emploi pour choisir un métier.', 'error')
        return
    end

    local job = JobsMap[jobName]
    if not job then
        TriggerClientEvent('rp_core:client:notify', src, 'Métier inexistant.', 'error')
        return
    end

    if job.whitelisted then
        TriggerClientEvent('rp_core:client:notify', src, 'Ce métier nécessite un recrutement (Whitelist). Postulez auprès des services compétents !', 'warning')
        return
    end

    if not player.setJob(jobName, 0) then
        TriggerClientEvent('rp_core:client:notify', src, 'Votre embauche n’a pas pu être enregistrée.', 'error')
        return
    end
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
