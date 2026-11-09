local dutyPlayers = {}

local function isAt(coords, src, maxDistance)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (maxDistance or 4.0)
end

RegisterNetEvent('job_police:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or player.job ~= 'police' or type(status) ~= 'boolean' or not isAt(Config.DutyCoords, src, 5.0) then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé ou état de service invalide.', 'error')
        return
    end

    dutyPlayers[src] = status
    TriggerClientEvent('job_police:dutyUpdated', src, status)
    print(string.format('[LSPD] Officier %s est désormais %s service', player.name or src, status and 'EN' or 'HORS'))
end)

RegisterNetEvent('job_police:getArmoryWeapons', function()
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player or player.job ~= 'police' or not dutyPlayers[src] or not isAt(Config.ArmoryCoords, src, 4.0) then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès armurerie réservé aux agents en service présents à l’armurerie.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    for _, item in ipairs(Config.Weapons) do
        GiveWeaponToPed(ped, GetHashKey(item.weapon), 250, false, false)
    end
    TriggerClientEvent('rp_core:client:notify', src, 'Dotation d\'armement LSPD distribuée avec succès.', 'success')
end)


exports('IsOnDuty', function(src)
    return dutyPlayers[tonumber(src)] == true
end)


AddEventHandler('playerDropped', function()
    dutyPlayers[source] = nil
end)
