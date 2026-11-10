RegisterCommand('pay', function(source, args)
    local src = source
    if src <= 0 then return end
    if not exports['rp_core']:CanPerformAction(src, 'pay', 1500) then
        TriggerClientEvent('rp_core:client:notify', src, 'Veuillez patienter avant un nouveau virement.', 'warning')
        return
    end

    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if not targetId or targetId % 1 ~= 0 or not amount or amount % 1 ~= 0 or amount < 1 or amount > 1000000 then
        TriggerClientEvent('rp_core:client:notify', src, 'Utilisation : /pay [ID] [Montant entier, max. 1 000 000]', 'error')
        return
    end
    if not exports['rp_core']:GetPlayerFromId(targetId) then
        TriggerClientEvent('rp_core:client:notify', src, 'Joueur introuvable.', 'error')
        return
    end

    if not exports['rp_core']:TransferCash(src, targetId, amount) then
        TriggerClientEvent('rp_core:client:notify', src, 'Virement impossible : fonds insuffisants ou sauvegarde refusée.', 'error')
    end
end, false)

RegisterCommand('id', function(source)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if player then
        TriggerClientEvent('rp_core:client:notify', src, string.format('ID: %s | Nom: %s %s | Métier: %s', src, player.firstname, player.lastname, player.job), 'info')
    else
        TriggerClientEvent('rp_core:client:notify', src, 'ID Serveur: ' .. src, 'info')
    end
end, false)
