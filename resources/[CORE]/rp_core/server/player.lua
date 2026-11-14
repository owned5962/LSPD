-- Character player object + persistence (oxmysql).
-- NOTE: balances and identifiers are server-authoritative.

local TIMER_MODULUS = 4294967296
local saveLocks = {}

local function RequirePositiveInteger(value, fieldName)
    local number = tonumber(value)
    if not number or number < 1 or number % 1 ~= 0 then
        error(('Invalid character field %s: expected a positive integer'):format(fieldName))
    end
    return math.floor(number)
end

local function AcquireCharacterLock(characterId)
    characterId = tonumber(characterId)
    if not characterId then return false end
    if saveLocks[characterId] then return false end
    saveLocks[characterId] = true
    return true
end

local function ReleaseCharacterLock(characterId)
    characterId = tonumber(characterId)
    if not characterId then return end
    saveLocks[characterId] = nil
end

exports('AcquireCharacterLock', AcquireCharacterLock)
exports('ReleaseCharacterLock', ReleaseCharacterLock)

local function ReadNonNegativeInteger(value, fallback, fieldName)
    if value == nil then return fallback end
    -- MySQL/oxmysql may return DECIMAL/DOUBLE as 2500.0 or "2500.00".
    local number = tonumber(value)
    if not number or number < 0 then
        error(('Invalid character field %s: expected a non-negative number (got %s)')
            :format(fieldName, tostring(value)))
    end
    number = math.floor(number + 0.0000001)
    if number < 0 then
        error(('Invalid character field %s: expected a non-negative integer'):format(fieldName))
    end
    return number
end

function CreateRPPlayer(source, identifier, charData)
    if type(charData) ~= 'table' then error('Invalid character data: expected a table') end

    local src = RequirePositiveInteger(source, 'source')
    if not GetPlayerName(src) then error('Invalid character source: player is not connected') end
    local validIdentifier = type(identifier) == 'string'
        and #identifier >= 10 and #identifier <= 96
        and identifier:match('^license2?:[A-Za-z0-9_%-]+$') ~= nil
    if not validIdentifier then
        error(('Invalid character identifier: expected a FiveM license identifier (got %s)')
            :format(tostring(identifier)))
    end

    local characterId = RequirePositiveInteger(charData.id, 'id')
    local characterSlot = RequirePositiveInteger(charData.char_id, 'char_id')
    if characterSlot > 3 then error('Invalid character slot: maximum is 3') end

    local self = {}
    self.source = src
    self.isLoaded = true
    self.identifier = identifier
    self.charId = characterId
    self.slot = characterSlot
    self.firstname = tostring(charData.firstname or 'Citoyen')
    self.lastname = tostring(charData.lastname or '')
    self.name = (self.firstname .. ' ' .. self.lastname):gsub('%s+$', '')
    self.dateofbirth = tostring(charData.dateofbirth or '1990-01-01')
    self.sex = (charData.sex == 'f') and 'f' or 'm'
    self.height = tonumber(charData.height) or 175
    self.phoneNumber = charData.phone_number
    self.isDead = charData.is_dead == true or charData.is_dead == 1
    self.job = tostring(charData.job or 'unemployed')
    self.jobGrade = tonumber(charData.job_grade) or 0
    self.duty = false
    self.group = tostring(charData.group or 'user')
    self.cash = ReadNonNegativeInteger(charData.cash, (Config and Config.StartingCash) or 2500, 'cash')
    self.bank = ReadNonNegativeInteger(charData.bank, (Config and Config.StartingBank) or 10000, 'bank')
    self.position = type(charData.position) == 'table' and charData.position or { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }
    self.skin = type(charData.skin) == 'table' and charData.skin or {}
    self.metadata = type(charData.metadata) == 'table' and charData.metadata or {}
    self.hunger = 100
    self.thirst = 100

    function self.syncClient()
        TriggerClientEvent('rp_core:client:setPlayerData', self.source, {
            isLoaded = true,
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
            isDead = self.isDead,
            position = self.position,
            skin = self.skin,
            metadata = self.metadata,
            duty = self.duty,
            job = self.job,
            jobLabel = self.job,
            jobGrade = self.jobGrade,
            jobGradeLabel = tostring(self.jobGrade),
            cash = self.cash,
            bank = self.bank,
            group = self.group,
            hunger = self.hunger,
            thirst = self.thirst
        })
    end

    function self.save(force)
        if not AcquireCharacterLock(self.charId) then
            return false
        end
        local ok, result = xpcall(function()
            local positionJson = json.encode(self.position or {})
            local skinJson = json.encode(self.skin or {})
            local metadataJson = json.encode(self.metadata or {})
            MySQL.update.await(
                'UPDATE characters SET cash = ?, bank = ?, job = ?, job_grade = ?, position = ?, skin = ?, metadata = ?, is_dead = ? WHERE id = ? AND identifier = ?',
                {
                    self.cash, self.bank, self.job, self.jobGrade,
                    positionJson, skinJson, metadataJson,
                    self.isDead and 1 or 0,
                    self.charId, self.identifier
                }
            )
            return true
        end, debug.traceback)
        ReleaseCharacterLock(self.charId)
        if not ok then
            print(('[rp_core] Character save failed for %s: %s'):format(tostring(self.charId), tostring(result)))
            return false
        end
        return result == true
    end

    function self.addCash(amount)
        amount = tonumber(amount)
        if not amount or amount < 1 then return false end
        self.cash = self.cash + math.floor(amount)
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        return true
    end

    function self.removeCash(amount)
        amount = tonumber(amount)
        if not amount or amount < 1 or self.cash < amount then return false end
        self.cash = self.cash - math.floor(amount)
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        return true
    end

    function self.addBank(amount)
        amount = tonumber(amount)
        if not amount or amount < 1 then return false end
        self.bank = self.bank + math.floor(amount)
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        return true
    end

    function self.removeBank(amount)
        amount = tonumber(amount)
        if not amount or amount < 1 or self.bank < amount then return false end
        self.bank = self.bank - math.floor(amount)
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        return true
    end

    return self
end

exports('CreateRPPlayer', CreateRPPlayer)

function TransferCash(fromSrc, toSrc, amount)
    amount = tonumber(amount)
    if not amount or amount < 1 or amount % 1 ~= 0 or amount > 1000000 then return false end
    local sender = exports['rp_core']:GetPlayerFromId(fromSrc)
    local recipient = exports['rp_core']:GetPlayerFromId(toSrc)
    if not sender or not recipient then return false end
    if sender.cash < amount then return false end

    if not sender.removeCash(amount) then return false end
    if not recipient.addCash(amount) then
        sender.addCash(amount)
        return false
    end

    local saveOk = sender.save() and recipient.save()
    if not saveOk then
        -- Best-effort rollback of memory state if SQL failed
        sender.addCash(amount)
        recipient.removeCash(amount)
        return false
    end

    TriggerClientEvent('rp_core:client:notify', fromSrc,
        ('Vous avez donné %s$ à %s'):format(amount, recipient.name), 'success')
    TriggerClientEvent('rp_core:client:notify', toSrc,
        ('Vous avez reçu %s$ de %s'):format(amount, sender.name), 'success')
    return true
end

exports('TransferCash', TransferCash)
