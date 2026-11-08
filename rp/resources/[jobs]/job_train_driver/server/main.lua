local dutyPlayers = {}

RegisterNetEvent('job_train_driver:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    dutyPlayers[src] = status
    TriggerClientEvent('job_train_driver:dutyUpdated', src, status)
    print(string.format('[JOB_TRAIN_DRIVER] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)
