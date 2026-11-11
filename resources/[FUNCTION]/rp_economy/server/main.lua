local MAX_TRANSACTION = 1000000
local AUTH_TTL = 120000
local authenticatedSessions = {}


local function getLocationsByType(locationType)
    local ok, rows = pcall(function()
        return exports['rp_businesses']:GetLocationsByType(locationType)
    end)
    return ok and type(rows) == 'table' and rows or {}
end

local function IsNearBankOrATM(src, allowATM)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local coords = GetEntityCoords(ped)
    for _, location in ipairs(getLocationsByType('bank')) do
        local x, y, z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
        if x and y and z and #(coords - vector3(x, y, z)) <= 6.0 then return true end
    end
    if allowATM then
        for _, location in ipairs(getLocationsByType('atm')) do
            local x, y, z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
            if x and y and z and #(coords - vector3(x, y, z)) <= 4.0 then return true end
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

local function requireAuthenticatedSession(src, operation, allowATM)
    local session = authenticatedSessions[src]
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not session or not player or session.charId ~= player.charId or GetGameTimer() > session.expiresAt then
        authenticatedSessions[src] = nil
        notify(src, 'Veuillez d’abord vous identifier avec votre empreinte.', 'error')
        return false
    end
    if not IsNearBankOrATM(src, allowATM) then
        authenticatedSessions[src] = nil
        notify(src, 'Vous devez rester devant un guichet ou un distributeur.', 'error')
        return false
    end
    session.expiresAt = GetGameTimer() + AUTH_TTL
    return true
end

RegisterNetEvent('rp_economy:server:authenticate', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'economy:fingerprint', 2500) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or not tonumber(player.charId) or not IsNearBankOrATM(src, true) then
        authenticatedSessions[src] = nil
        TriggerClientEvent('rp_economy:client:authenticationResult', src, {
            success = false,
            message = 'Identification impossible : approchez-vous d’un guichet ou d’un distributeur.'
        })
        return
    end
    authenticatedSessions[src] = {
        charId = player.charId,
        expiresAt = GetGameTimer() + AUTH_TTL
    }
    TriggerClientEvent('rp_economy:client:authenticationResult', src, {
        success = true,
        cash = tonumber(player.cash) or 0,
        bank = tonumber(player.bank) or 0,
        playerName = (tostring(player.firstname or 'Citoyen') .. ' ' .. tostring(player.lastname or '')):gsub('%s+, function(characterId, transactionType, amount, sender, reason)
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
    if not requireAuthenticatedSession(src, 'deposit', true) then return end
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
    if not requireAuthenticatedSession(src, 'withdraw', true) then return end
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
    if not requireAuthenticatedSession(src, 'transfer', false) then return end
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
    -- Both live balances must be synchronized while both character save locks
    -- are still held, otherwise an autosave can restore stale account values.
    if ok and tonumber(affected) == 2 then
        player.bank, target.bank = player.bank - amount, target.bank + amount
    end
    exports['rp_core']:ReleaseCharacterLock(lockedIds)
    if not ok then
        print(('[rp_economy] Transfer SQL error for characters %s -> %s: %s'):format(
            tostring(player.charId), tostring(target.charId), tostring(affected)))
        notify(src, 'Virement impossible : erreur de base de données.', 'error')
        return
    end
    if tonumber(affected) ~= 2 then
        notify(src, 'Virement impossible : solde insuffisant ou compte introuvable.', 'error')
        return
    end
    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'transfer_send', amount, target.firstname .. ' ' .. target.lastname, 'Virement envoyé')
    TriggerEvent('rp_economy:server:logTransaction', target.charId, 'transfer_receive', amount, player.firstname .. ' ' .. player.lastname, 'Virement reçu')
    TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
    TriggerClientEvent('rp_core:client:updateBank', targetId, target.bank)
    TriggerClientEvent('rp_economy:client:refreshBalances', src, player.cash, player.bank)
    TriggerClientEvent('rp_economy:client:refreshBalances', targetId, target.cash, target.bank)
    notify(src, 'Virement de ' .. formatCurrency(amount) .. ' effectué.', 'success')
    notify(targetId, 'Virement de ' .. formatCurrency(amount) .. ' reçu.', 'info')
end)

AddEventHandler('playerDropped', function()
    authenticatedSessions[source] = nil
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
, ''),
        accountNumber = ('LS-%06d'):format(tonumber(player.charId) or 0)
    })
end)

RegisterNetEvent('rp_economy:server:logout', function()
    authenticatedSessions[source] = nil
end)

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
    -- Both live balances must be synchronized while both character save locks
    -- are still held, otherwise an autosave can restore stale account values.
    if ok and tonumber(affected) == 2 then
        player.bank, target.bank = player.bank - amount, target.bank + amount
    end
    exports['rp_core']:ReleaseCharacterLock(lockedIds)
    if not ok then
        print(('[rp_economy] Transfer SQL error for characters %s -> %s: %s'):format(
            tostring(player.charId), tostring(target.charId), tostring(affected)))
        notify(src, 'Virement impossible : erreur de base de données.', 'error')
        return
    end
    if tonumber(affected) ~= 2 then
        notify(src, 'Virement impossible : solde insuffisant ou compte introuvable.', 'error')
        return
    end
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
