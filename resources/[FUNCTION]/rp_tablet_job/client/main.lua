local isOpen = false
local currentDuty = false

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
    local ok, player = pcall(function() return exports['rp_core']:GetPlayerData() end)
    if not ok or type(player) ~= 'table' or not player.charId then
        notify('Votre personnage est encore en cours de chargement.', 'error')
        return
    end
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

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('rp_tablet_job:server:requestData')
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

RegisterNetEvent('rp_tablet_job:client:openData', function(data)
    if not isOpen then return end
    currentDuty = data.duty == true
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('rp_tablet_job:client:refreshData', function(data)
    if not isOpen then return end
    currentDuty = data.duty == true
    SendNUIMessage({ action = 'update', data = data })
end)

-- Existing job resources publish their validated duty state. Listen to all known
-- job events so the tablet stays synchronized without duplicating duty authority.
for _, job in ipairs(JobsList or {}) do
    RegisterNetEvent('job_' .. job.name .. ':dutyUpdated', function(status)
        currentDuty = status == true
        if isOpen then TriggerServerEvent('rp_tablet_job:server:requestData') end
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
