Players = {}

local actionCooldowns = {}
local pendingDisconnectSaves = {}
local pendingDisconnectPlayers = {}

local TIMER_MODULUS = 4294967296

local function CanPerformAction(src, action, cooldownMs)
    src = tonumber(src)
    if not src or src < 1 or src % 1 ~= 0
        or type(action) ~= 'string' or action == '' or #action > 80 then
        return false
    end

    local cooldown = tonumber(cooldownMs) or 1000
    if cooldown ~= cooldown or cooldown == math.huge or cooldown == -math.huge then
        cooldown = 1000
    end
    cooldown = math.floor(math.max(0, math.min(60000, cooldown)))

    local now = GetGameTimer() % TIMER_MODULUS
    actionCooldowns[src] = actionCooldowns[src] or {}
    local lastAction = actionCooldowns[src][action]
    if lastAction ~= nil then
        local elapsed = (now - lastAction) % TIMER_MODULUS
        if elapsed < cooldown then return false end
    end

    actionCooldowns[src][action] = now
    return true
end

exports('CanPerformAction', CanPerformAction)

local function IsCharacterSavePending(characterId)
    characterId = tonumber(characterId)
    return characterId ~= nil and pendingDisconnectSaves[characterId] == true
end

exports('IsCharacterSavePending', IsCharacterSavePending)

function GetPlayerFromId(source)
    local player = Players[tonumber(source)]
    return player and player.isLoaded == true and player or nil
end

local function WaitForPlayerLoaded(source, timeoutMs)
    local src = tonumber(source)
    if not src or src < 1 then return nil end
    local deadline = GetGameTimer() + (tonumber(timeoutMs) or 8000)
    while GetGameTimer() < deadline do
        local player = GetPlayerFromId(src)
        if player then return player end
        Wait(100)
    end
    return GetPlayerFromId(src)
end

exports('GetPlayerFromId', GetPlayerFromId)
exports('WaitForPlayerLoaded', WaitForPlayerLoaded)

