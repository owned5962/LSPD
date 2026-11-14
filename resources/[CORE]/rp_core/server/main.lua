Players = {}

local pendingDisconnectSaves = {}
local pendingDisconnectPlayers = {}

local TIMER_MODULUS = 4294967296

-- Rate limiting lives in server/rate_limit.lua (loaded first).
-- Keep a local alias so existing main.lua call sites stay readable.
local function CanPerformAction(src, action, cooldownMs, opts)
    return exports['rp_core']:CanPerformAction(src, action, cooldownMs, opts)
end

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
    local timeout = math.max(0, math.min(15000, tonumber(timeoutMs) or 5000))
    local startedAt = GetGameTimer() % TIMER_MODULUS
    repeat
        local player = Players[src]
        if player and player.isLoaded == true and tonumber(player.charId) then
            return player
        end
        if not GetPlayerName(src) then return nil end
        Wait(100)
    until ((GetGameTimer() % TIMER_MODULUS) - startedAt) % TIMER_MODULUS >= timeout
    return nil
end

exports('WaitForPlayerLoaded', WaitForPlayerLoaded)
exports('IsPlayerLoaded', function(source)
    local player = Players[tonumber(source)]
    return player ~= nil and player.isLoaded == true and tonumber(player.charId) ~= nil
end)

local function SetPlayerDuty(source, status, expectedJob)
    local src = tonumber(source)
    local player = src and Players[src]
    if not player or player.isLoaded ~= true or type(status) ~= 'boolean'
        or type(expectedJob) ~= 'string' or player.job ~= expectedJob then
        return false
    end

    player.duty = status
    TriggerClientEvent('rp_core:client:setDuty', src, status, expectedJob)
    TriggerEvent('rp_core:server:dutyChanged', src, status, expectedJob)
    return true
end

exports('SetPlayerDuty', SetPlayerDuty)

local function ClonePlayerRecord(player)
    if type(player) ~= 'table' then return nil end
    local copy = {}
    for key, value in pairs(player) do
        if type(value) ~= 'function' then
            if type(value) == 'table' then
                local ok, cloned = pcall(function()
                    return json.decode(json.encode(value))
                end)
                copy[key] = ok and type(cloned) == 'table' and cloned or {}
            else
                copy[key] = value
            end
        end
    end
    return copy
end

