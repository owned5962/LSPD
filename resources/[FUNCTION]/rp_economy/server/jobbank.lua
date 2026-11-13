local MAX_JOB_BANK_TRANSACTION = 1000000
local jobLocks = {}
local initialized = false

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
    TriggerClientEvent('rp_economy:client:bankNotice', src, message, kind or 'info')
end

local function validAmount(value)
    local amount = tonumber(value)
    if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > MAX_JOB_BANK_TRANSACTION then return nil end
    return amount
end

local function ensureAccount(jobName)
    if not initialized or type(jobName) ~= 'string' or jobName == '' or #jobName > 64 then return false end
    local ok = pcall(MySQL.insert.await,
        'INSERT IGNORE INTO rp_job_bank_accounts (job, balance, allow_deposit, allow_withdraw) VALUES (?, 0, 1, 1)',
        { jobName })
    return ok
end

local function getAccountData(jobName)
    if not ensureAccount(jobName) then return nil end
    local account = MySQL.single.await(
        'SELECT job, balance, allow_deposit, allow_withdraw FROM rp_job_bank_accounts WHERE job = ?',
        { jobName })
    if not account then return nil end
    local jobOk, job = pcall(function() return exports['rp_jobs']:GetJob(jobName) end)
    account.label = jobOk and job and job.label or jobName
    account.balance = tonumber(account.balance) or 0
    account.allow_deposit = tonumber(account.allow_deposit) == 1
    account.allow_withdraw = tonumber(account.allow_withdraw) == 1
    local history = MySQL.query.await(
        'SELECT id, character_id, player_name, transaction_type, amount, balance_after, created_at FROM rp_job_bank_transactions WHERE job = ? ORDER BY id DESC LIMIT 12',
        { jobName }) or {}
    return { account = account, history = history }
end

