local EXPECTED_JOB_RESOURCES = 50
local startedJobs = {}

local function SendLoadscreenMessage(payload)
    local ok, encoded = pcall(json.encode, payload)
    if ok and encoded then
        pcall(SendLoadingScreenMessage, encoded)
    end
end

local function SendLoadscreenStage(stage, status, jobCount)
    local payload = { eventName = 'lssStage', stage = stage, status = status }
    if jobCount then payload.jobCount = jobCount end
    SendLoadscreenMessage(payload)
end

RegisterNetEvent('rp_loadscreen:receiveUpdates', function(payload)
    if type(payload) ~= 'table' then return end
    SendLoadscreenMessage(payload)
end)

local function IsMissionResource(resourceName)
    return resourceName == 'rp_missions'
        or resourceName == 'missions'
        or resourceName:match('^mission_') ~= nil
        or resourceName:match('^missions_') ~= nil
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if type(resourceName) ~= 'string' then return end

    if resourceName == GetCurrentResourceName() then
        CreateThread(function()
            Wait(2500)
            TriggerServerEvent('rp_loadscreen:requestUpdates')
            Wait(12000)
            TriggerServerEvent('rp_loadscreen:requestUpdates')
        end)
        return
    end

    if resourceName == 'rp_anticheat' then
        SendLoadscreenStage('anticheat', 'Initialisation des protections et de la surveillance...')
        return
    end

    if resourceName:match('^job_[%w_]+$') then
        if not startedJobs[resourceName] then startedJobs[resourceName] = true end
        local count = 0
        for _ in pairs(startedJobs) do count = count + 1 end
        SendLoadscreenStage('jobs',
            ('Chargement des ressources métiers : %d/%d'):format(math.min(count, EXPECTED_JOB_RESOURCES), EXPECTED_JOB_RESOURCES),
            count)
        return
    end

    if IsMissionResource(resourceName) then
        SendLoadscreenStage('missions', 'Initialisation du module de missions...')
        return
    end

    if resourceName:match('^rp_') and resourceName ~= 'rp_characters' then
        SendLoadscreenStage('modules', ('Démarrage du module : %s'):format(resourceName))
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if type(resourceName) == 'string' and startedJobs[resourceName] then
        startedJobs[resourceName] = nil
        local count = 0
        for _ in pairs(startedJobs) do count = count + 1 end
        SendLoadscreenStage('jobs',
            ('Ressources métiers actives : %d/%d'):format(math.min(count, EXPECTED_JOB_RESOURCES), EXPECTED_JOB_RESOURCES),
            count)
    end
end)
