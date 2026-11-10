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
    return Players[tonumber(source)]
end

function GetPlayerByIdentifier(identifier)
    for _, player in pairs(Players) do
        if player.identifier == identifier then
            return player
        end
    end
    return nil
end

function GetAllPlayers()
    return Players
end

-- Backward-compatible alias used by older resources.
exports('GetPlayer', GetPlayerFromId)
exports('GetPlayerFromId', GetPlayerFromId)
exports('GetPlayerByIdentifier', GetPlayerByIdentifier)
exports('GetAllPlayers', GetAllPlayers)

-- Save all connected characters regularly so economy/job changes survive crashes
-- more reliably than a disconnect-only save.
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)
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

        CreateThread(function()
            -- The FiveM source ID may be reused after disconnect; never read a new player's ped.
            -- Keep retrying with bounded backoff: a fixed retry count could leave a character
            -- permanently locked while the server is still running and the database recovers.
            local attempt = 0
            while true do
                attempt = attempt + 1
                local ok, result = pcall(player.save, true)
                if ok and result == true then
                    if characterId then
                        pendingDisconnectSaves[characterId] = nil
                        pendingDisconnectPlayers[characterId] = nil
                    end
                    print(('[rp_core] Final disconnect save completed for character %s after %s attempt(s)'):format(tostring(characterId), attempt))
                    break
                end

                if attempt == 1 or attempt % 20 == 0 then
                    print(('[rp_core] Final disconnect save still pending for character %s (attempt %s): %s'):format(
                        tostring(characterId), attempt, tostring(result)))
                end

                local backoff = math.min(30000, 500 * (2 ^ math.min(attempt - 1, 6)))
                Wait(backoff)
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
