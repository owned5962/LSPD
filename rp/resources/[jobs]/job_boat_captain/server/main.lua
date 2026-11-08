local dutyPlayers = {}

RegisterNetEvent('job_boat_captain:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    dutyPlayers[src] = status
    TriggerClientEvent('job_boat_captain:dutyUpdated', src, status)
    print(string.format('[JOB_BOAT_CAPTAIN] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)
