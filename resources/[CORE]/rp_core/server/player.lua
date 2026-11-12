local transferLocks = {}
local saveLocks = {}

-- Shared lock for balance-changing SQL transactions in other server resources.
-- It prevents periodic character saves from writing stale cash/bank values.
local function AcquireCharacterLock(characterIds)
    if type(characterIds) ~= 'table' or #characterIds < 1 then return false end
    local ids, seen = {}, {}
    for _, rawId in ipairs(characterIds) do
        local id = tonumber(rawId)
        if not id or id < 1 or id % 1 ~= 0 or seen[id]
            or transferLocks[id] or saveLocks[id] then return false end
        ids[#ids + 1], seen[id] = id, true
    end
    for _, id in ipairs(ids) do transferLocks[id] = true end
    return true
end

local function ReleaseCharacterLock(characterIds)
    if type(characterIds) ~= 'table' then return false end
    for _, rawId in ipairs(characterIds) do
        local id = tonumber(rawId)
        if id and id > 0 then transferLocks[id] = nil end
    end
    return true
end

exports('AcquireCharacterLock', AcquireCharacterLock)
exports('ReleaseCharacterLock', ReleaseCharacterLock)

local function RequirePositiveInteger(value, fieldName)
    local number = tonumber(value)
    if not number or number < 1 or number % 1 ~= 0 then
        error(('Invalid character field %s: expected a positive integer'):format(fieldName))
    end
    return number
end

local function ReadNonNegativeInteger(value, fallback, fieldName)
    if value == nil then return fallback end
    local number = tonumber(value)
    if not number or number < 0 or number % 1 ~= 0 then
        error(('Invalid character field %s: expected a non-negative integer'):format(fieldName))
    end
    return number
end

function CreateRPPlayer(source, identifier, charData)
    if type(charData) ~= 'table' then error('Invalid character data: expected a table') end

    local src = RequirePositiveInteger(source, 'source')
    if not GetPlayerName(src) then error('Invalid character source: player is not connected') end
    if type(identifier) ~= 'string' or not identifier:match('^license:[%w]+
    self.firstname = charData.firstname or 'John'
    self.lastname = charData.lastname or 'Doe'
    self.name = self.firstname .. ' ' .. self.lastname
    self.dateofbirth = charData.dateofbirth or '1995-01-01'
    self.sex = charData.sex or 'm'
    self.height = tonumber(charData.height) or 175
    self.phoneNumber = charData.phone_number
    self.isDead = charData.is_dead == true or tonumber(charData.is_dead) == 1
    self.cash = ReadNonNegativeInteger(charData.cash, Config.StartingCash, 'cash')
    self.bank = ReadNonNegativeInteger(charData.bank, Config.StartingBank, 'bank')
    self.job = charData.job or 'unemployed'
    self.jobGrade = tonumber(charData.job_grade) or 0
    self.group = charData.group or 'user'
    self.duty = false

    local savedMetadata = charData.metadata
    if type(savedMetadata) == 'string' and savedMetadata ~= '' then
        local ok, decoded = pcall(json.decode, savedMetadata)
        savedMetadata = ok and decoded or nil
    end
    self.metadata = type(savedMetadata) == 'table' and savedMetadata or {}
    self.metadata.hunger = math.max(0, math.min(100, tonumber(self.metadata.hunger) or 100))
    self.metadata.thirst = math.max(0, math.min(100, tonumber(self.metadata.thirst) or 100))

    local savedPosition = charData.position
    if type(savedPosition) == 'string' and savedPosition ~= '' then
        local ok, decoded = pcall(json.decode, savedPosition)
        savedPosition = ok and decoded or nil
    end
    self.position = type(savedPosition) == 'table' and savedPosition or Config.DefaultSpawn

    local savedSkin = charData.skin
    if type(savedSkin) == 'string' and savedSkin ~= '' then
        local ok, decoded = pcall(json.decode, savedSkin)
        savedSkin = ok and decoded or nil
    end
    self.skin = type(savedSkin) == 'table' and savedSkin or {}

    function self.getCash()
        return self.cash
    end

    function self.addCash(amount)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 then return false end
        local previous = self.cash
        self.cash = self.cash + amount
        if not self.save() then
            self.cash = previous
            TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
            return false
        end
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        TriggerClientEvent('rp_core:client:notify', self.source, '+ ' .. Utils.FormatCurrency(amount) .. ' (Cash)', 'success')
        return true
    end

    function self.removeCash(amount)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 or self.cash < amount then return false end
        local previous = self.cash
        self.cash = self.cash - amount
        if not self.save() then
            self.cash = previous
            TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
            return false
        end
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        TriggerClientEvent('rp_core:client:notify', self.source, '- ' .. Utils.FormatCurrency(amount) .. ' (Cash)', 'warning')
        return true
    end

    function self.getBank()
        return self.bank
    end

    function self.addBank(amount, reason, transactionType)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 then return false end
        local previous = self.bank
        self.bank = self.bank + amount
        if not self.save() then
            self.bank = previous
            TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
            return false
        end
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        TriggerClientEvent('rp_core:client:notify', self.source, '+ ' .. Utils.FormatCurrency(amount) .. ' (Banque)', 'success')
        TriggerEvent('rp_economy:server:logTransaction', self.charId, transactionType or 'deposit', amount, 'Système', reason or 'Crédit')
        return true
    end

    function self.removeBank(amount, reason, transactionType)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 or self.bank < amount then return false end
        local previous = self.bank
        self.bank = self.bank - amount
        if not self.save() then
            self.bank = previous
            TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
            return false
        end
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        TriggerClientEvent('rp_core:client:notify', self.source, '- ' .. Utils.FormatCurrency(amount) .. ' (Banque)', 'warning')
        TriggerEvent('rp_economy:server:logTransaction', self.charId, transactionType or 'withdraw', amount, 'Système', reason or 'Débit')
        return true
    end

    function self.setJob(jobName, grade)
        if not exports['rp_jobs']:IsValidJob(jobName) then
            TriggerClientEvent('rp_core:client:notify', self.source, 'Métier inconnu. Aucun changement appliqué.', 'error')
            return false
        end
        local jobObj = exports['rp_jobs']:GetJob(jobName)
        if not jobObj then
            jobName = 'unemployed'
            grade = 0
            jobObj = exports['rp_jobs']:GetJob('unemployed')
        end
        grade = tonumber(grade) or 0
        if not jobObj.grades or not jobObj.grades[grade] then
            TriggerClientEvent('rp_core:client:notify', self.source, 'Grade invalide pour ce métier.', 'error')
            return false
        end
        local gradeData = exports['rp_jobs']:GetJobGrade(jobName, grade)
        local previousJob, previousGrade, previousDuty = self.job, self.jobGrade, self.duty
        self.job, self.jobGrade, self.duty = jobName, grade, false
        if not self.save() then
            self.job, self.jobGrade, self.duty = previousJob, previousGrade, previousDuty
            TriggerClientEvent('rp_core:client:notify', self.source, 'Impossible de sauvegarder votre métier. Aucun changement appliqué.', 'error')
            return false
        end
        TriggerClientEvent('rp_core:client:setJob', self.source, jobName, jobObj.label, grade, gradeData.label)
        TriggerClientEvent('rp_core:client:notify', self.source, 'Votre métier est désormais: ' .. jobObj.label .. ' (' .. gradeData.label .. ')', 'info')
        return true
    end

    function self.save(skipPosition)
        -- Serialize saves against transfers and other saves for this character.
        if transferLocks[self.charId] or saveLocks[self.charId] then return false end
        saveLocks[self.charId] = true

        -- Protect the entire operation, not only the SQL call: native lookups and
        -- JSON encoding can also fail. The lock must always be released.
        local ok, result = pcall(function()
            local position = self.position or Config.DefaultSpawn
            local ped = not skipPosition and GetPlayerPed(self.source) or 0
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                position = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = GetEntityHeading(ped)
                }
                self.position = position
            end

            local affected = MySQL.update.await(
                'UPDATE characters SET cash = ?, bank = ?, job = ?, job_grade = ?, position = ?, skin = ?, metadata = ?, is_dead = ? WHERE id = ? AND identifier = ?',
                {
                    self.cash,
                    self.bank,
                    self.job,
                    self.jobGrade,
                    json.encode(position),
                    json.encode(self.skin or {}),
                    json.encode(self.metadata or {}),
                    self.isDead == true and 1 or 0,
                    self.charId,
                    self.identifier
                }
            )
            if type(affected) ~= 'number' then
                error('Unexpected SQL update result: ' .. tostring(affected))
            end
            if affected > 0 then return true end

            -- oxmysql reports changed rows: a valid no-op UPDATE can return 0.
            -- Confirm the character still exists before treating that save as successful.
            local exists = MySQL.scalar.await(
                'SELECT 1 FROM characters WHERE id = ? AND identifier = ? LIMIT 1',
                { self.charId, self.identifier }
            )
            return tonumber(exists) == 1
        end)

        saveLocks[self.charId] = nil
        if not ok then
            print(('[rp_core] SQL save failed for character %s: %s'):format(self.charId, tostring(result)))
            return false
        end
        return result == true
    end

    function self.syncClient()
        local jobObj = exports['rp_jobs']:GetJob(self.job) or { label = self.job }
        local gradeData = exports['rp_jobs']:GetJobGrade(self.job, self.jobGrade) or { label = 'Grade ' .. self.jobGrade }
        TriggerClientEvent('rp_core:client:setPlayerData', self.source, {
            isLoaded = self.isLoaded == true,
            source = self.source,
            identifier = self.identifier,
            charId = self.charId,
            characterSlot = self.slot,
            firstname = self.firstname,
            lastname = self.lastname,
            name = self.name,
            dateofbirth = self.dateofbirth,
            sex = self.sex,
            height = self.height,
            phoneNumber = self.phoneNumber,
            isDead = self.isDead == true,
            cash = self.cash,
            bank = self.bank,
            job = self.job,
            jobLabel = jobObj.label,
            jobGrade = self.jobGrade,
            jobGradeLabel = gradeData.label,
            group = self.group,
            duty = self.duty == true,
            hunger = self.metadata.hunger,
            thirst = self.metadata.thirst,
            metadata = self.metadata,
            position = self.position,
            skin = self.skin
        })
    end

    return self
end

exports('CreateRPPlayer', CreateRPPlayer)


-- Atomic cash transfer: both character balances are updated by one SQL statement.
-- The client never supplies balances or character identifiers.

function TransferCash(fromSource, toSource, amount)
    fromSource, toSource, amount = tonumber(fromSource), tonumber(toSource), tonumber(amount)
    if not fromSource or not toSource or fromSource == toSource or not amount
        or amount < 1 or amount % 1 ~= 0 or amount > 1000000 then return false end

    local sender, recipient = Players[fromSource], Players[toSource]
    if not sender or not recipient or sender.cash < amount then return false end
    if transferLocks[sender.charId] or transferLocks[recipient.charId]
        or saveLocks[sender.charId] or saveLocks[recipient.charId] then return false end

    transferLocks[sender.charId], transferLocks[recipient.charId] = true, true
    local ok, affected = pcall(MySQL.update.await, [[
        UPDATE characters AS sender
        JOIN characters AS recipient ON recipient.id = ? AND recipient.identifier = ?
        SET sender.cash = sender.cash - ?, recipient.cash = recipient.cash + ?
        WHERE sender.id = ? AND sender.identifier = ? AND sender.cash >= ?
          AND sender.id <> recipient.id
    ]], { recipient.charId, recipient.identifier, amount, amount,
          sender.charId, sender.identifier, amount })
    transferLocks[sender.charId], transferLocks[recipient.charId] = nil, nil

    if not ok or not affected or affected < 2 then
        if not ok then print(('[rp_core] Cash transfer SQL error: %s'):format(tostring(affected))) end
        return false
    end

    sender.cash = sender.cash - amount
    recipient.cash = recipient.cash + amount
    TriggerClientEvent('rp_core:client:updateCash', fromSource, sender.cash)
    TriggerClientEvent('rp_core:client:updateCash', toSource, recipient.cash)
    TriggerClientEvent('rp_core:client:notify', fromSource,
        '- ' .. Utils.FormatCurrency(amount) .. ' (Virement à ' .. recipient.firstname .. ' ' .. recipient.lastname .. ')', 'warning')
    TriggerClientEvent('rp_core:client:notify', toSource,
        '+ ' .. Utils.FormatCurrency(amount) .. ' (Virement de ' .. sender.firstname .. ' ' .. sender.lastname .. ')', 'success')
    return true
end

exports('TransferCash', TransferCash)
) or #identifier > 64 then
        error('Invalid character identifier: expected a FiveM license identifier')
    end

    local characterId = RequirePositiveInteger(charData.id, 'id')
    local characterSlot = RequirePositiveInteger(charData.char_id, 'char_id')
    if characterSlot > 3 then error('Invalid character slot: maximum is 3') end

    local self = {}
    self.source = src
    self.identifier = identifier
    self.isLoaded = true
    -- Never substitute a fake database ID: it could overwrite another character.
    self.charId = characterId
    self.slot = characterSlot
    self.firstname = charData.firstname or 'John'
    self.lastname = charData.lastname or 'Doe'
    self.name = self.firstname .. ' ' .. self.lastname
    self.dateofbirth = charData.dateofbirth or '1995-01-01'
    self.sex = charData.sex or 'm'
    self.height = tonumber(charData.height) or 175
    self.phoneNumber = charData.phone_number
    self.isDead = charData.is_dead == true or tonumber(charData.is_dead) == 1
    self.cash = tonumber(charData.cash) or Config.StartingCash
    self.bank = tonumber(charData.bank) or Config.StartingBank
    self.job = charData.job or 'unemployed'
    self.jobGrade = tonumber(charData.job_grade) or 0
    self.group = charData.group or 'user'
    self.duty = false

    local savedMetadata = charData.metadata
    if type(savedMetadata) == 'string' and savedMetadata ~= '' then
        local ok, decoded = pcall(json.decode, savedMetadata)
        savedMetadata = ok and decoded or nil
    end
    self.metadata = type(savedMetadata) == 'table' and savedMetadata or {}
    self.metadata.hunger = math.max(0, math.min(100, tonumber(self.metadata.hunger) or 100))
    self.metadata.thirst = math.max(0, math.min(100, tonumber(self.metadata.thirst) or 100))

    local savedPosition = charData.position
    if type(savedPosition) == 'string' and savedPosition ~= '' then
        local ok, decoded = pcall(json.decode, savedPosition)
        savedPosition = ok and decoded or nil
    end
    self.position = type(savedPosition) == 'table' and savedPosition or Config.DefaultSpawn

    local savedSkin = charData.skin
    if type(savedSkin) == 'string' and savedSkin ~= '' then
        local ok, decoded = pcall(json.decode, savedSkin)
        savedSkin = ok and decoded or nil
    end
    self.skin = type(savedSkin) == 'table' and savedSkin or {}

    function self.getCash()
        return self.cash
    end

    function self.addCash(amount)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 then return false end
        local previous = self.cash
        self.cash = self.cash + amount
        if not self.save() then
            self.cash = previous
            TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
            return false
        end
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        TriggerClientEvent('rp_core:client:notify', self.source, '+ ' .. Utils.FormatCurrency(amount) .. ' (Cash)', 'success')
        return true
    end

    function self.removeCash(amount)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 or self.cash < amount then return false end
        local previous = self.cash
        self.cash = self.cash - amount
        if not self.save() then
            self.cash = previous
            TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
            return false
        end
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        TriggerClientEvent('rp_core:client:notify', self.source, '- ' .. Utils.FormatCurrency(amount) .. ' (Cash)', 'warning')
        return true
    end

    function self.getBank()
        return self.bank
    end

    function self.addBank(amount, reason, transactionType)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 then return false end
        local previous = self.bank
        self.bank = self.bank + amount
        if not self.save() then
            self.bank = previous
            TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
            return false
        end
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        TriggerClientEvent('rp_core:client:notify', self.source, '+ ' .. Utils.FormatCurrency(amount) .. ' (Banque)', 'success')
        TriggerEvent('rp_economy:server:logTransaction', self.charId, transactionType or 'deposit', amount, 'Système', reason or 'Crédit')
        return true
    end

    function self.removeBank(amount, reason, transactionType)
        amount = tonumber(amount)
        if not amount or amount <= 0 or amount % 1 ~= 0 or self.bank < amount then return false end
        local previous = self.bank
        self.bank = self.bank - amount
        if not self.save() then
            self.bank = previous
            TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
            return false
        end
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        TriggerClientEvent('rp_core:client:notify', self.source, '- ' .. Utils.FormatCurrency(amount) .. ' (Banque)', 'warning')
        TriggerEvent('rp_economy:server:logTransaction', self.charId, transactionType or 'withdraw', amount, 'Système', reason or 'Débit')
        return true
    end

    function self.setJob(jobName, grade)
        if not exports['rp_jobs']:IsValidJob(jobName) then
            TriggerClientEvent('rp_core:client:notify', self.source, 'Métier inconnu. Aucun changement appliqué.', 'error')
            return false
        end
        local jobObj = exports['rp_jobs']:GetJob(jobName)
        if not jobObj then
            jobName = 'unemployed'
            grade = 0
            jobObj = exports['rp_jobs']:GetJob('unemployed')
        end
        grade = tonumber(grade) or 0
        if not jobObj.grades or not jobObj.grades[grade] then
            TriggerClientEvent('rp_core:client:notify', self.source, 'Grade invalide pour ce métier.', 'error')
            return false
        end
        local gradeData = exports['rp_jobs']:GetJobGrade(jobName, grade)
        local previousJob, previousGrade, previousDuty = self.job, self.jobGrade, self.duty
        self.job, self.jobGrade, self.duty = jobName, grade, false
        if not self.save() then
            self.job, self.jobGrade, self.duty = previousJob, previousGrade, previousDuty
            TriggerClientEvent('rp_core:client:notify', self.source, 'Impossible de sauvegarder votre métier. Aucun changement appliqué.', 'error')
            return false
        end
        TriggerClientEvent('rp_core:client:setJob', self.source, jobName, jobObj.label, grade, gradeData.label)
        TriggerClientEvent('rp_core:client:notify', self.source, 'Votre métier est désormais: ' .. jobObj.label .. ' (' .. gradeData.label .. ')', 'info')
        return true
    end

    function self.save(skipPosition)
        -- Serialize saves against transfers and other saves for this character.
        if transferLocks[self.charId] or saveLocks[self.charId] then return false end
        saveLocks[self.charId] = true

        -- Protect the entire operation, not only the SQL call: native lookups and
        -- JSON encoding can also fail. The lock must always be released.
        local ok, result = pcall(function()
            local position = self.position or Config.DefaultSpawn
            local ped = not skipPosition and GetPlayerPed(self.source) or 0
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                position = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = GetEntityHeading(ped)
                }
                self.position = position
            end

            local affected = MySQL.update.await(
                'UPDATE characters SET cash = ?, bank = ?, job = ?, job_grade = ?, position = ?, skin = ?, metadata = ? WHERE id = ? AND identifier = ?',
                {
                    self.cash,
                    self.bank,
                    self.job,
                    self.jobGrade,
                    json.encode(position),
                    json.encode(self.skin or {}),
                    json.encode(self.metadata or {}),
                    self.charId,
                    self.identifier
                }
            )
            if type(affected) ~= 'number' then
                error('Unexpected SQL update result: ' .. tostring(affected))
            end
            if affected > 0 then return true end

            -- oxmysql reports changed rows: a valid no-op UPDATE can return 0.
            -- Confirm the character still exists before treating that save as successful.
            local exists = MySQL.scalar.await(
                'SELECT 1 FROM characters WHERE id = ? AND identifier = ? LIMIT 1',
                { self.charId, self.identifier }
            )
            return tonumber(exists) == 1
        end)

        saveLocks[self.charId] = nil
        if not ok then
            print(('[rp_core] SQL save failed for character %s: %s'):format(self.charId, tostring(result)))
            return false
        end
        return result == true
    end

    function self.syncClient()
        local jobObj = exports['rp_jobs']:GetJob(self.job) or { label = self.job }
        local gradeData = exports['rp_jobs']:GetJobGrade(self.job, self.jobGrade) or { label = 'Grade ' .. self.jobGrade }
        TriggerClientEvent('rp_core:client:setPlayerData', self.source, {
            isLoaded = self.isLoaded == true,
            source = self.source,
            identifier = self.identifier,
            charId = self.charId,
            characterSlot = self.slot,
            firstname = self.firstname,
            lastname = self.lastname,
            name = self.name,
            dateofbirth = self.dateofbirth,
            sex = self.sex,
            height = self.height,
            phoneNumber = self.phoneNumber,
            isDead = self.isDead == true,
            cash = self.cash,
            bank = self.bank,
            job = self.job,
            jobLabel = jobObj.label,
            jobGrade = self.jobGrade,
            jobGradeLabel = gradeData.label,
            group = self.group,
            duty = self.duty == true,
            hunger = self.metadata.hunger,
            thirst = self.metadata.thirst,
            metadata = self.metadata,
            position = self.position,
            skin = self.skin
        })
    end

    return self