function GetPlayerByIdentifier(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    for _, player in pairs(Players) do
        if player.identifier == identifier and player.isLoaded == true then
            return {
                source = player.source,
                identifier = player.identifier,
                charId = player.charId,
                slot = player.slot,
                isLoaded = true
            }
        end
    end
    return nil
end

function GetAllPlayers()
    local snapshot = {}
    for source, player in pairs(Players) do
        snapshot[source] = ClonePlayerRecord(player)
    end
    return snapshot
end

local function GetPlayerSnapshot(source)
    local player = Players[tonumber(source)]
    if not player or player.isLoaded ~= true then return nil end
    return ClonePlayerRecord(player)
end

exports('GetPlayerSnapshot', GetPlayerSnapshot)

local function RegisterPlayer(source, player)
    local src = tonumber(source)
    local characterId = type(player) == 'table' and tonumber(player.charId) or nil
    local slot = type(player) == 'table' and tonumber(player.slot) or nil
    local identifier = type(player) == 'table' and player.identifier or nil
    local validIdentifier = type(identifier) == 'string'
        and identifier:match('^license:[%w_%-]+$') ~= nil
        and #identifier >= 10 and #identifier <= 80

    if not src or src < 1 or src % 1 ~= 0 or not GetPlayerName(src) or type(player) ~= 'table'
        or tonumber(player.source) ~= src or not validIdentifier
        or not characterId or characterId < 1 or characterId % 1 ~= 0
        or not slot or slot < 1 or slot > 3 or slot % 1 ~= 0
        or player.isLoaded ~= true then
        return false
    end

    if pendingDisconnectSaves[characterId] == true then
        return false
    end

    for otherSrc, other in pairs(Players) do
        if other and otherSrc ~= src and other.identifier == identifier then
            return false
        end
    end

    Players[src] = player
    TriggerEvent('rp_core:server:playerLoaded', src, ClonePlayerRecord(player))
    return true
end

exports('RegisterPlayer', RegisterPlayer)

local function UnregisterPlayer(source, identifier)
    local src = tonumber(source)
    local player = src and Players[src]
    if not player then return false end
    if identifier and player.identifier ~= identifier then return false end
    Players[src] = nil
    TriggerEvent('rp_core:server:playerUnloaded', src, ClonePlayerRecord(player))
    return true
end

exports('UnregisterPlayer', UnregisterPlayer)
exports('GetPlayer', GetPlayerFromId)
exports('GetPlayerFromId', GetPlayerFromId)
exports('GetPlayerByIdentifier', GetPlayerByIdentifier)
exports('GetAllPlayers', GetAllPlayers)

RegisterNetEvent('rp_core:server:requestPlayerDataSync', function()
    local src = source
    if not CanPerformAction(src, 'core:request_player_data_sync', 750) then
        return
    end
    local player = Players[tonumber(src)]
    if player and tonumber(player.charId) and type(player.syncClient) == 'function' then
        player.syncClient()
        return
    end
    print(('[rp_core] No active character session for %s — requesting character bootstrap.')
        :format(tostring(src)))
    TriggerClientEvent('rp_core:client:requestCharacterBootstrap', src)
    if GetResourceState('rp_characters') == 'started' then
        TriggerEvent('rp_characters:server:forceBootstrap', src)
    end
end)

-- Sequential autosave (no parallel workers): avoids saveLocks races.
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
                if not ok or saved ~= true then
                    Wait(150)
                    ok, saved = pcall(player.save)
                end
                if ok and saved == true then
                    okCount = okCount + 1
                    lastFailureLog[player.charId] = nil
                else
                    failCount = failCount + 1
                    local now = GetGameTimer()
                    local last = lastFailureLog[player.charId] or 0
                    if (now - last) > 300000 then
                        lastFailureLog[player.charId] = now
                        print(('[rp_core] Autosave deferred for character %s (%s)')
                            :format(tostring(player.charId), ok and 'lock/SQL busy' or tostring(saved)))
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

-- Compact categorized boot status.
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
            if GetResourceState(res) == 'started' then ok = ok + 1
            else missing[#missing + 1] = res .. '(' .. tostring(GetResourceState(res)) .. ')' end
        end
        local color = (ok == total) and '^2' or '^3'
        local mark = (ok == total) and '[OK]' or '[WARN]'
        local extra = (#missing > 0) and (' ' .. table.concat(missing, ', ')) or ''
        print(('%s%s %-6s [%d/%d]%s^7'):format(color, mark, group.name, ok, total, extra))
    end
    local jobOk, jobTotal = 0, 0
    for i = 0, GetNumResources() - 1 do
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
    pcall(function() exports['rp_core']:ClearPlayerRateLimits(src) end)
    local player = Players[src]
    if player then
        print(string.format('[rp_core] Player %s (%s) disconnected: %s',
            GetPlayerName(src) or tostring(src), player.identifier or 'unknown', reason or 'unknown'))
        local characterId = tonumber(player.charId)
        if characterId then
            pendingDisconnectSaves[characterId] = true
            pendingDisconnectPlayers[characterId] = player
        end
        Players[src] = nil
        TriggerEvent('rp_core:server:playerUnloaded', src, ClonePlayerRecord(player))
        CreateThread(function()
            local saved, attempt = false, 0
            while not saved and characterId do
                attempt = attempt + 1
                local ok, result = pcall(player.save, true)
                saved = ok and result == true
                if not saved then
                    if attempt == 1 or attempt % 6 == 0 then
                        print(('[rp_core] Final save still pending for character %s (attempt %d); reconnect remains blocked.')
                            :format(tostring(characterId), attempt))
                    end
                    Wait(math.min(30000, 1000 * attempt))
                end
            end
            if saved and characterId then
                pendingDisconnectSaves[characterId] = nil
                pendingDisconnectPlayers[characterId] = nil
                print(('[rp_core] Final disconnect save completed for character %s.'):format(tostring(characterId)))
            end
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, player in pairs(Players) do
        if player and player.save then
            local ok, saved = pcall(player.save)
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

CreateThread(function()
    Wait(500)
    print('^2[rp_core] [OK] Exports ready: CanPerformAction (rate-limit), GetPlayerFromId, RegisterPlayer, CreateRPPlayer^7')
end)
