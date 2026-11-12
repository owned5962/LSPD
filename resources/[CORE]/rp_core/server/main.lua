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

-- Re-send the authoritative character snapshot if rp_core was restarted client-side.
-- The client cannot provide or override the character data.
RegisterNetEvent('rp_core:server:requestPlayerDataSync', function()
    local src = source
    if not CanPerformAction(src, 'core:request_player_data_sync', 500) then return end
    local player = Players[tonumber(src)]
    if not player or not tonumber(player.charId) or type(player.syncClient) ~= 'function' then return end
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

        CreateThread(function()
            -- The FiveM source ID may be reused after disconnect; never read a new player's ped.
            -- Retry briefly when an autosave or another character save currently owns the lock.
            local saved = false
            for attempt = 1, 20 do
                local ok, result = pcall(player.save, true)
                if ok and result == true then
                    saved = true
                    break
                end
                Wait(500)
            end
            if not saved then
                print(('[rp_core] Final disconnect save failed for character %s after 20 attempts'):format(tostring(characterId)))
            end
            if saved and characterId then
                pendingDisconnectSaves[characterId] = nil
                pendingDisconnectPlayers[characterId] = nil
            elseif characterId then
                -- Keep reconnect blocked: loading stale SQL data is worse than requiring recovery.
                print(('[rp_core] Character %s remains locked until its final save can be recovered'):format(tostring(characterId)))
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