end

exports('CreateRPPlayer', CreateRPPlayer)


-- Atomic cash transfer: both character balances are updated by one SQL statement.
-- The client never supplies balances or character identifiers.

function TransferCash(fromSource, toSource, amount)
    fromSource, toSource, amount = tonumber(fromSource), tonumber(toSource), tonumber(amount)
    if not fromSource or not toSource or fromSource == toSource or not amount
        or amount < 1 or amount % 1 ~= 0 or amount > 1000000 then return false end

    local sender, recipient = Players[fromSource], Players[toSource]
    if not sender or not recipient or sender.cash < amount then return false end
    if transferLocks[sender.charId] or transferLocks[recipient.charId]
        or saveLocks[sender.charId] or saveLocks[recipient.charId] then return false end

    transferLocks[sender.charId], transferLocks[recipient.charId] = true, true
    local ok, affected = pcall(MySQL.update.await, [[
        UPDATE characters AS sender
        JOIN characters AS recipient ON recipient.id = ? AND recipient.identifier = ?
        SET sender.cash = sender.cash - ?, recipient.cash = recipient.cash + ?
        WHERE sender.id = ? AND sender.identifier = ? AND sender.cash >= ?
          AND sender.id <> recipient.id
    ]], { recipient.charId, recipient.identifier, amount, amount,
          sender.charId, sender.identifier, amount })
    transferLocks[sender.charId], transferLocks[recipient.charId] = nil, nil

    if not ok or not affected or affected < 2 then
        if not ok then print(('[rp_core] Cash transfer SQL error: %s'):format(tostring(affected))) end
        return false
    end

    sender.cash = sender.cash - amount
    recipient.cash = recipient.cash + amount
    TriggerClientEvent('rp_core:client:updateCash', fromSource, sender.cash)
    TriggerClientEvent('rp_core:client:updateCash', toSource, recipient.cash)
    TriggerClientEvent('rp_core:client:notify', fromSource,
        '- ' .. Utils.FormatCurrency(amount) .. ' (Virement à ' .. recipient.firstname .. ' ' .. recipient.lastname .. ')', 'warning')
    TriggerClientEvent('rp_core:client:notify', toSource,
        '+ ' .. Utils.FormatCurrency(amount) .. ' (Virement de ' .. sender.firstname .. ' ' .. sender.lastname .. ')', 'success')
    return true
end

exports('TransferCash', TransferCash)
