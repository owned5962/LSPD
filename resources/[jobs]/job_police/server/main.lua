local dutyPlayers = {}

RegisterNetEvent('job_police:setDuty', function(status)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    dutyPlayers[src] = status
    TriggerClientEvent('job_police:dutyUpdated', src, status)
    print(string.format('[LSPD] Officier %s est désormais %s service', player.name or src, status and 'EN' or 'HORS'))
end)

RegisterNetEvent('job_police:getArmoryWeapons', function()
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player or player.job ~= 'police' then
        TriggerClientEvent('rp_core:notify', src, 'error', 'Accès armurerie réservé aux agents assermentés LSPD.')
        return
    end

    local ped = GetPlayerPed(src)
    for _, item in ipairs(Config.Weapons) do
        GiveWeaponToPed(ped, GetHashKey(item.weapon), 250, false, false)
    end
    TriggerClientEvent('rp_core:notify', src, 'success', 'Dotation d\'armement LSPD distribuée avec succès.')
end)
