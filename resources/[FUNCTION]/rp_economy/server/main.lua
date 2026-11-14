local MAX_TRANSACTION = 1000000
local AUTH_TTL = 300000
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
        if x and y and z and #(coords - vector3(x, y, z)) <= 4.0 then return true end
    end

    if allowATM then
        for _, location in ipairs(getLocationsByType('atm')) do
            local x, y, z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
            if x and y and z and #(coords - vector3(x, y, z)) <= 1.5 then return true end
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

local function getPersonalHistory(characterId)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT type, amount, sender_or_receiver, reason, created_at FROM bank_transactions WHERE character_id = ? ORDER BY id DESC LIMIT 20',
        { tonumber(characterId) })
    if not ok or type(rows) ~= 'table' then
        print(('[rp_economy] Personal history lookup failed for character %s: %s'):format(
            tostring(characterId), tostring(rows)))
        return {}
    end
    return rows
end

local function refreshAccountSnapshot(src, player)
    TriggerClientEvent('rp_economy:client:refreshBalances', src,
        player.cash, player.bank, getPersonalHistory(player.charId))
end

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
    TriggerClientEvent('rp_economy:client:bankNotice', src, message, kind or 'info')
end

local function requireAuthenticatedSession(src, allowATM)
    local session = authenticatedSessions[src]
    local player = exports['rp_core']:GetPlayerFromId(src)

    if not session or not player or session.charId ~= player.charId or GetGameTimer() > session.expiresAt then
        authenticatedSessions[src] = nil
        TriggerClientEvent('rp_economy:client:sessionExpired', src)
        notify(src, 'Votre session bancaire a expiré. Identifiez-vous à nouveau.', 'error')
        return false
    end

    if not IsNearBankOrATM(src, allowATM) then
        authenticatedSessions[src] = nil
        TriggerClientEvent('rp_economy:client:sessionExpired', src)
        notify(src, 'Vous devez rester devant un guichet ou un distributeur.', 'error')
        return false
    end

    session.expiresAt = GetGameTimer() + AUTH_TTL
    return true
end

exports('IsBankSessionAuthenticated', function(src)
    return requireAuthenticatedSession(tonumber(src), false) == true
end)

RegisterNetEvent('rp_economy:server:authenticate', function()
    local src = source
    -- Validate the actual terminal location before consuming the anti-spam cooldown.
    -- Otherwise a failed proximity attempt can make the next valid scan look like a broken reader.
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or not tonumber(player.charId) then
        authenticatedSessions[src] = nil
        TriggerClientEvent('rp_economy:client:authenticationResult', src, {
            success = false,
            message = 'Votre personnage n’est pas encore chargé. Réessayez.'
        })
        return
    end

    if not IsNearBankOrATM(src, true) then
        authenticatedSessions[src] = nil
        TriggerClientEvent('rp_economy:client:authenticationResult', src, {
            success = false,
            message = 'Identification impossible : approchez-vous du guichet ou placez-vous devant un véritable distributeur.'
        })
        return
    end

    if not exports['rp_core']:CanPerformAction(src, 'economy:fingerprint', 1200) then
        TriggerClientEvent('rp_economy:client:authenticationResult', src, {
            success = false,
            message = 'Une lecture vient déjà d’être demandée. Patientez une seconde avant de réessayer.'
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
        playerName = (tostring(player.firstname or 'Citoyen') .. ' ' .. tostring(player.lastname or '')):gsub('%s+$', ''),
        accountNumber = ('LS-%06d'):format(tonumber(player.charId) or 0),
        history = getPersonalHistory(player.charId)
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

    local ok, result = pcall(MySQL.insert.await,
        'INSERT INTO bank_transactions (character_id, type, amount, sender_or_receiver, reason) VALUES (?, ?, ?, ?, ?)',
        {
            characterId, transactionType, amount,
            tostring(sender or 'Système'):sub(1, 128),
            tostring(reason or 'Transaction'):sub(1, 255)
        }
    )
    if not ok or tonumber(result) == nil or tonumber(result) < 1 then
        print(('[rp_economy] Transaction log failed for character %s: %s'):format(characterId, tostring(result)))
    end
end)

RegisterNetEvent('rp_economy:server:deposit', function(rawAmount)
    local src = source
    if not requireAuthenticatedSession(src, true) then return end
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
    refreshAccountSnapshot(src, player)
    notify(src, 'Dépôt réussi : ' .. formatCurrency(amount), 'success')
end)

RegisterNetEvent('rp_economy:server:withdraw', function(rawAmount)
    local src = source
    if not requireAuthenticatedSession(src, true) then return end
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
    if not requireAuthenticatedSession(src, false) then return end
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

    TriggerEvent('rp_economy:server:logTransaction', player.charId, 'transfer_send', amount, (tostring(target.firstname or '') .. ' ' .. tostring(target.lastname or '')):sub(1, 128), 'Virement envoyé')
    TriggerEvent('rp_economy:server:logTransaction', target.charId, 'transfer_receive', amount, (tostring(player.firstname or '') .. ' ' .. tostring(player.lastname or '')):sub(1, 128), 'Virement reçu')
    TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
    TriggerClientEvent('rp_core:client:updateBank', targetId, target.bank)
    TriggerClientEvent('rp_economy:client:refreshBalances', src, player.cash, player.bank)
    refreshAccountSnapshot(targetId, target)
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
            if type(player) == 'table' and type(player.addBank) == 'function' then
                local gradeOk, gradeData = pcall(function()
                    return exports['rp_jobs']:GetJobGrade(player.job, player.jobGrade)
                end)
                if not gradeOk then
                    print(('[rp_economy] Salary grade lookup failed for player %s: %s'):format(
                        tostring(src), tostring(gradeData)))
                    gradeData = nil
                end

                local salary = type(gradeData) == 'table' and validAmount(gradeData.salary) or nil
                if salary then
                    -- addBank owns persistence, transaction history and the player notification.
                    -- Avoid a duplicate notification and never invent a fallback salary if the
                    -- job catalogue cannot provide a valid grade amount.
                    local paidOk, paid = pcall(player.addBank, salary,
                        'Salaire - ' .. tostring(player.job or 'Civil'), 'salary')
                    if not paidOk or paid ~= true then
                        print(('[rp_economy] Salary payment failed for player %s: %s'):format(
                            tostring(src), tostring(paid)))
                    end
                end
            end
        end
    end
end)
