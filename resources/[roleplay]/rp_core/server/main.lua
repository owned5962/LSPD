Players = {}

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
    local player = Players[src]
    if player then
        print(string.format('[rp_core] Player %s (%s) disconnected: %s',
            GetPlayerName(src) or tostring(src), player.identifier or 'unknown', reason or 'unknown'))
        -- Keep the player object alive in this closure while the SQL save completes.
        CreateThread(function()
            player.save()
        end)
        Players[src] = nil
    end
end)
