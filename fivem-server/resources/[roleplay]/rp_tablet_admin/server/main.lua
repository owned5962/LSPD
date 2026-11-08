local function IsPlayerAdmin(source)
    if IsPlayerAceAllowed(source, "rp_admin") or IsPlayerAceAllowed(source, "command") then
        return true
    end
    local player = exports['rp_core']:GetPlayerFromId(source)
    if player and (player.group == 'admin' or player.group == 'superadmin') then
        return true
    end
    -- Fallback for standalone local testing: source 1 has admin access
    if source == 1 then
        return true
    end
    return false
end

RegisterNetEvent('rp_tablet_admin:server:requestOpen', function()
    local src = source
    if not IsPlayerAdmin(src) then
        TriggerClientEvent('rp_core:client:notify', src, 'Accès refusé: vous n\'avez pas les permissions administrateur.', 'error')
        return
    end

    local adminPlayer = exports['rp_core']:GetPlayerFromId(src)
    local adminData = {
        name = adminPlayer and (adminPlayer.firstname .. ' ' .. adminPlayer.lastname) or GetPlayerName(src),
        role = adminPlayer and adminPlayer.group or "Administrateur",
        id = src
    }

    local onlinePlayers = {}
    local all = exports['rp_core']:GetAllPlayers()
    for pid, p in pairs(all) do
        table.insert(onlinePlayers, {
            id = pid,
            name = p.firstname .. ' ' .. p.lastname,
            rawName = GetPlayerName(pid) or ('Joueur ' .. pid),
            job = p.job,
            jobLabel = exports['rp_jobs']:GetJob(p.job).label,
            grade = p.jobGrade,
            cash = p.cash,
            bank = p.bank,
            group = p.group
        })
    end

    local jobs = exports['rp_jobs']:GetAllJobs()

    TriggerClientEvent('rp_tablet_admin:client:openAuthorized', src, adminData, onlinePlayers, jobs)
end)

RegisterNetEvent('rp_tablet_admin:server:kickPlayer', function(targetId, reason)
    local src = source
    if not IsPlayerAdmin(src) then return end
    reason = reason or "Expulsé par un administrateur."
    DropPlayer(targetId, "[ADMINISTRATION] " .. reason)
    TriggerClientEvent('rp_core:client:notify', src, 'Joueur ' .. targetId .. ' expulsé.', 'success')
end)

local FrozenPlayers = {}
RegisterNetEvent('rp_tablet_admin:server:freezePlayer', function(targetId, freezeState)
    local src = source
    if not IsPlayerAdmin(src) then return end
    targetId = tonumber(targetId)
    FrozenPlayers[targetId] = freezeState
    TriggerClientEvent('rp_tablet_admin:client:freezeToggle', targetId, freezeState)
    TriggerClientEvent('rp_core:client:notify', src, 'Joueur ' .. targetId .. (freezeState and ' gelé.' or ' dégelé.'), 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:teleportToPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local targetPed = GetPlayerPed(targetId)
    if DoesEntityExist(targetPed) then
        local coords = GetEntityCoords(targetPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', src, coords)
        TriggerClientEvent('rp_core:client:notify', src, 'Téléporté vers le joueur ' .. targetId, 'success')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:bringPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local adminPed = GetPlayerPed(src)
    if DoesEntityExist(adminPed) then
        local coords = GetEntityCoords(adminPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', targetId, coords)
        TriggerClientEvent('rp_core:client:notify', src, 'Joueur ' .. targetId .. ' téléporté sur vous.', 'success')
        TriggerClientEvent('rp_core:client:notify', targetId, 'Vous avez été téléporté par un administrateur.', 'info')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:revivePlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    TriggerClientEvent('rp_tablet_admin:client:revive', targetId)
    TriggerClientEvent('rp_core:client:notify', src, 'Joueur ' .. targetId .. ' réanimé.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:manageEconomy', function(targetId, moneyType, amount, operation)
    local src = source
    if not IsPlayerAdmin(src) then return end
    targetId = tonumber(targetId)
    amount = tonumber(amount)
    if not targetId or not amount or amount <= 0 then return end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        TriggerClientEvent('rp_core:client:notify', src, 'Joueur introuvable.', 'error')
        return
    end

    if operation == 'give' then
        if moneyType == 'cash' then
            target.addCash(amount)
        else
            target.addBank(amount, 'Donation Administrative')
        end
        TriggerClientEvent('rp_core:client:notify', src, 'Ajouté ' .. amount .. ' $ (' .. moneyType .. ') au joueur ' .. targetId, 'success')
    elseif operation == 'remove' then
        if moneyType == 'cash' then
            target.removeCash(amount)
        else
            target.removeBank(amount, 'Saisie Administrative')
        end
        TriggerClientEvent('rp_core:client:notify', src, 'Retiré ' .. amount .. ' $ (' .. moneyType .. ') au joueur ' .. targetId, 'warning')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:setJob', function(targetId, jobName, grade)
    local src = source
    if not IsPlayerAdmin(src) then return end
    targetId = tonumber(targetId)
    grade = tonumber(grade) or 0

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        TriggerClientEvent('rp_core:client:notify', src, 'Joueur introuvable.', 'error')
        return
    end

    target.setJob(jobName, grade)
    TriggerClientEvent('rp_core:client:notify', src, 'Métier du joueur ' .. targetId .. ' défini sur ' .. jobName .. ' (Grade ' .. grade .. ')', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setWeatherTime', function(weather, hours, minutes)
    local src = source
    if not IsPlayerAdmin(src) then return end
    if weather and weather ~= '' then
        TriggerClientEvent('rp_tablet_admin:client:syncWeather', -1, weather)
    end
    if hours ~= nil and minutes ~= nil then
        TriggerClientEvent('rp_tablet_admin:client:syncTime', -1, hours, minutes)
    end
    TriggerClientEvent('rp_core:client:notify', src, 'Météo / Heure synchronisée sur le serveur.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:broadcastAnnouncement', function(message)
    local src = source
    if not IsPlayerAdmin(src) then return end
    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 69, 0},
        args = {"[ANNONCE ADMIN]", message}
    })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE: ' .. message, 'warning')
end)
