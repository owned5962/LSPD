function CreateRPPlayer(source, identifier, charData)
    local self = {}
    self.source = source
    self.identifier = identifier
    self.charId = charData.id or 1
    self.firstname = charData.firstname or 'John'
    self.lastname = charData.lastname or 'Doe'
    self.dateofbirth = charData.dateofbirth or '1995-01-01'
    self.sex = charData.sex or 'm'
    self.cash = tonumber(charData.cash) or Config.StartingCash
    self.bank = tonumber(charData.bank) or Config.StartingBank
    self.job = charData.job or 'unemployed'
    self.jobGrade = tonumber(charData.job_grade) or 0
    self.group = charData.group or 'user'
    self.duty = true

    function self.getCash()
        return self.cash
    end

    function self.addCash(amount)
        if amount <= 0 then return end
        self.cash = self.cash + amount
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        TriggerClientEvent('rp_core:client:notify', self.source, '+ ' .. Utils.FormatCurrency(amount) .. ' (Cash)', 'success')
    end

    function self.removeCash(amount)
        if amount <= 0 or self.cash < amount then return false end
        self.cash = self.cash - amount
        TriggerClientEvent('rp_core:client:updateCash', self.source, self.cash)
        TriggerClientEvent('rp_core:client:notify', self.source, '- ' .. Utils.FormatCurrency(amount) .. ' (Cash)', 'warning')
        return true
    end

    function self.getBank()
        return self.bank
    end

    function self.addBank(amount, reason)
        if amount <= 0 then return end
        self.bank = self.bank + amount
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        TriggerClientEvent('rp_core:client:notify', self.source, '+ ' .. Utils.FormatCurrency(amount) .. ' (Banque)', 'success')
        TriggerEvent('rp_economy:server:logTransaction', self.charId, 'deposit', amount, 'Système', reason or 'Crédit')
    end

    function self.removeBank(amount, reason)
        if amount <= 0 or self.bank < amount then return false end
        self.bank = self.bank - amount
        TriggerClientEvent('rp_core:client:updateBank', self.source, self.bank)
        TriggerClientEvent('rp_core:client:notify', self.source, '- ' .. Utils.FormatCurrency(amount) .. ' (Banque)', 'warning')
        TriggerEvent('rp_economy:server:logTransaction', self.charId, 'withdraw', amount, 'Système', reason or 'Débit')
        return true
    end

    function self.setJob(jobName, grade)
        local jobObj = exports['rp_jobs']:GetJob(jobName)
        if not jobObj then
            jobName = 'unemployed'
            grade = 0
            jobObj = exports['rp_jobs']:GetJob('unemployed')
        end
        local gradeData = exports['rp_jobs']:GetJobGrade(jobName, grade) or { name = 'employe', label = 'Employé', salary = 200 }
        self.job = jobName
        self.jobGrade = grade
        TriggerClientEvent('rp_core:client:setJob', self.source, jobName, jobObj.label, grade, gradeData.label)
        TriggerClientEvent('rp_core:client:notify', self.source, 'Votre métier est désormais: ' .. jobObj.label .. ' (' .. gradeData.label .. ')', 'info')
    end

    function self.save()
        -- Persistence sync hook (MySQL / in-memory)
        TriggerEvent('rp_core:server:onSavePlayer', self)
    end

    function self.syncClient()
        local jobObj = exports['rp_jobs']:GetJob(self.job) or { label = self.job }
        local gradeData = exports['rp_jobs']:GetJobGrade(self.job, self.jobGrade) or { label = 'Grade ' .. self.jobGrade }
        TriggerClientEvent('rp_core:client:setPlayerData', self.source, {
            identifier = self.identifier,
            charId = self.charId,
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