MySQL.ready(function()
    CreateThread(function()
        local ok, err = pcall(function()
            MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_job_bank_accounts (
                job VARCHAR(64) NOT NULL PRIMARY KEY,
                balance BIGINT UNSIGNED NOT NULL DEFAULT 0,
                allow_deposit TINYINT(1) NOT NULL DEFAULT 1,
                allow_withdraw TINYINT(1) NOT NULL DEFAULT 1,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
            MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_job_bank_transactions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
                job VARCHAR(64) NOT NULL,
                character_id INT NOT NULL,
                player_name VARCHAR(128) NOT NULL,
                transaction_type ENUM('deposit','withdraw') NOT NULL,
                amount BIGINT UNSIGNED NOT NULL,
                balance_after BIGINT UNSIGNED NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                KEY idx_job_bank_history (job, id),
                KEY idx_job_bank_character (character_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        end)
        if not ok then
            print('[rp_jobbank] Initialisation SQL impossible : ' .. tostring(err))
            return
        end
        initialized = true
        local jobsOk, jobs = pcall(function() return exports['rp_jobs']:GetAllJobs() end)
        if jobsOk and type(jobs) == 'table' then
            for key, job in pairs(jobs) do
                local name = type(job) == 'table' and (job.name or key) or key
                ensureAccount(tostring(name))
            end
        end
        print('[rp_jobbank] Comptes bancaires métiers prêts.')
    end)
end)

RegisterNetEvent('rp_jobbank:server:request', function()
    local src = source
    if exports['rp_economy']:IsBankSessionAuthenticated(src) ~= true then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local jobName = player and tostring(player.job or '') or ''
    if jobName == '' or jobName == 'unemployed' then
        TriggerClientEvent('rp_jobbank:client:update', src, nil)
        return
    end
    local ok, data = pcall(getAccountData, jobName)
    TriggerClientEvent('rp_jobbank:client:update', src, ok and data or nil)
end)

local function transact(src, rawAmount, kind)
    if exports['rp_economy']:IsBankSessionAuthenticated(src) ~= true then return end
    if not exports['rp_core']:CanPerformAction(src, 'economy:jobbank:' .. kind, 1500) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local amount = validAmount(rawAmount)
    local jobName = player and tostring(player.job or '') or ''
    if not player or not amount or jobName == '' or jobName == 'unemployed' then
        notify(src, 'Aucun compte bancaire de métier disponible.', 'error')
        return
    end
    local jobOk, job = pcall(function() return exports['rp_jobs']:GetJob(jobName) end)
    if not jobOk or not job then notify(src, 'Métier invalide : opération refusée.', 'error'); return end
    if jobLocks[jobName] then notify(src, 'Une opération est déjà en cours sur ce compte.', 'warning'); return end
    jobLocks[jobName] = true
    local dataOk, data = pcall(getAccountData, jobName)
    if not dataOk or not data then
        jobLocks[jobName] = nil
        notify(src, 'Compte du métier indisponible.', 'error')
        return
    end
    local account = data.account
    if kind == 'deposit' and not account.allow_deposit then
        jobLocks[jobName] = nil
        notify(src, 'Les dépôts sont désactivés pour ce métier.', 'error')
        return
    end
    if kind == 'withdraw' and not account.allow_withdraw then
        jobLocks[jobName] = nil
        notify(src, 'Les retraits sont désactivés pour ce métier.', 'error')
        return
    end
    if kind == 'deposit' and tonumber(player.cash) < amount then
        jobLocks[jobName] = nil
        notify(src, 'Vous ne possédez pas assez d’espèces.', 'error')
        return
    end
    if kind == 'withdraw' and tonumber(account.balance) < amount then
        jobLocks[jobName] = nil
        notify(src, 'Le solde du compte du métier est insuffisant.', 'error')
        return
    end

    local lockIds = { player.charId }
    if not exports['rp_core']:AcquireCharacterLock(lockIds) then
        jobLocks[jobName] = nil
        notify(src, 'Une opération sur votre compte personnel est en cours. Réessayez.', 'warning')
        return
    end
    local query, params
    if kind == 'deposit' then
        query = [[UPDATE characters AS c JOIN rp_job_bank_accounts AS a ON a.job = ?
            SET c.cash = c.cash - ?, a.balance = a.balance + ?
            WHERE c.id = ? AND c.identifier = ? AND c.cash >= ? AND a.allow_deposit = 1]]
        params = { jobName, amount, amount, player.charId, player.identifier, amount }
    else
        query = [[UPDATE characters AS c JOIN rp_job_bank_accounts AS a ON a.job = ?
            SET c.cash = c.cash + ?, a.balance = a.balance - ?
            WHERE c.id = ? AND c.identifier = ? AND a.balance >= ? AND a.allow_withdraw = 1]]
        params = { jobName, amount, amount, player.charId, player.identifier, amount }
    end
    local sqlOk, affected = pcall(MySQL.update.await, query, params)
    exports['rp_core']:ReleaseCharacterLock(lockIds)
    if not sqlOk or not tonumber(affected) or tonumber(affected) < 1 then
        jobLocks[jobName] = nil
        if not sqlOk then print(('[rp_jobbank] Erreur SQL %s/%s : %s'):format(jobName, kind, tostring(affected))) end
        notify(src, 'Opération refusée : solde, autorisation ou compte invalide.', 'error')
        return
    end

    if kind == 'deposit' then player.cash = player.cash - amount else player.cash = player.cash + amount end
    local balance = kind == 'deposit' and (tonumber(account.balance) + amount) or (tonumber(account.balance) - amount)
    local playerName = (tostring(player.firstname or '') .. ' ' .. tostring(player.lastname or '')):gsub('^%s*(.-)%s*    TriggerClientEvent('rp_core:client:updateCash', src, player.cash)
    TriggerClientEvent('rp_economy:client:refreshBalances', src, player.cash, player.bank)
    local refreshed = getAccountData(jobName)
    TriggerClientEvent('rp_jobbank:client:update', src, refreshed)
    local formatted = tostring(amount):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    notify(src, (kind == 'deposit' and 'Dépôt' or 'Retrait') .. ' de ' .. formatted .. ' $ effectué sur le compte ' .. tostring(job.label or jobName) .. '.', 'success')
end

RegisterNetEvent('rp_jobbank:server:deposit', function(amount)
    transact(source, amount, 'deposit')
end)

RegisterNetEvent('rp_jobbank:server:withdraw', function(amount)
    transact(source, amount, 'withdraw')
end)
, '%1')
    local logOk, logErr = pcall(MySQL.insert.await,
        'INSERT INTO rp_job_bank_transactions (job, character_id, player_name, transaction_type, amount, balance_after) VALUES (?, ?, ?, ?, ?, ?)',
        { jobName, player.charId, playerName, kind, amount, balance })
    jobLocks[jobName] = nil
    if not logOk then print('[rp_jobbank] Historique non enregistré : ' .. tostring(logErr)) end
    TriggerClientEvent('rp_core:client:updateCash', src, player.cash)
    TriggerClientEvent('rp_economy:client:refreshBalances', src, player.cash, player.bank)
    local refreshed = getAccountData(jobName)
    TriggerClientEvent('rp_jobbank:client:update', src, refreshed)
    local formatted = tostring(amount):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
    notify(src, (kind == 'deposit' and 'Dépôt' or 'Retrait') .. ' de ' .. formatted .. ' $ effectué sur le compte ' .. tostring(job.label or jobName) .. '.', 'success')
end

RegisterNetEvent('rp_jobbank:server:deposit', function(amount)
    transact(source, amount, 'deposit')
end)

RegisterNetEvent('rp_jobbank:server:withdraw', function(amount)
    transact(source, amount, 'withdraw')
end)
