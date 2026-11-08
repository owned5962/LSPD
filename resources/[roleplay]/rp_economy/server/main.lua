local MAX_TRANSACTION = 1000000

local function validAmount(value)
    local amount = tonumber(value)
    if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > MAX_TRANSACTION then
        return nil
    end
    return amount
end

local function formatCurrency(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1 %2')
        if k == 0 then break end
    end
    return formatted .. ' $'
end

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

RegisterNetEvent('rp_economy:server:logTransaction', function(characterId, transactionType, amount, sender, reason)
    local validTypes = {
        deposit = true, withdraw = true, transfer_send = true,
        transfer_receive = true, salary = true
    }
    characterId = tonumber(characterId)
    amount = validAmount(amount)
    if not characterId or not validTypes[transactionType] or not amount then return end

    MySQL.insert('INSERT INTO bank_transactions (character_id, type, amount, sender_or_receiver, reason) VALUES (?, ?, ?, ?, ?)', {
        characterId, transactionType, amount,
        tostring(sender or 'Système'):sub(1, 128),
        tostring(reason or 'Transaction'):sub(1, 255)
    })
end)

RegisterNetEvent('rp_economy:server:deposit', function(rawAmount)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    local amount = validAmount(rawAmount)
    if not player or not amount then return end

    if player.removeCash(amount) then
        player.addBank(amount, 'Dépôt bancaire')
        TriggerClientEvent('rp_economy:client:refreshBalances', src, player.getCash(), player.getBank())
        notify(src, 'Dépôt réussi : ' .. formatCurrency(amount), 'success')
    else
        notify(src, 'Fonds insuffisants en espèces.', 'error')
    end
end)

RegisterNetEvent('rp_economy:server:withdraw', function(rawAmount)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    local amount = validAmount(rawAmount)
    if not player or not amount then return end

    if player.removeBank(amount, 'Retrait DAB / Guichet') then
        player.addCash(amount)
        TriggerClientEvent('rp_economy:client:refreshBalances', src, player.getCash(), player.getBank())
        notify(src, 'Retrait réussi : ' .. formatCurrency(amount), 'success')
    else
        notify(src, 'Solde bancaire insuffisant.', 'error')
    end
end)

RegisterNetEvent('rp_economy:server:transfer', function(rawTargetId, rawAmount)
    local src = source
    local targetId = tonumber(rawTargetId)
    local amount = validAmount(rawAmount)
    local player = exports['rp_core']:GetPlayerFromId(src)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)

    if not player or not target or targetId == src or not amount then
        notify(src, 'Virement invalide ou joueur introuvable.', 'error')
        return
    end

    if player.removeBank(amount, 'Virement vers ' .. target.firstname .. ' ' .. target.lastname) then
        target.addBank(amount, 'Virement reçu de ' .. player.firstname .. ' ' .. player.lastname)
        TriggerClientEvent('rp_economy:client:refreshBalances', src, player.getCash(), player.getBank())
        TriggerClientEvent('rp_economy:client:refreshBalances', targetId, target.getCash(), target.getBank())
        notify(src, 'Virement de ' .. formatCurrency(amount) .. ' effectué.', 'success')
        notify(targetId, 'Virement de ' .. formatCurrency(amount) .. ' reçu.', 'info')
    else
        notify(src, 'Solde insuffisant pour ce virement.', 'error')
    end
end)

CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        local allPlayers = exports['rp_core']:GetAllPlayers()
        for src, player in pairs(allPlayers) do
            local gradeData = exports['rp_jobs']:GetJobGrade(player.job, player.jobGrade)
            local salary = validAmount(gradeData and gradeData.salary or 150)
            if salary and player.addBank(salary, 'Salaire - ' .. (player.job or 'Civil')) then
                notify(src, 'Salaire reçu : ' .. formatCurrency(salary) .. ' sur votre compte bancaire.', 'success')
            end
        end
    end
end)