function GetPlayerByIdentifier(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    for _, player in pairs(Players) do
        if player and player.identifier == identifier and player.isLoaded == true then
            return player
        end
    end
    return nil
end

exports('GetPlayerByIdentifier', GetPlayerByIdentifier)

function GetAllPlayers()
    local list = {}
    for src, player in pairs(Players) do
        if player and player.isLoaded == true then
            list[src] = player
        end
    end
    return list
end

exports('GetAllPlayers', GetAllPlayers)

function RegisterPlayer(source, player)
    local src = tonumber(source)
    local characterId = player and tonumber(player.charId)
    local slot = player and tonumber(player.slot)
    local identifier = player and player.identifier
    local validIdentifier = type(identifier) == 'string'
        and identifier:match('^license:[%w_%-]+$') ~= nil
        and #identifier <= 80

    if not src or src < 1 or src % 1 ~= 0 or not GetPlayerName(src) or type(player) ~= 'table'
        or tonumber(player.source) ~= src or not validIdentifier
        or not characterId or characterId < 1 or characterId % 1 ~= 0
        or not slot or slot < 1 or slot > 3 or slot % 1 ~= 0 then
        return false
    end

    if pendingDisconnectSaves[characterId] then
        return false
    end

    local existing = Players[src]
    if existing and existing.identifier ~= identifier then
        return false
    end

    local byIdent = GetPlayerByIdentifier(identifier)
    if byIdent and tonumber(byIdent.source) ~= src then
        return false
    end

    player.isLoaded = true
    Players[src] = player
    return true
end

exports('RegisterPlayer', RegisterPlayer)

function UnregisterPlayer(source, identifier)
    local src = tonumber(source)
    if src and Players[src] then
        if identifier and Players[src].identifier ~= identifier then
            return false
        end
        Players[src] = nil
        return true
    end
    return false
end

exports('UnregisterPlayer', UnregisterPlayer)

function GetPlayerSnapshot(source)
    local player = GetPlayerFromId(source)
    if not player then return nil end
    return {
        source = player.source,
        identifier = player.identifier,
        charId = player.charId,
        slot = player.slot,
        firstname = player.firstname,
        lastname = player.lastname,
        sex = player.sex,
        position = player.position,
        skin = player.skin,
        cash = player.cash,
        bank = player.bank,
        job = player.job,
        jobGrade = player.jobGrade,
        group = player.group,
        metadata = player.metadata,
    }
end

exports('GetPlayerSnapshot', GetPlayerSnapshot)

RegisterNetEvent('rp_core:server:requestPlayerDataSync', function()
    local src = source
    if not CanPerformAction(src, 'core:request_player_data_sync', 500) then return end
    local player = Players[tonumber(src)]
    if not player or not tonumber(player.charId) or type(player.syncClient) ~= 'function' then
        TriggerClientEvent('rp_core:client:requestCharacterBootstrap', src)
        return
    end
    player.syncClient()
end)

-- Save connected characters every minute on a single sequential worker.
-- Parallel workers raced on nextIndex and shared saveLocks, causing repeated
-- "Autosave deferred/failed" spam for the same character.
CreateThread(function()
    local lastFailureLog = {}
    while true do
        Wait(60 * 1000)

        local queue = {}
        for _, player in pairs(Players) do
            if player and player.save and player.isLoaded == true then
                queue[#queue + 1] = player
            end
        end

        local okCount, failCount = 0, 0
        for index = 1, #queue do
            local player = queue[index]
            if Players[tonumber(player.source)] == player and player.isLoaded == true then
                local ok, saved = pcall(player.save)
                if (not ok or saved ~= true) then
                    Wait(150)
                    ok, saved = pcall(player.save)
                end
                if ok and saved == true then
                    okCount = okCount + 1
                    lastFailureLog[player.charId] = nil
                else
                    failCount = failCount + 1
                    local charId = tostring(player.charId)
                    local now = GetGameTimer()
                    local last = lastFailureLog[player.charId] or 0
                    if (now - last) > 300000 then
                        lastFailureLog[player.charId] = now
                        print(('[rp_core] Autosave deferred for character %s (%s)')
                            :format(charId, ok and 'lock/SQL busy' or tostring(saved)))
                    end
                end
            end
            Wait(100)
        end
        if #queue > 0 then
            print(('[rp_core] [OK] Autosave cycle: %d saved, %d deferred / %d players')
                :format(okCount, failCount, #queue))
        end
    end
end)

-- Compact boot health summary (one block instead of dozens of lines).
CreateThread(function()
    Wait(8000)
    local groups = {
        { name = 'CORE', resources = { 'oxmysql', 'rp_core', 'rp_characters', 'rp_jobs', 'rp_inventory', 'rp_economy' } },
        { name = 'UI', resources = { 'rp_ui', 'rp_tablet_job', 'rp_tablet_admin', 'rp_tablet_creator', 'rp_anticheat', 'rp_loadscreen' } },
        { name = 'WORLD', resources = { 'rp_world', 'rp_businesses', 'rp_territories', 'rp_garages', 'rp_fuel' } },
    }
    print('^5========== LSS BOOT STATUS =========^=7')
    for _, group in ipairs(groups) do
        local ok, total = 0, #group.resources
        local missing = {}
        for _, res in ipairs(group.resources) do
            if GetResourceState(res) == 'started' then
                ok = ok + 1
            else
                missing[#missing + 1] = res .. '(' .. tostring(GetResourceState(res)) .. ')'
            end
        end
        local color = (ok == total) and '^2' or '^3'
        local mark = (ok == total) and '[OK]' or '[WARN]'
        print(('%s%s %-6s [%d/%d] %s^7'):format(color, mark, group.name, ok, total, mark == '[OK]' and '' or table.concat(missing, ', ')))
    end
    local jobOk, jobTotal = 0, 0
    local num = GetNumResources()
    for i = 0, num - 1 do
        local name = GetResourceByFindIndex(i)
        if type(name) == 'string' and name:sub(1, 4) == 'job_' then
            jobTotal = jobTotal + 1
            if GetResourceState(name) == 'started' then jobOk = jobOk + 1 end
        end
    end
    local jobColor = (jobTotal > 0 and jobOk == jobTotal) and '^2' or '^3'
    local jobMark = (jobTotal > 0 and jobOk == jobTotal) and '[OK]' or '[WARN]'
    print(('%s%s JOBS   [%d/%d]^7'):format(jobColor, jobMark, jobOk, jobTotal))
    print('^5====================================^=7')
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    actionCooldowns[src] = nil
    local player = Players[src]
    if player then
        print(string.format('[rp_core] Player %s (%s) disconnected: %s',
            GetPlayerName(src) or tostring(src), player.identifier or 'unknown', reason or 'unknown'))
        local characterId = tonumber(player.charId)
        if characterId then
            pendingDisconnectSaves[characterId] = true
            pendingDisconnectPlayers[characterId] = player
            Players[src] = nil
            CreateThread(function()
                local attempts = 0
                while attempts < 5 do
                    attempts = attempts + 1
                    local ok, saved = pcall(player.save, true)
                    if ok and saved == true then
                        pendingDisconnectSaves[characterId] = nil
                        pendingDisconnectPlayers[characterId] = nil
                        print(('[rp_core] Final disconnect save completed for character %s.'):format(tostring(characterId)))
                        return
                    end
                    print(('[rp_core] Final save still pending for character %s (attempt %d); reconnect remains blocked.')
                        :format(tostring(characterId), attempts))
                    Wait(2000)
                end
                pendingDisconnectSaves[characterId] = nil
                pendingDisconnectPlayers[characterId] = nil
            end)
        else
            Players[src] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src, player in pairs(Players) do
        if player and player.save then
            local ok, saved = pcall(player.save, true)
            if not ok or saved ~= true then
                print(('[rp_core] Resource-stop save failed for character %s'):format(tostring(player.charId)))
            end
        end
    end
    for characterId, player in pairs(pendingDisconnectPlayers) do
        if player and player.save then
            local ok, saved = pcall(player.save, true)
            if not ok or saved ~= true then
                print(('[rp_core] Resource-stop final save failed for character %s'):format(tostring(characterId)))
            end
        end
    end
end)
