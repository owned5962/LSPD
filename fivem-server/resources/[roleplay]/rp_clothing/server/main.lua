RegisterNetEvent('rp_clothing:saveOutfit', function(name, skinData)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    if player.cash >= 150 then
        player.cash = player.cash - 150
        TriggerClientEvent('rp_core:notify', src, 'success', 'Tenue enregistrée ! (-150 $)')
    else
        TriggerClientEvent('rp_core:notify', src, 'error', 'Fonds insuffisants en liquide (150 $ requis)')
    end
end)
