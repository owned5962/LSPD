local isOpen = false
local currentDuty = false
local currentJob = nil

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', tostring(message or ''), kind or 'info')
end

local function closeTablet()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openTablet()
    if isOpen then closeTablet(); return end
    local readyOk, ready = pcall(function()
        return exports['rp_core']:WaitForPlayerLoaded(5000)
    end)
    if not readyOk or ready ~= true then
        notify('Le personnage n’est pas encore synchronisé avec le serveur. Réessayez dans quelques secondes.', 'warning')
        return
    end
    local ok, player = pcall(function() return exports['rp_core']:GetPlayerData() end)
    if not ok or type(player) ~= 'table' or not tonumber(player.charId) then
        notify('Les données du personnage sont indisponibles. Réessayez dans quelques secondes.', 'error')
        return
    end
    if type(player.job) ~= 'string' or player.job == '' or player.job == 'unemployed' then
        notify('Vous devez avoir un métier pour accéder à la tablette professionnelle.', 'warning')
        return
    end
    currentJob = player.job
    isOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('rp_tablet_job:server:requestData')
end

RegisterCommand('jobtablet', openTablet, false)
RegisterKeyMapping('jobtablet', 'Ouvrir la tablette métier', 'keyboard', 'F4')

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('refreshSalaryStats', function(_, cb)
    TriggerServerEvent('rp_tablet_job:server:requestSalaryStats')
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('rp_tablet_job:server:requestData')
    if currentJob == 'police' and currentDuty then
        TriggerServerEvent('rp_police_interaction:server:requestAlerts')
    end
    cb({ ok = true })
end)

RegisterNUICallback('startMission', function(data, cb)
    TriggerServerEvent('rp_tablet_job:server:startMission', data.title, data.description)
    cb({ ok = true })
end)

RegisterNUICallback('finishMission', function(_, cb)
    TriggerServerEvent('rp_tablet_job:server:finishMission')
    cb({ ok = true })
end)

RegisterNUICallback('refreshJobBank', function(_, cb)
    TriggerServerEvent('rp_jobbank:server:requestFromJobMenu')
    TriggerServerEvent('rp_tablet_job:server:requestSalaryStats')
    cb({ ok = true })
end)

RegisterNUICallback('jobBankDeposit', function(data, cb)
    local amount = tonumber(data and data.amount)
    if not amount or amount % 1 ~= 0 or amount < 1 then cb({ ok = false }); return end
    TriggerServerEvent('rp_jobbank:server:jobMenuDeposit', amount)
    cb({ ok = true })
end)

RegisterNUICallback('jobBankWithdraw', function(data, cb)
    local amount = tonumber(data and data.amount)
    if not amount or amount % 1 ~= 0 or amount < 1 then cb({ ok = false }); return end
    TriggerServerEvent('rp_jobbank:server:jobMenuWithdraw', amount)
    cb({ ok = true })
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    local ok, player = pcall(function() return exports['rp_core']:GetPlayerData() end)
    local job = ok and player and player.job
    if type(job) ~= 'string' or job == '' or job == 'unemployed' then
        cb({ ok = false, error = 'Aucun métier actif.' })
        return
    end
    TriggerServerEvent('job_' .. job .. ':setDuty', not currentDuty)
    cb({ ok = true })
end)

RegisterNUICallback('policeWaypoint', function(data, cb)
    data = type(data) == 'table' and data or {}
    local x, y = tonumber(data.x), tonumber(data.y)
    if currentJob ~= 'police' or not currentDuty or not x or not y
        or x ~= x or y ~= y or math.abs(x) > 5000 or math.abs(y) > 5000 then
        cb({ ok = false })
        return
    end
    SetNewWaypoint(x + 0.0, y + 0.0)
    cb({ ok = true })
end)

RegisterNUICallback('markPoliceAlert', function(data, cb)
    if currentJob ~= 'police' or not currentDuty then cb({ ok = false }); return end
    local alertId = tonumber(data and data.id)
    local status = data and data.status
    if not alertId or alertId % 1 ~= 0 or (status ~= 'Pris en charge' and status ~= 'Clôturée') then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('rp_police_interaction:server:markAlert', alertId, status)
    cb({ ok = true })
end)

RegisterNetEvent('rp_tablet_job:client:openData', function(data)
    if not isOpen then return end
    currentDuty = data.duty == true
    currentJob = data.jobName
    SendNUIMessage({ action = 'open', data = data })
    TriggerServerEvent('rp_jobbank:server:requestFromJobMenu')
    if currentJob == 'police' and currentDuty then
        TriggerServerEvent('rp_police_interaction:server:requestAlerts')
    end
end)

RegisterNetEvent('rp_jobbank:client:jobMenuUpdate', function(data)
    if not isOpen then return end
    SendNUIMessage({ action = 'jobBankData', data = data })
end)

RegisterNetEvent('rp_tablet_job:client:refreshData', function(data)
    if not isOpen then return end
    currentDuty = data.duty == true
    currentJob = data.jobName
    SendNUIMessage({ action = 'update', data = data })
end)

RegisterNetEvent('rp_tablet_job:client:policeAlerts', function(alerts)
    if isOpen and currentJob == 'police' and currentDuty then
        SendNUIMessage({ action = 'policeAlerts', alerts = alerts or {} })
    end
end)

RegisterNetEvent('rp_tablet_job:client:policeAlert', function(alert)
    if isOpen and currentJob == 'police' and currentDuty then
        SendNUIMessage({ action = 'policeAlert', alert = alert })
    end
end)

for _, job in ipairs(JobsList or {}) do
    RegisterNetEvent('job_' .. job.name .. ':dutyUpdated', function(status)
        currentDuty = status == true
        if isOpen then
            TriggerServerEvent('rp_tablet_job:server:requestData')
            if currentJob == 'police' and currentDuty then
                TriggerServerEvent('rp_police_interaction:server:requestAlerts')
            end
        end
    end)
end

RegisterNetEvent('rp_tablet_job:client:notify', function(message, kind)
    notify(message, kind)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        isOpen = false
        SetNuiFocus(false, false)
    end
end)


RegisterNetEvent('rp_tablet_job:client:salaryStats', function(data)
    if not isOpen then return end
    SendNUIMessage({ action = 'salaryStats', data = data or {} })
end)
