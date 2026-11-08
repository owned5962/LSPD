local dutyPlayers = {}

RegisterNetEvent('job_fitness_coach:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or player.job ~= 'fitness_coach' or type(status) ~= 'boolean' then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé ou état de service invalide.', 'error')
        return
    end

    dutyPlayers[src] = status
    TriggerClientEvent('job_fitness_coach:dutyUpdated', src, status)
    print(string.format('[JOB_FITNESS_COACH] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)
