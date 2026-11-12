Players = {}

local actionCooldowns = {}
local pendingDisconnectSaves = {}
local pendingDisconnectPlayers = {}

local function CanPerformAction(src, action, cooldownMs)
    src = tonumber(src)
    if not src or src < 1 or type(action) ~= 'string' or action == '' then return false end
    local now = GetGameTimer()
    actionCooldowns[src] = actionCooldowns[src] or {}
    local nextAllowed = actionCooldowns[src][action] or 0
    if now < nextAllowed then return false end
    actionCooldowns[src][action] = now + math.max(0, tonumber(cooldownMs) or 1000)
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
    local timeout = math.max(0, math.min(15000, tonumber(timeoutMs) or 5000))
    local deadline = GetGameTimer() + timeout
    repeat
        local player = Players[src]
        if player and player.isLoaded == true and tonumber(player.charId) then
            return player
        end
        if not GetPlayerName(src) then return nil end
        Wait(100)
    until GetGameTimer() >= deadline
    return nil
end

exports('WaitForPlayerLoaded', WaitForPlayerLoaded)
exports('IsPlayerLoaded', function(source)
    local player = Players[tonumber(source)]
    return player ~= nil and player.isLoaded == true and tonumber(player.charId) ~= nil
end)

function GetPlayerByIdentifier(identifier)
    for _, player in pairs(Players) do
        if player.identifier == identifier then
            return player
        end
    end
    return nil
end

function GetAllPlayers()
    -- Return detached snapshots: readers in other resources must not be able
    -- to mutate the authoritative registry or nested character metadata.
    local snapshot = {}
    for source, player in pairs(Players) do
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
        snapshot[source] = copy
    end
    return snapshot
end

local function RegisterPlayer(source, player)
    local src = tonumber(source)
    if not src or src < 1 or not GetPlayerName(src) or type(player) ~= 'table'
        or tonumber(player.source) ~= src or type(player.identifier) ~= 'string'
        or player.identifier == '' or not tonumber(player.charId) or tonumber(player.charId) < 1 then
        return false
    end
    if Players[src] then return false end

    for activeSource, activePlayer in pairs(Players) do
        if activeSource ~= src and activePlayer.identifier == player.identifier then
            return false
        end
    end

    player.isLoaded = true
    player.name = tostring(player.firstname or '') .. ' ' .. tostring(player.lastname or '')
    Players[src] = player
    TriggerEvent('rp_core:server:playerLoaded', src, player)
    return true
end

exports('RegisterPlayer', RegisterPlayer)

local function UnregisterPlayer(source, expectedIdentifier)
    local src = tonumber(source)
    local player = src and Players[src]
    if not player then return false end
    if expectedIdentifier and player.identifier ~= expectedIdentifier then return false end
    Players[src] = nil
    TriggerEvent('rp_core:server:playerUnloaded', src, player)
    return true
end

exports('UnregisterPlayer', UnregisterPlayer)

-- Backward-compatible alias used by older resources.
exports('GetPlayer', GetPlayerFromId)
exports('GetPlayerFromId', GetPlayerFromId)
exports('GetPlayerByIdentifier', GetPlayerByIdentifier)
exports('GetAllPlayers', GetAllPlayers)

-- Re-send the authoritative character snapshot if rp_core was restarted client-side.
-- The client cannot provide or override the character data.
RegisterNetEvent('rp_core:server:requestPlayerDataSync', function()
    local src = source
    if not CanPerformAction(src, 'core:request_player_data_sync', 500) then return end
    local player = Players[tonumber(src)]
    if not player or not tonumber(player.charId) or type(player.syncClient) ~= 'function' then
        -- The server core may have restarted and lost its in-memory registry.
        -- Ask the character resource to rebuild the authoritative session from SQL.
        TriggerClientEvent('rp_core:client:requestCharacterBootstrap', src)
        return
    end
    player.syncClient()
end)

-- Save all connected characters regularly so economy/job changes survive crashes
-- more reliably than a disconnect-only save.
CreateThread(function()
    while true do
        Wait(60 * 1000)
        for _, player in pairs(Players) do
            if player and player.save then
                player.save()
            end
        end
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    actionCooldowns[src] = nil
    local player = Players[src]
    if player then
        print(string.format('[rp_core] Player %s (%s) disconnected: %s',
            GetPlayerName(src) or tostring(src), player.identifier or 'unknown', reason or 'unknown'))
        -- Block a fast reconnect from loading stale SQL data while this final save is pending.
        -- Character IDs are database-primary keys and remain stable across FiveM source reuse.
        local characterId = tonumber(player.charId)
        if characterId then
            pendingDisconnectSaves[characterId] = true
            pendingDisconnectPlayers[characterId] = player
        end
        Players[src] = nil
        TriggerEvent('rp_core:server:playerUnloaded', src, player)

        CreateThread(function()
            -- The FiveM source ID may be reused after disconnect; never read a new player's ped.
            -- Retry briefly when an autosave or another character save currently owns the lock.
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
                    -- Keep retrying after transient SQL outages. Never unlock a
                    -- character while its last in-memory state has not been saved.
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


-- Best-effort flush when rp_core itself is stopped or restarted.
-- player.save() uses oxmysql await and returns false on SQL/lock failures.
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
