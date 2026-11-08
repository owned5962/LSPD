function CreateRPPlayer(source, identifier, charData)
    local self = {}
    self.source = tonumber(source)
    self.identifier = identifier
    -- characters.id is the database primary key used by bank_transactions.
    self.charId = tonumber(charData.id) or 1
    self.slot = tonumber(charData.char_id) or 1
    self.firstname = charData.firstname or 'John'
    self.lastname = charData.lastname or 'Doe'
    self.dateofbirth = charData.dateofbirth or '1995-01-01'
    self.sex = charData.sex or 'm'
    self.height = tonumber(charData.height) or 175
    self.cash = tonumber(charData.cash) or Config.StartingCash
    self.bank = tonumber(charData.bank) or Config.StartingBank
    self.job = charData.job or 'unemployed'
    self.jobGrade = tonumber(charData.job_grade) or 0
    self.group = charData.group or 'user'
    self.duty = true

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
        local previousJob, previousGrade = self.job, self.jobGrade
        self.job, self.jobGrade = jobName, grade
        if not self.save() then
            self.job, self.jobGrade = previousJob, previousGrade
            TriggerClientEvent('rp_core:client:notify', self.source, 'Impossible de sauvegarder votre métier. Aucun changement appliqué.', 'error')
            return false
        end
        TriggerClientEvent('rp_core:client:setJob', self.source, jobName, jobObj.label, grade, gradeData.label)
        TriggerClientEvent('rp_core:client:notify', self.source, 'Votre métier est désormais: ' .. jobObj.label .. ' (' .. gradeData.label .. ')', 'info')
        return true
    end

    function self.save()
        local position = self.position or Config.DefaultSpawn
        local ped = GetPlayerPed(self.source)
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

        local ok, result = pcall(MySQL.update.await,
            'UPDATE characters SET cash = ?, bank = ?, job = ?, job_grade = ?, position = ?, skin = ? WHERE id = ? AND identifier = ?',
            {
                self.cash,
                self.bank,
                self.job,
                self.jobGrade,
                json.encode(position),
                json.encode(self.skin or {}),
                self.charId,
                self.identifier
            }
        )

        if not ok then
            print(('[rp_core] SQL save failed for character %s: %s'):format(self.charId, tostring(result)))
            return false
        end
        return result and result > 0
    end

    function self.syncClient()
        local jobObj = exports['rp_jobs']:GetJob(self.job) or { label = self.job }
        local gradeData = exports['rp_jobs']:GetJobGrade(self.job, self.jobGrade) or { label = 'Grade ' .. self.jobGrade }
        TriggerClientEvent('rp_core:client:setPlayerData', self.source, {
            identifier = self.identifier,
            charId = self.charId,
            characterSlot = self.slot,
            firstname = self.firstname,
            lastname = self.lastname,
            cash = self.cash,
            bank = self.bank,
            job = self.job,
            jobLabel = jobObj.label,
            jobGrade = self.jobGrade,
            jobGradeLabel = gradeData.label,
            group = self.group
        })
    end

    return self
end

exports('CreateRPPlayer', CreateRPPlayer)
