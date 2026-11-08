RegisterNetEvent('rp_economy:server:deposit', function(amount)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or not amount or amount <= 0 then return end

    if player.removeCash(amount) then
        player.addBank(amount, 'Dépôt Bancaire')
        TriggerClientEvent('rp_economy:client:refreshBalances', src, player.getCash(), player.getBank())
        TriggerClientEvent('rp_core:client:notify', src, 'Dépôt réussi: ' .. Utils.FormatCurrency(amount), 'success')
    else
        TriggerClientEvent('rp_core:client:notify', src, 'Fonds insuffisants en espèces.', 'error')
    end
end)

RegisterNetEvent('rp_economy:server:withdraw', function(amount)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or not amount or amount <= 0 then return end

    if player.removeBank(amount, 'Retrait DAB / Guichet') then
        player.addCash(amount)
        TriggerClientEvent('rp_economy:client:refreshBalances', src, player.getCash(), player.getBank())
        TriggerClientEvent('rp_core:client:notify', src, 'Retrait réussi: ' .. Utils.FormatCurrency(amount), 'success')
    else
        TriggerClientEvent('rp_core:client:notify', src, 'Solde bancaire insuffisant.', 'error')
    end
end)

RegisterNetEvent('rp_economy:server:transfer', function(targetId, amount)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    local target = exports['rp_core']:GetPlayerFromId(targetId)

    if not player or not target or not amount or amount <= 0 then
        TriggerClientEvent('rp_core:client:notify', src, 'Virement invalide ou joueur introuvable.', 'error')
        return
    end

    if player.removeBank(amount, 'Virement vers ' .. target.firstname .. ' ' .. target.lastname) then
        target.addBank(amount, 'Virement reçu de ' .. player.firstname .. ' ' .. player.lastname)
        TriggerClientEvent('rp_economy:client:refreshBalances', src, player.getCash(), player.getBank())
        TriggerClientEvent('rp_economy:client:refreshBalances', targetId, target.getCash(), target.getBank())
        TriggerClientEvent('rp_core:client:notify', src, 'Virement de ' .. Utils.FormatCurrency(amount) .. ' effectué.', 'success')
        TriggerClientEvent('rp_core:client:notify', targetId, 'Virement de ' .. Utils.FormatCurrency(amount) .. ' reçu.', 'info')
    else
        TriggerClientEvent('rp_core:client:notify', src, 'Solde insuffisant pour ce virement.', 'error')
    end
end)

-- Automated Salaries Loop
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000) -- every 10 mins
        local allPlayers = exports['rp_core']:GetAllPlayers()
        for src, player in pairs(allPlayers) do
            local gradeData = exports['rp_jobs']:GetJobGrade(player.job, player.jobGrade)
            local salary = gradeData and gradeData.salary or 150
            player.addBank(salary, 'Salaire - ' .. (player.job or 'Civil'))
            TriggerClientEvent('rp_core:client:notify', src, 'Salaire reçu: ' .. Utils.FormatCurrency(salary) .. ' sur votre compte bancaire.', 'success')
        end
    end
end)
