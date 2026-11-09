local dutyPlayers = {}

local function isAt(coords, src, maxDistance)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (maxDistance or 5.0)
end

RegisterNetEvent('job_photographer:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or player.job ~= 'photographer' or type(status) ~= 'boolean' or not isAt(Config.DutyCoords, src, 5.0) then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé ou état de service invalide.', 'error')
        return
    end

    dutyPlayers[src] = status
    TriggerClientEvent('job_photographer:dutyUpdated', src, status)
    print(string.format('[JOB_PHOTOGRAPHER] Player %s is now %s duty', player.name or src, status and 'ON' or 'OFF'))
end)


AddEventHandler('playerDropped', function()
    dutyPlayers[source] = nil
end)
