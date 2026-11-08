RegisterCommand('pay', function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if not targetId or not amount or amount <= 0 then
        TriggerClientEvent('rp_core:client:notify', src, 'Utilisation: /pay [ID] [Montant]', 'error')
        return
    end

    local sender = exports['rp_core']:GetPlayerFromId(src)
    local receiver = exports['rp_core']:GetPlayerFromId(targetId)

    if not sender or not receiver then
        TriggerClientEvent('rp_core:client:notify', src, 'Joueur introuvable.', 'error')
        return
    end

    if sender.removeCash(amount) then
        receiver.addCash(amount)
        TriggerClientEvent('rp_core:client:notify', src, 'Vous avez donné ' .. Utils.FormatCurrency(amount) .. ' à ' .. receiver.firstname .. ' ' .. receiver.lastname, 'success')
        TriggerClientEvent('rp_core:client:notify', targetId, 'Vous avez reçu ' .. Utils.FormatCurrency(amount) .. ' de ' .. sender.firstname .. ' ' .. sender.lastname, 'info')
    else
        TriggerClientEvent('rp_core:client:notify', src, 'Fonds insuffisants en espèces.', 'error')
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
