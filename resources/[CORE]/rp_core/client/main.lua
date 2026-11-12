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
        -- rp_core may be restarted while the character remains active server-side.
        -- Re-request the existing server-owned player data rather than leaving
        -- this client permanently stuck with the empty startup table.
        for attempt = 1, 10 do
            if IsPlayerLoaded() then return end
            TriggerServerEvent('rp_core:server:requestPlayerDataSync')
            Wait(1000)
        end
        if not IsPlayerLoaded() then
            print('[rp_core] Player data was not restored; the server has no active character session for this client.')
        end
    end)
end)

RegisterNetEvent('rp_core:client:updateNeeds', function(hunger, thirst)
    PlayerData.hunger = math.max(0, math.min(100, tonumber(hunger) or PlayerData.hunger or 100))
    PlayerData.thirst = math.max(0, math.min(100, tonumber(thirst) or PlayerData.thirst or 100))
end)
