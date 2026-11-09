local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(tonumber(src))
end

local function notify(src, kind, message)
    TriggerClientEvent('rp_core:client:notify', src, message, kind)
end

local function isNearby(src, targetId, maxDistance)
    local sourcePed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed == 0 or targetPed == 0 then return false end
    return #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) <= (maxDistance or 3.0)
end

local dutyResources = {
    police = 'job_police',
    ambulance = 'job_ambulance',
    mechanic = 'job_mechanic',
    taxi = 'job_taxi',
    towtruck = 'job_towtruck'
}

local function isOnDuty(jobName, src)
    local resource = dutyResources[jobName]
    if not resource or GetResourceState(resource) ~= 'started' then return false end
    local ok, state = pcall(function()
        return exports[resource]:IsOnDuty(src)
    end)
    return ok and state == true
end

local function actionAllowed(jobName, action)
    local jobData = Config.JobActions[jobName]
    if not jobData then return false end
    for _, entry in ipairs(jobData.actions or {}) do
        if entry.id == action then return true end
    end
    return false
end

RegisterNetEvent('rp_interactions:requestJobMenu', function()
    local src = source
    local player = getPlayer(src)
    if not player then return end

    local jobName = player.job or 'unemployed'
    local jobData = Config.JobActions[jobName] or {
        label = 'Actions Citoyen',
        actions = {}
    }
    TriggerClientEvent('rp_interactions:openMenu', src, jobName, player.jobGrade or 0, jobData)
end)

RegisterNetEvent('rp_interactions:executeVehicleAction', function(rawNetId, action)
    local src = source
    local netId = tonumber(rawNetId)
    if not netId or netId % 1 ~= 0 or netId < 1 or type(action) ~= 'string' then return end

    local player = getPlayer(src)
    if not player or not actionAllowed(player.job, action) then
        notify(src, 'error', 'Cette action véhicule n’est pas autorisée pour votre métier.')
        return
    end
    if not isOnDuty(player.job, src) then
        notify(src, 'error', 'Vous devez être en service pour effectuer cette action.')
        return
    end

    local expectedJob = (action == 'repair' or action == 'clean') and 'mechanic'
        or (action == 'impound' and (player.job == 'police' or player.job == 'towtruck') and player.job)
    if not expectedJob or player.job ~= expectedJob then
        notify(src, 'error', 'Action véhicule refusée.')
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(src)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 or ped == 0 then
        notify(src, 'error', 'Véhicule introuvable.')
        return
    end
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 5.0 then
        notify(src, 'error', 'Vous êtes trop loin du véhicule.')
        return
    end

    if action == 'repair' then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
        notify(src, 'success', 'Véhicule réparé.')
    elseif action == 'clean' then
        SetVehicleDirtLevel(vehicle, 0.0)
        notify(src, 'success', 'Véhicule nettoyé.')
    elseif action == 'impound' then
        local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
        for seat = -1, maxPassengers - 1 do
            if GetPedInVehicleSeat(vehicle, seat) ~= 0 then
                notify(src, 'error', 'Impossible de mettre en fourrière un véhicule occupé.')
                return
            end
        end
        DeleteEntity(vehicle)
        notify(src, 'success', 'Véhicule envoyé en fourrière.')
    end
end)

RegisterNetEvent('rp_interactions:executeAction', function(targetId, action, amount)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src or type(action) ~= 'string' then return end

    local player, target = getPlayer(src), getPlayer(targetId)
    if not player or not target or not isNearby(src, targetId, 3.0) then
        notify(src, 'error', 'Joueur introuvable ou trop éloigné.')
        return
    end

    local jobName = player.job or 'unemployed'
    if not actionAllowed(jobName, action) then
        notify(src, 'error', 'Cette action n’est pas autorisée pour votre métier.')
        return
    end
    if dutyResources[jobName] and not isOnDuty(jobName, src) then
        notify(src, 'error', 'Vous devez être en service pour effectuer cette action.')
        return
    end

    if action == 'cuff' then
        if jobName ~= 'police' then return end
        TriggerClientEvent('rp_interactions:toggleCuff', targetId)
        notify(src, 'success', 'Action menottes exécutée.')
        return
    end

    if action == 'revive' or action == 'heal' then
        if jobName ~= 'ambulance' then
            notify(src, 'error', 'Action réservée au SAMU.')
            return
        end
        local targetPed = GetPlayerPed(targetId)
        if targetPed == 0 then return end
        if action == 'revive' and not IsEntityDead(targetPed) then
            notify(src, 'error', 'Ce patient n’est pas inconscient.')
            return
        end
        if action == 'heal' and IsEntityDead(targetPed) then
            notify(src, 'error', 'Ce patient doit être réanimé avant de recevoir des soins.')
            return
        end
        TriggerClientEvent('rp_interactions:medicalAction', targetId, action)
        notify(targetId, 'success', action == 'revive' and 'Vous avez été réanimé par le SAMU.' or 'Vous avez reçu des soins médicaux.')
        notify(src, 'success', action == 'revive' and 'Patient réanimé.' or 'Soins administrés au patient.')
        return
    end

    if action == 'billing' or action == 'fine' then
        local cost = tonumber(amount)
        if not cost or cost % 1 ~= 0 or cost < 1 or cost > 100000 then
            notify(src, 'error', 'Montant invalide (1 à 100 000 $).')
            return
        end
        if action == 'fine' and jobName ~= 'police' then return end
        if action == 'billing' and not (jobName == 'ambulance' or jobName == 'mechanic' or jobName == 'taxi') then
            notify(src, 'error', 'Votre métier ne peut pas émettre cette facture.')
            return
        end
        if (tonumber(target.bank) or 0) < cost then
            notify(src, 'error', 'Le citoyen n’a pas assez d’argent en banque.')
            return
        end
        local targetNewBank = target.bank - cost
        local sourceNewBank = player.bank + cost
        local ok, affectedRows = pcall(MySQL.update.await,
            'UPDATE characters AS sender JOIN characters AS target ON sender.id = ? AND target.id = ? SET sender.bank = sender.bank + ?, target.bank = target.bank - ? WHERE target.bank >= ?',
            { player.charId, target.charId, cost, cost, cost }
        )
        if not ok or tonumber(affectedRows) ~= 2 then
            notify(src, 'error', 'Le paiement a échoué : solde modifié ou sauvegarde indisponible.')
            return
        end
        target.bank, player.bank = targetNewBank, sourceNewBank
        TriggerClientEvent('rp_core:client:updateBank', targetId, target.bank)
        TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
        TriggerEvent('rp_economy:server:logTransaction', target.charId, 'withdraw', cost, player.firstname .. ' ' .. player.lastname, action == 'fine' and 'Amende' or 'Facture')
        TriggerEvent('rp_economy:server:logTransaction', player.charId, 'deposit', cost, target.firstname .. ' ' .. target.lastname, action == 'fine' and 'Amende reçue' or 'Facture réglée')
        notify(targetId, 'info', 'Vous avez payé ' .. cost .. ' $.')
        notify(src, 'success', 'Paiement de ' .. cost .. ' $ reçu.')
    end
end)
