local sessions = {}
local lastStart = {}

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function playerAtSchool(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    return #(GetEntityCoords(ped) - Config.School.coords) <= Config.ServerDistance
end

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(src)
end

local function validCategory(category)
    return type(category) == 'string' and Config.Categories[category] or nil
end

local function clearSession(src, message, kind)
    sessions[src] = nil
    if message then notify(src, message, kind) end
end

RegisterNetEvent('rp_drivingschool:server:requestLicenses', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'drivingschool:licenses', 1000) then return end
    local player = getPlayer(src)
    if not player then return end
    local rows = MySQL.query.await('SELECT category, issued_at FROM rp_driving_licenses WHERE character_id = ? AND identifier = ?', {
        player.charId, player.identifier
    }) or {}
    TriggerClientEvent('rp_drivingschool:client:licenses', src, rows)
end)

RegisterNetEvent('rp_drivingschool:server:startTheory', function(category)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'drivingschool:start', Config.TheoryCooldown) then return end
    local player, definition = getPlayer(src), validCategory(category)
    if not player or not definition or not playerAtSchool(src) then
        notify(src, 'Approchez-vous du comptoir de l’auto-école.', 'error')
        return
    end
    if sessions[src] then notify(src, 'Un examen est déjà en cours.', 'warning'); return end

    local already = MySQL.scalar.await(
        'SELECT 1 FROM rp_driving_licenses WHERE character_id = ? AND identifier = ? AND category = ? LIMIT 1',
        { player.charId, player.identifier, category }
    )
    if already then notify(src, 'Vous possédez déjà ce permis.', 'info'); return end
    if (tonumber(player.bank) or 0) < definition.price then
        notify(src, 'Solde bancaire insuffisant pour cet examen.', 'error')
        return
    end
    if type(player.removeBank) ~= 'function' or player.removeBank(definition.price, 'Inscription auto-école - ' .. definition.label, 'withdraw') ~= true then
        notify(src, 'Le paiement de l’inscription a échoué.', 'error')
        return
    end

    sessions[src] = {
        category = category,
        characterId = player.charId,
        identifier = player.identifier,
        phase = 'theory',
        expiresAt = os.time() + Config.ExamTimeout
    }
    local publicQuestions = {}
    for index, question in ipairs(definition.questions) do
        publicQuestions[index] = { q = question.q, a = question.a }
    end
    TriggerClientEvent('rp_drivingschool:client:theory', src, category, definition.label, publicQuestions)
end)

