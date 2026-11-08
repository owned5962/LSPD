local dutyPlayers = {}

RegisterNetEvent('job_it_tech:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    dutyPlayers[src] = status
    TriggerClientEvent('job_it_tech:dutyUpdated', src, status)
    print(string.format('[JOB_IT_TECH] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)
