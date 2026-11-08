PlayerData = {
    identifier = nil,
    charId = nil,
    firstname = '',
    lastname = '',
    job = 'unemployed',
    jobLabel = 'Sans-emploi',
    jobGrade = 0,
    jobGradeLabel = 'Demandeur',
    cash = 0,
    bank = 0,
    group = 'user'
}

RegisterNetEvent('rp_core:client:setPlayerData', function(data)
    for k, v in pairs(data) do
        PlayerData[k] = v
    end
end)

RegisterNetEvent('rp_core:client:updateCash', function(amount)
    PlayerData.cash = amount
end)

RegisterNetEvent('rp_core:client:updateBank', function(amount)
    PlayerData.bank = amount
end)

RegisterNetEvent('rp_core:client:setJob', function(job, label, grade, gradeLabel)
    PlayerData.job = job
    PlayerData.jobLabel = label
    PlayerData.jobGrade = grade
    PlayerData.jobGradeLabel = gradeLabel
end)

exports('GetPlayerData', function()
    return PlayerData
end)
