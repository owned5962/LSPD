local function isAt(coords, src, maxDistance)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (maxDistance or 5.0)
end

RegisterNetEvent('job_diver:setDuty', function(status)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'job_diver:setDuty', 2000) then
        TriggerClientEvent('rp_core:client:notify', src, 'Patientez avant de changer votre état de service.', 'warning')
        TriggerClientEvent('job_diver:dutyUpdated', src, (exports['rp_core']:GetPlayerFromId(src) or {}).duty == true)
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or player.job ~= 'diver' or type(status) ~= 'boolean' or not isAt(Config.DutyCoords, src, 5.0) then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé ou état de service invalide.', 'error')
        return
    end

    if not exports['rp_core']:SetPlayerDuty(src, status, Config.Job) then
        TriggerClientEvent('rp_core:client:notify', src, 'Impossible de synchroniser votre état de service. Réessayez.', 'error')
        return
    end
    TriggerClientEvent('job_diver:dutyUpdated', src, status)
    print(string.format('[JOB_DIVER] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)


-- Duty state is owned by rp_core and is cleared with the player session.