RegisterNetEvent('rp_drivingschool:server:submitTheory', function(rawAnswers)
    local src = source
    local session = sessions[src]
    local player = getPlayer(src)
    if not session or session.phase ~= 'theory' or not player
        or player.charId ~= session.characterId or player.identifier ~= session.identifier
        or os.time() > session.expiresAt or type(rawAnswers) ~= 'table' then
        clearSession(src, 'Session théorique invalide ou expirée.', 'error')
        return
    end

    local questions = Config.Categories[session.category].questions
    if #rawAnswers ~= #questions then clearSession(src, 'Réponses invalides.', 'error'); return end
    local score = 0
    for i, question in ipairs(questions) do
        local answer = tonumber(rawAnswers[i])
        if not answer or answer % 1 ~= 0 or answer < 1 or answer > #question.a then
            clearSession(src, 'Réponses invalides.', 'error')
            return
        end
        if answer == question.correct then score = score + 1 end
    end
    if score < Config.PassMark then
        clearSession(src, ('Examen théorique échoué : %d/%d. Vous pourrez vous réinscrire.'):format(score, #questions), 'error')
        return
    end

    session.phase = 'practical'
    local definition = Config.Categories[session.category]
    TriggerClientEvent('rp_drivingschool:client:startPractical', src, {
        category = session.category,
        model = definition.model,
        spawn = { x = definition.spawn.x, y = definition.spawn.y, z = definition.spawn.z, w = definition.spawn.w },
        checkpoints = (function()
            local result = {}
            for _, point in ipairs(definition.checkpoints) do
                result[#result + 1] = { x = point.x, y = point.y, z = point.z }
            end
            return result
        end)()
    })
    notify(src, 'Théorie validée ! Rendez-vous au véhicule pour l’épreuve pratique.', 'success')
end)

RegisterNetEvent('rp_drivingschool:server:practicalStarted', function(netId)
    local src = source
    local session = sessions[src]
    local player = getPlayer(src)
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local definition = session and Config.Categories[session.category]
    if not session or session.phase ~= 'practical' or not player or not definition
        or player.charId ~= session.characterId or player.identifier ~= session.identifier
        or not entity or entity == 0 or not DoesEntityExist(entity)
        or NetworkGetEntityOwner(entity) ~= src
        or GetEntityModel(entity) ~= GetHashKey(definition.model)
        or #(GetEntityCoords(entity) - vector3(definition.spawn.x, definition.spawn.y, definition.spawn.z)) > 20.0
        or GetPedInVehicleSeat(entity, -1) ~= GetPlayerPed(src) then
        clearSession(src, 'Impossible de valider le véhicule d’examen.', 'error')
        TriggerClientEvent('rp_drivingschool:client:examFailed', src)
        return
    end
    session.netId = tonumber(netId)
    session.nextCheckpoint = 1
    session.expiresAt = os.time() + Config.ExamTimeout
    TriggerClientEvent('rp_drivingschool:client:checkpoint', src, 1, #definition.checkpoints)
end)

RegisterNetEvent('rp_drivingschool:server:checkpointReached', function(index)
    local src = source
    local session = sessions[src]
    local player = getPlayer(src)
    local definition = session and Config.Categories[session.category]
    local expected = session and definition and definition.checkpoints[session.nextCheckpoint]
    local entity = session and NetworkGetEntityFromNetworkId(session.netId or 0)
    local ped = GetPlayerPed(src)
    if not session or session.phase ~= 'practical' or not player or not expected
        or player.charId ~= session.characterId or player.identifier ~= session.identifier
        or os.time() > session.expiresAt or tonumber(index) ~= session.nextCheckpoint
        or not entity or entity == 0 or not DoesEntityExist(entity)
        or NetworkGetEntityOwner(entity) ~= src or GetPedInVehicleSeat(entity, -1) ~= ped
        or GetEntityModel(entity) ~= GetHashKey(definition.model)
        or #(GetEntityCoords(ped) - expected) > Config.CheckpointRadius then
        clearSession(src, 'Épreuve pratique interrompue ou checkpoint invalide.', 'error')
        TriggerClientEvent('rp_drivingschool:client:examFailed', src)
        return
    end

    session.nextCheckpoint = session.nextCheckpoint + 1
    if session.nextCheckpoint <= #definition.checkpoints then
        TriggerClientEvent('rp_drivingschool:client:checkpoint', src, session.nextCheckpoint, #definition.checkpoints)
        return
    end

    local ok, result = pcall(MySQL.insert.await,
        'INSERT IGNORE INTO rp_driving_licenses (character_id, identifier, category) VALUES (?, ?, ?)',
        { player.charId, player.identifier, session.category })
    sessions[src] = nil
    if not ok or not result or result < 1 then
        print(('[rp_drivingschool] License persistence failed for character %s (%s): %s')
            :format(tostring(player.charId), session.category, tostring(result)))
        notify(src, 'Examen réussi, mais la sauvegarde du permis a échoué. Contactez un administrateur.', 'error')
        TriggerClientEvent('rp_drivingschool:client:examFailed', src)
        return
    end
    TriggerClientEvent('rp_drivingschool:client:examPassed', src, session.category)
    notify(src, 'Félicitations ! Votre ' .. definition.label .. ' est obtenu et enregistré.', 'success')
end)

RegisterNetEvent('rp_drivingschool:server:cancelExam', function()
    local src = source
    if sessions[src] then clearSession(src, 'Examen annulé.', 'warning') end
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastStart[source] = nil
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for src, session in pairs(sessions) do
            if now > session.expiresAt then clearSession(src, 'Votre examen a expiré.', 'error') end
        end
    end
end)
