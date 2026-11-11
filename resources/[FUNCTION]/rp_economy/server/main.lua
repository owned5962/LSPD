local MAX_TRANSACTION = 1000000

local BANK_POSITIONS = {
    vector3(149.9, -1040.5, 29.3), vector3(-1212.9, -330.8, 37.7),
    vector3(-2962.6, 482.1, 15.7), vector3(1175.0, 2706.8, 38.0),
    vector3(236.4, 217.4, 106.2)
}
-- GTA map ATMs are usually static map entities, not networked entities.
-- GetAllObjects() on the server therefore cannot reliably enumerate them.
-- Validate against the same fixed ATM locations used by the map blips instead.
local ATM_POSITIONS = {
    vector3(89.6, 2.2, 68.3), vector3(1167.0, -456.1, 66.8),
    vector3(-386.7, 6045.9, 31.5), vector3(-821.6, -1081.9, 11.1),
    vector3(-56.9, -1752.1, 29.4), vector3(155.9, 6642.9, 31.6),
    vector3(174.2, 6637.9, 31.6), vector3(296.4, -894.1, 29.2),
    vector3(-203.8, -861.4, 30.3), vector3(-254.4, -692.5, 33.6),
    vector3(-1570.1, -546.7, 34.9), vector3(-1415.9, -211.8, 46.5),
    vector3(-1205.0, -324.8, 37.9), vector3(-717.6, -915.7, 19.2),
    vector3(-526.6, -1222.9, 18.5), vector3(-1315.4, -834.4, 16.9),
    vector3(112.5, -819.4, 31.3), vector3(285.4, 143.4, 104.2),
    vector3(-256.2, -716.0, 33.5), vector3(-660.7, -854.1, 24.5),
    vector3(-1109.8, -1690.8, 4.4), vector3(1686.8, 4815.8, 42.0),
    vector3(1703.0, 4933.6, 42.1), vector3(1968.1, 3743.6, 32.3),
    vector3(540.3, 2671.1, 42.2), vector3(2564.5, 2584.8, 38.1),
    vector3(2683.0, 3286.5, 55.2)
}

local function IsNearBankOrATM(src, allowATM)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local coords = GetEntityCoords(ped)
    for _, bankCoords in ipairs(BANK_POSITIONS) do
        if #(coords - bankCoords) <= 6.0 then return true end
    end
    if allowATM then
        for _, atmCoords in ipairs(ATM_POSITIONS) do
            if #(coords - atmCoords) <= 4.0 then return true end
        end
    end
    return false
end

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

AddEventHandler('rp_economy:server:logTransaction', function(characterId, transactionType, amount, sender, reason)
    local validTypes = {
        deposit = true, withdraw = true, transfer_send = true, fuel_refund = true,
        transfer_receive = true, salary = true, fuel = true
    }
    characterId = tonumber(characterId)
    amount = validAmount(amount)
    if not characterId or characterId % 1 ~= 0 or not validTypes[transactionType] or not amount then return end

    local ok, err = pcall(MySQL.insert.await,
        'INSERT INTO bank_transactions (character_id, type, amount, sender_or_receiver, reason) VALUES (?, ?, ?, ?, ?)',
        {
            characterId, transactionType, amount,
            tostring(sender or 'Système'):sub(1, 128),
            tostring(reason or 'Transaction'):sub(1, 255)
        }
    )
    if not ok then
        print(('[rp_economy] Transaction log failed for character %s: %s'):format(characterId, tostring(err)))
    end
end)

RegisterNetEvent('rp_economy:server:deposit', function(rawAmount)
    local src = source
    if not IsNearBankOrATM(src, true) then notify(src, 'Rendez-vous devant une banque ou un distributeur pour déposer.', 'error'); return end
    if not exports['rp_core']:CanPerformAction(src, 'economy:deposit', 1500) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local amount = validAmount(rawAmount)
    if not player or not amount then return end

    local lockedIds = { player.charId }
    if not exports['rp_core']:AcquireCharacterLock(lockedIds) then
        notify(src, 'Une opération sur votre compte est en cours. Réessayez.', 'warning')
        return
    end
    local ok, affected = pcall(MySQL.update.await,
        'UPDATE characters SET cash = cash - ?, bank = bank + ? WHERE id = ? AND identifier = ? AND cash >= ?',
        { amount, amount, player.charId, player.identifier, amount }
    )
    -- Keep the core save lock until the in-memory balances match SQL. Otherwise
    -- an autosave can run in the gap and overwrite the successful transaction
    -- with the old cash/bank values.
    if ok and tonumber(affected) == 1 then
        player.cash, player.bank = player.cash - amount, player.bank + amount
    end
    exports['rp_core']:ReleaseCharacterLock(lockedIds)
    if not ok then
        print(('[rp_economy] Deposit SQL error for character %s: %s'):format(player.charId, tostring(affected)))
        notify(src, 'Dépôt impossible : erreur de base de données.', 'error')
        return
    end
    if tonumber(affected) ~= 1 then
        notify(src, 'Dépôt impossible : espèces insuffisantes ou compte introuvable.', 'error')
        return
    end
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'deposit', amount, 'Système', 'Dépôt bancaire')
    TriggerClientEvent('rp_core:client:updateCash', src, player.cash)
    TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
    TriggerClientEvent('rp_economy:client:refreshBalances', src, player.cash, player.bank)
    notify(src, 'Dépôt réussi : ' .. formatCurrency(amount), 'success')
