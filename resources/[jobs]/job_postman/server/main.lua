local dutyPlayers = {}

RegisterNetEvent('job_postman:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or player.job ~= 'postman' or type(status) ~= 'boolean' then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé ou état de service invalide.', 'error')
        return
    end

    dutyPlayers[src] = status
    TriggerClientEvent('job_postman:dutyUpdated', src, status)
    print(string.format('[JOB_POSTMAN] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)
