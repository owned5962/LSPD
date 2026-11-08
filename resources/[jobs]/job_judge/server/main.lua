local dutyPlayers = {}

RegisterNetEvent('job_judge:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or player.job ~= 'judge' or type(status) ~= 'boolean' then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé ou état de service invalide.', 'error')
        return
    end

    dutyPlayers[src] = status
    TriggerClientEvent('job_judge:dutyUpdated', src, status)
    print(string.format('[JOB_JUDGE] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)
