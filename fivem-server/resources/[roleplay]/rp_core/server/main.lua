Players = {}

function GetPlayerFromId(source)
    return Players[tonumber(source)]
end

function GetPlayerByIdentifier(identifier)
    for _, p in pairs(Players) do
        if p.identifier == identifier then
            return p
        end
    end
    return nil
end

function GetAllPlayers()
    return Players
end

exports('GetPlayerFromId', GetPlayerFromId)
exports('GetPlayerByIdentifier', GetPlayerByIdentifier)
exports('GetAllPlayers', GetAllPlayers)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if Players[src] then
        print(string.format('[rp_core] Player %s (%s) disconnected: %s', GetPlayerName(src), Players[src].identifier or 'unknown', reason))
        Players[src] = nil
    end
end)
