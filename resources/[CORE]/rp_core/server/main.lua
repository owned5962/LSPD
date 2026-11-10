Players = {}

local actionCooldowns = {}
local pendingDisconnectSaves = {}

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
        if characterId then pendingDisconnectSaves[characterId] = true end
        Players[src] = nil

        CreateThread(function()
            -- The FiveM source ID may be reused after disconnect; never read a new player's ped.
            -- Retry briefly when an autosave or another character save currently owns the lock.
            local saved = false
            for attempt = 1, 5 do
                local ok, result = pcall(player.save, true)
                if ok and result == true then
                    saved = true
                    break
                end
                Wait(250)
            end
            if not saved then
                print(('[rp_core] Final disconnect save failed for character %s after 5 attempts'):format(tostring(characterId)))
            end
            if characterId then pendingDisconnectSaves[characterId] = nil end
        end)
    end
end)