end)

RegisterNetEvent('rp_economy:server:withdraw', function(rawAmount)
    local src = source
    if not IsNearBankOrATM(src, true) then notify(src, 'Rendez-vous devant une banque ou un distributeur pour retirer.', 'error'); return end
    if not exports['rp_core']:CanPerformAction(src, 'economy:withdraw', 1500) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local amount = validAmount(rawAmount)
    if not player or not amount then return end

    local lockedIds = { player.charId }
    if not exports['rp_core']:AcquireCharacterLock(lockedIds) then
        notify(src, 'Une opération sur votre compte est en cours. Réessayez.', 'warning')
        return
    end
    local ok, affected = pcall(MySQL.update.await,
        'UPDATE characters SET bank = bank - ?, cash = cash + ? WHERE id = ? AND identifier = ? AND bank >= ?',
        { amount, amount, player.charId, player.identifier, amount }
    )
    -- Update the live character before releasing its lock so rp_core cannot
    -- persist stale balances over the withdrawal.
    if ok and tonumber(affected) == 1 then
        player.bank, player.cash = player.bank - amount, player.cash + amount
    end
    exports['rp_core']:ReleaseCharacterLock(lockedIds)
    if not ok then
        print(('[rp_economy] Withdrawal SQL error for character %s: %s'):format(player.charId, tostring(affected)))
        notify(src, 'Retrait impossible : erreur de base de données.', 'error')
        return
    end
    if tonumber(affected) ~= 1 then
        notify(src, 'Retrait impossible : solde bancaire insuffisant ou compte introuvable.', 'error')
        return
    end
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'withdraw', amount, 'Système', 'Retrait DAB / Guichet')
    TriggerClientEvent('rp_core:client:updateCash', src, player.cash)
    TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
    TriggerClientEvent('rp_economy:client:refreshBalances', src, player.cash, player.bank)
    notify(src, 'Retrait réussi : ' .. formatCurrency(amount), 'success')
end)

RegisterNetEvent('rp_economy:server:transfer', function(rawTargetId, rawAmount)
    local src = source
    if not IsNearBankOrATM(src, false) then notify(src, 'Les virements sont disponibles uniquement au guichet d’une banque.', 'error'); return end
    if not exports['rp_core']:CanPerformAction(src, 'economy:transfer', 2000) then return end
    local targetId = tonumber(rawTargetId)
    local amount = validAmount(rawAmount)
    local player = exports['rp_core']:GetPlayerFromId(src)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId)

    if not player or not target or targetId == src or not amount then
        notify(src, 'Virement invalide ou joueur introuvable.', 'error')
        return
    end

    local lockedIds = { player.charId, target.charId }
    if not exports['rp_core']:AcquireCharacterLock(lockedIds) then
        notify(src, 'Une opération sur un des comptes est en cours. Réessayez.', 'warning')
        return
    end
    local ok, affected = pcall(MySQL.update.await,
        'UPDATE characters AS sender JOIN characters AS recipient ON sender.id = ? AND recipient.id = ? SET sender.bank = sender.bank - ?, recipient.bank = recipient.bank + ? WHERE sender.identifier = ? AND recipient.identifier = ? AND sender.bank >= ?',
        { player.charId, target.charId, amount, amount, player.identifier, target.identifier, amount }
    )
    exports['rp_core']:ReleaseCharacterLock(lockedIds)
    if not ok or tonumber(affected) ~= 2 then
        notify(src, 'Virement impossible : solde modifié ou base indisponible.', 'error')
        return
    end
    player.bank, target.bank = player.bank - amount, target.bank + amount
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'transfer_send', amount, target.firstname .. ' ' .. target.lastname, 'Virement envoyé')
    TriggerEvent('rp_economy:server:logTransaction', target.charId, 'transfer_receive', amount, player.firstname .. ' ' .. player.lastname, 'Virement reçu')
    TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
    TriggerClientEvent('rp_core:client:updateBank', targetId, target.bank)
    TriggerClientEvent('rp_economy:client:refreshBalances', src, player.cash, player.bank)
    TriggerClientEvent('rp_economy:client:refreshBalances', targetId, target.cash, target.bank)
    notify(src, 'Virement de ' .. formatCurrency(amount) .. ' effectué.', 'success')
    notify(targetId, 'Virement de ' .. formatCurrency(amount) .. ' reçu.', 'info')
end)

CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        local allPlayers = exports['rp_core']:GetAllPlayers()
        for src, player in pairs(allPlayers) do
            local gradeData = exports['rp_jobs']:GetJobGrade(player.job, player.jobGrade)
            local salary = validAmount(gradeData and gradeData.salary or 150)
            if salary and player.addBank(salary, 'Salaire - ' .. (player.job or 'Civil'), 'salary') then
                notify(src, 'Salaire reçu : ' .. formatCurrency(salary) .. ' sur votre compte bancaire.', 'success')
            end
        end
    end
end)
