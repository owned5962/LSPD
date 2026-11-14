PlayerData = {
    isLoaded = false,
    source = nil,
    identifier = nil,
    charId = nil,
    characterSlot = nil,
    firstname = '',
    lastname = '',
    name = '',
    dateofbirth = '',
    sex = 'm',
    height = 175,
    phoneNumber = nil,
    isDead = false,
    position = nil,
    skin = {},
    metadata = {},
    duty = false,
    job = 'unemployed',
    jobLabel = 'Sans-emploi',
    jobGrade = 0,
    jobGradeLabel = 'Demandeur',
    cash = 0,
    bank = 0,
    group = 'user',
    hunger = 100,
    thirst = 100
}

local playerDataReady = false

local function IsPlayerLoaded()
    local characterId = tonumber(PlayerData.charId)
    return playerDataReady == true and PlayerData.isLoaded == true and characterId ~= nil and characterId > 0
end

RegisterNetEvent('rp_core:client:setPlayerData', function(data)
    if type(data) ~= 'table' then
        print('[rp_core] Ignored invalid player-data synchronization payload.')
        return
    end

    for k, v in pairs(data) do
        PlayerData[k] = v
    end

    local characterId = tonumber(PlayerData.charId)
    playerDataReady = data.isLoaded == true and characterId ~= nil and characterId > 0
    PlayerData.isLoaded = playerDataReady
end)

RegisterNetEvent('rp_core:client:updateCash', function(amount)
    amount = tonumber(amount)
    if amount and amount >= 0 then PlayerData.cash = amount end
end)

RegisterNetEvent('rp_core:client:updateBank', function(amount)
    amount = tonumber(amount)
    if amount and amount >= 0 then PlayerData.bank = amount end
end)

RegisterNetEvent('rp_core:client:setJob', function(job, label, grade, gradeLabel)
    PlayerData.job = job
    PlayerData.jobLabel = label
    PlayerData.jobGrade = grade
    PlayerData.jobGradeLabel = gradeLabel
    PlayerData.duty = false
end)

RegisterNetEvent('rp_core:client:setDuty', function(status, jobName)
    if type(status) ~= 'boolean' then return end
    if jobName and PlayerData.job ~= jobName then return end
    PlayerData.duty = status
end)

exports('GetPlayerData', function()
    return PlayerData
end)

exports('IsPlayerLoaded', IsPlayerLoaded)

-- Wait briefly for the authoritative server synchronization instead of
-- showing a false "character not loaded" message during resource restarts.
exports('WaitForPlayerLoaded', function(timeoutMs)
    local timeout = math.max(0, math.min(15000, tonumber(timeoutMs) or 5000))
    local deadline = GetGameTimer() + timeout
    while not IsPlayerLoaded() and GetGameTimer() < deadline do
        Wait(100)
    end
    return IsPlayerLoaded()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        -- One request is enough: when no in-memory session exists, the server
        -- asks rp_characters to load the account and character data from SQL.
        -- Repeating this request during creator/selector screens only produced
        -- rate-limited noise and a misleading "no active character" warning.
        if IsPlayerLoaded() then return end
        TriggerServerEvent('rp_core:server:requestPlayerDataSync')
        Wait(20000)
        if not IsPlayerLoaded() then
            print('[rp_core] No active character session was restored and no account initialization is pending.')
        end
    end)
end)

RegisterNetEvent('rp_core:client:updateNeeds', function(hunger, thirst)
    PlayerData.hunger = math.max(0, math.min(100, tonumber(hunger) or PlayerData.hunger or 100))
    PlayerData.thirst = math.max(0, math.min(100, tonumber(thirst) or PlayerData.thirst or 100))
    PlayerData.metadata = type(PlayerData.metadata) == 'table' and PlayerData.metadata or {}
    PlayerData.metadata.hunger = PlayerData.hunger
    PlayerData.metadata.thirst = PlayerData.thirst
end)
