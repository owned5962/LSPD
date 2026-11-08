local dutyPlayers = {}

RegisterNetEvent('job_dock_worker:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or player.job ~= 'dock_worker' or type(status) ~= 'boolean' then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé ou état de service invalide.', 'error')
        return
    end

    dutyPlayers[src] = status
    TriggerClientEvent('job_dock_worker:dutyUpdated', src, status)
    print(string.format('[JOB_DOCK_WORKER] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)
