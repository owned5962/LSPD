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

-- Client events & NUI
local isJobCenterOpen = false

local JobCenterCoords = { x = -268.3, y = -956.8, z = 31.2 }

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
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isJobCenterOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeJobCenter' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isJobCenterOpen = false
    SetNuiFocus(false, false)
end)

local function IsPlayerAtJobCenter()
    local coords = GetEntityCoords(PlayerPedId())
    local dx, dy, dz = coords.x - JobCenterCoords.x, coords.y - JobCenterCoords.y, coords.z - JobCenterCoords.z
    return (dx * dx + dy * dy + dz * dz) <= (5.0 * 5.0)
end

function OpenJobCenter()
    if not IsPlayerAtJobCenter() then
        TriggerEvent('rp_core:client:notify', 'Rendez-vous au Pôle Emploi pour consulter les offres.', 'error')
        return
    end
    isJobCenterOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openJobCenter",
        jobs = JobsList
    })
    TriggerServerEvent('rp_jobs:server:requestJobStats')
end

function CloseJobCenter()
    isJobCenterOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeJobCenter" })
end

RegisterCommand('jobcenter', function()
    if isJobCenterOpen then CloseJobCenter() else OpenJobCenter() end
end, false)
RegisterKeyMapping('jobcenter', 'Ouvrir le menu des métiers', 'keyboard', 'F5')

RegisterNUICallback('close', function(data, cb)
    CloseJobCenter()
    cb('ok')
end)

RegisterNUICallback('selectJob', function(data, cb)
    if not isJobCenterOpen or type(data) ~= 'table' or type(data.jobName) ~= 'string' then
        cb({ status = 'invalid_request' })
        return
    end
    TriggerServerEvent('rp_jobs:server:chooseJob', data.jobName)
    cb({ status = 'submitted' })
end)

RegisterNetEvent('rp_jobs:client:jobSelectionResult', function(success, message)
    SendNUIMessage({ action = 'jobSelectionResult', success = success == true, message = tostring(message or '') })
end)

RegisterNetEvent('rp_jobs:client:jobStats', function(stats)
    SendNUIMessage({ action = 'jobStats', stats = type(stats) == 'table' and stats or {} })
end)

RegisterNUICallback('requestStats', function(_, cb)
    TriggerServerEvent('rp_jobs:server:requestJobStats')
    cb({ status = 'requested' })
end)
