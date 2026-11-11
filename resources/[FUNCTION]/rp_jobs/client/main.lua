local JobsMap = {}

for _, job in ipairs(JobsList) do
    JobsMap[job.name] = job
end
JobsMap[DefaultJob.name] = DefaultJob

function GetJob(name)
    return JobsMap[name] or DefaultJob
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
exports('GetJobGrade', GetJobGrade)
exports('GetAllJobs', GetAllJobs)

-- Client events & NUI
local isJobCenterOpen = false
local JobCenterCoords = vector3(-268.3, -956.8, 31.2)

CreateThread(function()
    local blip = AddBlipForCoord(JobCenterCoords.x, JobCenterCoords.y, JobCenterCoords.z)
    SetBlipSprite(blip, 407)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Pôle Emploi - 50 Métiers")
    EndTextCommandSetBlipName(blip)

    while true do
        local sleep = 1250
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local distance = #(coords - JobCenterCoords)

        if distance < 12.0 then
            sleep = 0
            DrawMarker(1, JobCenterCoords.x, JobCenterCoords.y, JobCenterCoords.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1, 1.1, 0.45,
                70, 180, 230, 130, false, true, 2, false, nil, nil, false)
            if distance < 1.8 and not isJobCenterOpen then
                exports['rp_ui']:ShowTextUI('[E] Consulter les offres d’emploi')
                if IsControlJustPressed(0, 38) then
                    OpenJobCenter()
                end
            end
        end
        Wait(sleep)
    end
end)

function OpenJobCenter()
    if isJobCenterOpen then return end
    local coords = GetEntityCoords(PlayerPedId())
    if #(coords - JobCenterCoords) > 5.0 then
        TriggerEvent('rp_core:notify', 'error', 'Rendez-vous au Pôle Emploi pour consulter les offres.')
        return
    end
    isJobCenterOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openJobCenter",
        jobs = JobsList
    })
end

function CloseJobCenter()
    if not isJobCenterOpen then return end
    isJobCenterOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeJobCenter" })
end

RegisterCommand('jobcenter', function()
    OpenJobCenter()
end, false)

RegisterNUICallback('close', function(data, cb)
    CloseJobCenter()
    cb('ok')
end)

RegisterNUICallback('selectJob', function(data, cb)
    if type(data) ~= 'table' or type(data.jobName) ~= 'string' then
        cb('invalid')
        return
    end
    TriggerServerEvent('rp_jobs:server:chooseJob', data.jobName)
    CloseJobCenter()
    cb('ok')
end)
