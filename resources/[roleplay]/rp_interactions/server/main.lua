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
        actions = {
            { id = 'id_card', label = "Montrer sa carte d'identité", icon = 'fa-id-card' },
            { id = 'driver_license', label = 'Montrer son permis de conduire', icon = 'fa-car' },
            { id = 'billing', label = 'Facturer un service', icon = 'fa-file-invoice' }
        }
    }
    TriggerClientEvent('rp_interactions:openMenu', src, jobName, player.jobGrade or 0, jobData)
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

    if action == 'cuff' then
        if jobName ~= 'police' then return end
        TriggerClientEvent('rp_interactions:toggleCuff', targetId)
        notify(src, 'success', 'Action menottes exécutée.')
        return
    end

    if action == 'revive' or action == 'heal' then
        if jobName ~= 'ambulance' then return end
        notify(targetId, 'success', action == 'revive' and 'Vous avez été réanimé par le SAMU !' or 'Vous avez reçu des soins médicaux.')
        notify(src, 'success', action == 'revive' and 'Patient réanimé avec succès.' or 'Soins administrés au patient.')
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
        local ok, transactionResult = pcall(function()
            return MySQL.transaction.await({
                {
                    query = 'UPDATE characters SET bank = ? WHERE id = ? AND bank >= ?',
                    values = { targetNewBank, target.charId, cost }
                },
                {
                    query = 'UPDATE characters SET bank = ? WHERE id = ?',
                    values = { sourceNewBank, player.charId }
                }
            })
        end)
        if not ok or not transactionResult then
            notify(src, 'error', 'Le paiement a échoué en base de données.')
            return
        end
        target.bank, player.bank = targetNewBank, sourceNewBank
        TriggerClientEvent('rp_core:client:updateBank', targetId, target.bank)
        TriggerClientEvent('rp_core:client:updateBank', src, player.bank)
        TriggerEvent('rp_economy:server:logTransaction', target.charId, action == 'fine' and 'withdraw' or 'withdraw', cost, player.firstname .. ' ' .. player.lastname, action == 'fine' and 'Amende' or 'Facture')
        TriggerEvent('rp_economy:server:logTransaction', player.charId, 'deposit', cost, target.firstname .. ' ' .. target.lastname, action == 'fine' and 'Amende reçue' or 'Facture réglée')
        notify(targetId, 'info', 'Vous avez payé ' .. cost .. ' $.')
        notify(src, 'success', 'Paiement de ' .. cost .. ' $ reçu.')
    end
end)
