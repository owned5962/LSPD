RegisterNetEvent('rp_interactions:requestJobMenu', function()
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    local jobName = player.job or 'unemployed'
    local jobData = Config.JobActions[jobName]

    if not jobData then
        -- Default citizen interactions
        jobData = {
            label = 'Actions Citoyen',
            actions = {
                { id = 'id_card', label = 'Montrer sa carte d\'identité', icon = 'fa-id-card' },
                { id = 'driver_license', label = 'Montrer son permis de conduire', icon = 'fa-car' },
                { id = 'billing', label = 'Facturer un service', icon = 'fa-file-invoice' }
            }
        }
    end

    TriggerClientEvent('rp_interactions:openMenu', src, jobName, player.job_grade or 0, jobData)
end)

RegisterNetEvent('rp_interactions:executeAction', function(targetId, action, amount)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    local target = exports['rp_core']:GetPlayer(targetId)

    if not player or not target then return end

    if action == 'cuff' then
        TriggerClientEvent('rp_interactions:toggleCuff', targetId)
        TriggerClientEvent('rp_core:notify', src, 'info', 'Action menottes exécutée.')
    elseif action == 'revive' then
        TriggerClientEvent('rp_core:notify', targetId, 'success', 'Vous avez été réanimé par le SAMU!')
        TriggerClientEvent('rp_core:notify', src, 'success', 'Patient réanimé avec succès.')
    elseif action == 'heal' then
        TriggerClientEvent('rp_core:notify', targetId, 'success', 'Vous avez reçu des soins médicaux.')
        TriggerClientEvent('rp_core:notify', src, 'success', 'Soins administrés au patient.')
    elseif action == 'billing' or action == 'fine' then
        local cost = tonumber(amount) or 250
        if target.bank >= cost then
            target.bank = target.bank - cost
            player.bank = player.bank + cost
            TriggerClientEvent('rp_core:notify', targetId, 'info', 'Vous avez payé une facture de ' .. cost .. ' $.')
            TriggerClientEvent('rp_core:notify', src, 'success', 'Facture de ' .. cost .. ' $ réglée avec succès.')
        else
            TriggerClientEvent('rp_core:notify', src, 'error', 'Le citoyen n\'a pas assez d\'argent en banque!')
        end
    end
end)
