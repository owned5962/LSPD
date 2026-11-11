local function IsPlayerAdmin(source)
    if IsPlayerAceAllowed(source, "rp_admin") then
        return true
    end

    local player = exports['rp_core']:GetPlayerFromId(source)
    return player ~= nil and (player.group == 'admin' or player.group == 'superadmin')
end

local function AllowAdminAction(src, action, cooldown)
    return IsPlayerAdmin(src) and exports['rp_core']:CanPerformAction(src, 'admin:' .. action, cooldown or 500)
end

local function BuildOnlinePlayers(requestingAdminId)
    local onlinePlayers, seen = {}, {}
    local function AddOnlinePlayer(rawId)
        local id = tonumber(rawId)
        if not id or id < 1 or seen[id] then return end
        local rawName = GetPlayerName(id)
        if not rawName then return end
        local player = exports['rp_core']:GetPlayerFromId(id)
        local ped = GetPlayerPed(id)
        local position
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            position = { x = coords.x, y = coords.y, z = coords.z }
        end
        local first = player and tostring(player.firstname or '') or ''
        local last = player and tostring(player.lastname or '') or ''
        local name = (first .. ' ' .. last):gsub('^%s*(.-)%s*

local function GetOnlineTargetId(value)
    local targetId = tonumber(value)
    if not targetId or targetId < 1 or targetId % 1 ~= 0 or not GetPlayerName(targetId) then
        return nil
    end
    return targetId
end

local function NotifyAdmin(source, message, kind)
    TriggerClientEvent('rp_core:client:notify', source, message, kind or 'error')
end

RegisterNetEvent('rp_tablet_admin:server:requestOpen', function()
    local src = source
    if not AllowAdminAction(src, 'open', 1000) then
        NotifyAdmin(src, "Accès refusé ou ouverture trop rapide.")
        return
    end

    local adminPlayer = exports['rp_core']:GetPlayerFromId(src)
    local adminData = {
        name = adminPlayer and ((adminPlayer.firstname or '') .. ' ' .. (adminPlayer.lastname or '')) or (GetPlayerName(src) or 'Administrateur'),
        role = adminPlayer and adminPlayer.group or "Administrateur",
        id = src
    }

    local onlinePlayers = BuildOnlinePlayers(src)

    local jobs = exports['rp_jobs']:GetAllJobs()
    local frozenPlayers = {}
    for targetId, frozen in pairs(FrozenPlayers) do if frozen and GetPlayerName(targetId) then frozenPlayers[#frozenPlayers + 1] = targetId end end
    TriggerClientEvent('rp_tablet_admin:client:openAuthorized', src, adminData, onlinePlayers, jobs, frozenPlayers)
end)

RegisterNetEvent('rp_tablet_admin:server:kickPlayer', function(targetId, reason)
    local src = source
    if not AllowAdminAction(src, 'kick', 500) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    if type(reason) ~= 'string' then reason = 'Expulsé par un administrateur.' end
    reason = reason:gsub('[%c]', ' '):sub(1, 120)
    if reason == '' then reason = 'Expulsé par un administrateur.' end

    DropPlayer(targetId, '[ADMINISTRATION] ' .. reason)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' expulsé.', 'success')
end)

local FrozenPlayers = {}
RegisterNetEvent('rp_tablet_admin:server:freezePlayer', function(targetId, freezeState)
    local src = source
    if not AllowAdminAction(src, 'freeze', 500) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or type(freezeState) ~= 'boolean' then
        NotifyAdmin(src, 'Paramètres de gel invalides.')
        return
    end

    FrozenPlayers[targetId] = freezeState
    TriggerClientEvent('rp_tablet_admin:client:freezeToggle', targetId, freezeState)
    NotifyAdmin(src, 'Joueur ' .. targetId .. (freezeState and ' gelé.' or ' dégelé.'), 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:teleportToPlayer', function(targetId)
    local src = source
    if not AllowAdminAction(src, 'goto', 500) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
        local coords = GetEntityCoords(targetPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', src, coords)
        NotifyAdmin(src, 'Téléporté vers le joueur ' .. targetId, 'success')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:bringPlayer', function(targetId)
    local src = source
    if not AllowAdminAction(src, 'bring', 500) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    local adminPed = GetPlayerPed(src)
    if adminPed and adminPed ~= 0 and DoesEntityExist(adminPed) then
        local coords = GetEntityCoords(adminPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', targetId, coords)
        NotifyAdmin(src, 'Joueur ' .. targetId .. ' téléporté sur vous.', 'success')
        NotifyAdmin(targetId, 'Vous avez été téléporté par un administrateur.', 'info')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:revivePlayer', function(targetId)
    local src = source
    if not AllowAdminAction(src, 'revive', 500) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    TriggerClientEvent('rp_tablet_admin:client:revive', targetId)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' réanimé.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:manageEconomy', function(targetId, moneyType, amount, operation)
    local src = source
    if not AllowAdminAction(src, 'economy', 1000) then return end

    targetId = GetOnlineTargetId(targetId)
    amount = tonumber(amount)
    if not targetId or not amount or amount % 1 ~= 0 or amount < 1 or amount > 1000000 then
        NotifyAdmin(src, 'Montant ou joueur invalide (montant maximum : 1 000 000).')
        return
    end
    if moneyType ~= 'cash' and moneyType ~= 'bank' then
        NotifyAdmin(src, 'Type de compte invalide.')
        return
    end
    if operation ~= 'give' and operation ~= 'remove' then
        NotifyAdmin(src, 'Opération économique invalide.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    local succeeded = false
    if operation == 'give' then
        if moneyType == 'cash' then
            target.addCash(amount)
        else
            target.addBank(amount, 'Donation Administrative')
        end
        succeeded = true
    elseif moneyType == 'cash' then
        succeeded = target.removeCash(amount)
    else
        succeeded = target.removeBank(amount, 'Saisie Administrative')
    end

    if not succeeded then
        NotifyAdmin(src, 'Fonds insuffisants : opération annulée.')
        return
    end

    NotifyAdmin(src, (operation == 'give' and 'Ajouté ' or 'Retiré ') .. amount .. ' $ (' .. moneyType .. ') au joueur ' .. targetId, 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setJob', function(targetId, jobName, grade)
    local src = source
    if not AllowAdminAction(src, 'setjob', 500) then return end

    targetId = GetOnlineTargetId(targetId)
    grade = tonumber(grade)
    if not targetId or type(jobName) ~= 'string' or #jobName > 50 or not grade or grade < 0 or grade % 1 ~= 0 then
        NotifyAdmin(src, 'Paramètres de métier invalides.')
        return
    end

    local selectedJob
    for _, job in ipairs(exports['rp_jobs']:GetAllJobs()) do
        if job.name == jobName then
            selectedJob = job
            break
        end
    end
    if not selectedJob or not selectedJob.grades or not selectedJob.grades[grade] then
        NotifyAdmin(src, 'Métier ou grade inexistant.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    target.setJob(jobName, grade)
    NotifyAdmin(src, 'Métier du joueur ' .. targetId .. ' défini sur ' .. jobName .. ' (Grade ' .. grade .. ')', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setWeatherTime', function(weather, hours, minutes)
    local src = source
    if not AllowAdminAction(src, 'world', 500) then return end

    local allowedWeather = {
        EXTRASUNNY = true, CLEAR = true, CLOUDS = true, SMOG = true,
        FOGGY = true, OVERCAST = true, RAIN = true, THUNDER = true,
        CLEARING = true, NEUTRAL = true, SNOW = true, BLIZZARD = true,
        SNOWLIGHT = true, XMAS = true, HALLOWEEN = true
    }

    if weather ~= nil and weather ~= '' then
        if type(weather) ~= 'string' or not allowedWeather[weather] then
            NotifyAdmin(src, 'Météo invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncWeather', -1, weather)
    end

    if hours ~= nil or minutes ~= nil then
        hours = tonumber(hours)
        minutes = tonumber(minutes)
        if not hours or not minutes or hours % 1 ~= 0 or minutes % 1 ~= 0 or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then
            NotifyAdmin(src, 'Heure invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncTime', -1, hours, minutes)
    end

    NotifyAdmin(src, 'Météo / heure synchronisée sur le serveur.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:broadcastAnnouncement', function(message)
    local src = source
    if not AllowAdminAction(src, 'broadcast', 500) then return end

    if type(message) ~= 'string' then
        NotifyAdmin(src, 'Annonce invalide.')
        return
    end
    message = message:gsub('[%c]', ' '):sub(1, 500)
    if message == '' then
        NotifyAdmin(src, 'L’annonce ne peut pas être vide.')
        return
    end

    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 69, 0},
        args = {'[ANNONCE ADMIN]', message}
    })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'warning')
end)
, '%1')
            if name == '' then name = rawName end
            local jobName = player and player.job or 'unemployed'
            local job = exports['rp_jobs']:GetJob(jobName)
            local ped = GetPlayerPed(pid)
            local position
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                position = { x = coords.x, y = coords.y, z = coords.z }
            end
            onlinePlayers[#onlinePlayers + 1] = {
                id = pid, name = name, rawName = rawName, isSelf = pid == src, position = position,
                job = jobName, jobLabel = job and job.label or jobName,
                grade = player and player.jobGrade or 0, cash = player and player.cash or 0,
                bank = player and player.bank or 0, group = player and player.group or 'user',
                ping = GetPlayerPing(pid)
            }
            seen[pid] = true
        end
    end
    if not seen[src] and GetPlayerName(src) then
        onlinePlayers[#onlinePlayers + 1] = { id = src, name = GetPlayerName(src), rawName = GetPlayerName(src), isSelf = true }
    end
    table.sort(onlinePlayers, function(a, b) return a.id < b.id end)

    local jobs = exports['rp_jobs']:GetAllJobs()
    TriggerClientEvent('rp_tablet_admin:client:openAuthorized', src, adminData, onlinePlayers, jobs)
end)

RegisterNetEvent('rp_tablet_admin:server:kickPlayer', function(targetId, reason)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    if type(reason) ~= 'string' then reason = 'Expulsé par un administrateur.' end
    reason = reason:gsub('[%c]', ' '):sub(1, 120)
    if reason == '' then reason = 'Expulsé par un administrateur.' end

    DropPlayer(targetId, '[ADMINISTRATION] ' .. reason)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' expulsé.', 'success')
end)

local FrozenPlayers = {}
RegisterNetEvent('rp_tablet_admin:server:freezePlayer', function(targetId, freezeState)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or type(freezeState) ~= 'boolean' then
        NotifyAdmin(src, 'Paramètres de gel invalides.')
        return
    end

    FrozenPlayers[targetId] = freezeState
    TriggerClientEvent('rp_tablet_admin:client:freezeToggle', targetId, freezeState)
    NotifyAdmin(src, 'Joueur ' .. targetId .. (freezeState and ' gelé.' or ' dégelé.'), 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:teleportToPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
        local coords = GetEntityCoords(targetPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', src, coords)
        NotifyAdmin(src, 'Téléporté vers le joueur ' .. targetId, 'success')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:bringPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    local adminPed = GetPlayerPed(src)
    if adminPed and adminPed ~= 0 and DoesEntityExist(adminPed) then
        local coords = GetEntityCoords(adminPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', targetId, coords)
        NotifyAdmin(src, 'Joueur ' .. targetId .. ' téléporté sur vous.', 'success')
        NotifyAdmin(targetId, 'Vous avez été téléporté par un administrateur.', 'info')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:revivePlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    TriggerClientEvent('rp_tablet_admin:client:revive', targetId)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' réanimé.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:manageEconomy', function(targetId, moneyType, amount, operation)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    amount = tonumber(amount)
    if not targetId or not amount or amount % 1 ~= 0 or amount < 1 or amount > 1000000 then
        NotifyAdmin(src, 'Montant ou joueur invalide (montant maximum : 1 000 000).')
        return
    end
    if moneyType ~= 'cash' and moneyType ~= 'bank' then
        NotifyAdmin(src, 'Type de compte invalide.')
        return
    end
    if operation ~= 'give' and operation ~= 'remove' then
        NotifyAdmin(src, 'Opération économique invalide.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    local succeeded = false
    if operation == 'give' then
        if moneyType == 'cash' then
            target.addCash(amount)
        else
            target.addBank(amount, 'Donation Administrative')
        end
        succeeded = true
    elseif moneyType == 'cash' then
        succeeded = target.removeCash(amount)
    else
        succeeded = target.removeBank(amount, 'Saisie Administrative')
    end

    if not succeeded then
        NotifyAdmin(src, 'Fonds insuffisants : opération annulée.')
        return
    end

    NotifyAdmin(src, (operation == 'give' and 'Ajouté ' or 'Retiré ') .. amount .. ' $ (' .. moneyType .. ') au joueur ' .. targetId, 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setJob', function(targetId, jobName, grade)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    grade = tonumber(grade)
    if not targetId or type(jobName) ~= 'string' or #jobName > 50 or not grade or grade < 0 or grade % 1 ~= 0 then
        NotifyAdmin(src, 'Paramètres de métier invalides.')
        return
    end

    local selectedJob
    for _, job in ipairs(exports['rp_jobs']:GetAllJobs()) do
        if job.name == jobName then
            selectedJob = job
            break
        end
    end
    if not selectedJob or not selectedJob.grades or not selectedJob.grades[grade] then
        NotifyAdmin(src, 'Métier ou grade inexistant.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    target.setJob(jobName, grade)
    NotifyAdmin(src, 'Métier du joueur ' .. targetId .. ' défini sur ' .. jobName .. ' (Grade ' .. grade .. ')', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setWeatherTime', function(weather, hours, minutes)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local allowedWeather = {
        EXTRASUNNY = true, CLEAR = true, CLOUDS = true, SMOG = true,
        FOGGY = true, OVERCAST = true, RAIN = true, THUNDER = true,
        CLEARING = true, NEUTRAL = true, SNOW = true, BLIZZARD = true,
        SNOWLIGHT = true, XMAS = true, HALLOWEEN = true
    }

    if weather ~= nil and weather ~= '' then
        if type(weather) ~= 'string' or not allowedWeather[weather] then
            NotifyAdmin(src, 'Météo invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncWeather', -1, weather)
    end

    if hours ~= nil or minutes ~= nil then
        hours = tonumber(hours)
        minutes = tonumber(minutes)
        if not hours or not minutes or hours % 1 ~= 0 or minutes % 1 ~= 0 or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then
            NotifyAdmin(src, 'Heure invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncTime', -1, hours, minutes)
    end

    NotifyAdmin(src, 'Météo / heure synchronisée sur le serveur.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:broadcastAnnouncement', function(message)
    local src = source
    if not IsPlayerAdmin(src) then return end

    if type(message) ~= 'string' then
        NotifyAdmin(src, 'Annonce invalide.')
        return
    end
    message = message:gsub('[%c]', ' '):sub(1, 500)
    if message == '' then
        NotifyAdmin(src, 'L’annonce ne peut pas être vide.')
        return
    end

    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 69, 0},
        args = {'[ANNONCE ADMIN]', message}
    })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'warning')
end)


RegisterNetEvent('rp_tablet_admin:server:requestPlayerPositions', function()
    local src = source
    if not AllowAdminAction(src, 'positions', 1800) then return end
    TriggerClientEvent('rp_tablet_admin:client:playerPositions', src, BuildOnlinePlayers(src))
end)

RegisterNetEvent('rp_tablet_admin:server:requestAuditLogs', function()
    local src = source
    if not AllowAdminAction(src, 'audit_logs', 2000) then return end
    local ok, logs = pcall(MySQL.query.await,
        'SELECT admin_name, action, target_identifier, details, created_at FROM admin_logs ORDER BY id DESC LIMIT 50')
    if not ok then NotifyAdmin(src, 'Impossible de charger les journaux administrateur.'); return end
    TriggerClientEvent('rp_tablet_admin:client:auditLogs', src, logs or {})
end)

RegisterNetEvent('rp_tablet_admin:server:spectatePlayer', function(targetId)
    local src = source
    if not AllowAdminAction(src, 'spectate', 500) then return end
    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then NotifyAdmin(src, 'Cible invalide pour la surveillance.'); return end
    TriggerClientEvent('rp_tablet_admin:client:startSpectate', src, targetId)
end)
RegisterNetEvent('rp_tablet_admin:server:stopSpectate', function()
    local src = source
    if IsPlayerAdmin(src) then TriggerClientEvent('rp_tablet_admin:client:stopSpectate', src) end
end)
RegisterNetEvent('rp_tablet_admin:server:toggleNoclip', function()
    local src = source
    if IsPlayerAdmin(src) then TriggerClientEvent('rp_tablet_admin:client:toggleNoclip', src) end
end)
RegisterNetEvent('rp_tablet_admin:server:toggleGodmode', function()
    local src = source
    if IsPlayerAdmin(src) then TriggerClientEvent('rp_tablet_admin:client:toggleGodmode', src) end
end)
RegisterNetEvent('rp_tablet_admin:server:spawnVehicle', function(model)
    local src = source
    if not AllowAdminAction(src, 'spawn_vehicle', 1000) then return end
    if type(model) ~= 'string' or #model < 2 or #model > 40 or not model:match('^[%w_]+$') then NotifyAdmin(src, 'Modèle de véhicule invalide.'); return end
    TriggerClientEvent('rp_tablet_admin:client:spawnVehicle', src, model)
end)
RegisterNetEvent('rp_tablet_admin:server:banPlayer', function(targetId, rawReason)
    local src = source
    if not AllowAdminAction(src, 'ban', 1500) then return end
    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then NotifyAdmin(src, 'Joueur cible invalide.'); return end
    local reason = type(rawReason) == 'string' and rawReason:gsub('[%c]', ' '):sub(1, 180) or ''
    if reason == '' then NotifyAdmin(src, 'Un motif de bannissement est obligatoire.'); return end
    local license
    for _, identifier in ipairs(GetPlayerIdentifiers(targetId)) do if identifier:sub(1, 8) == 'license:' then license = identifier; break end end
    if not license then NotifyAdmin(src, 'Identifiant license introuvable.'); return end
    local ok, err = pcall(function()
        MySQL.insert.await('INSERT INTO player_bans (identifier, reason, banned_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), created_at = CURRENT_TIMESTAMP',
            { license, reason, 'server:' .. tostring(src) })
    end)
    if not ok then print('[rp_tablet_admin] Ban SQL error: ' .. tostring(err)); NotifyAdmin(src, 'Erreur SQL : bannissement annulé.'); return end
    DropPlayer(targetId, '[ADMINISTRATION - BAN PERMANENT] ' .. reason)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' banni durablement.', 'success')
end)
RegisterNetEvent('rp_tablet_admin:server:healPlayer', function(targetId)
    local src = source
    if not AllowAdminAction(src, 'heal', 500) then return end
    targetId = GetOnlineTargetId(targetId)
    if not targetId then NotifyAdmin(src, 'Joueur cible introuvable.'); return end
    TriggerClientEvent('rp_tablet_admin:client:heal', targetId)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' soigné.', 'success')
end)
, '%1')
        if name == '' then name = rawName end
        local jobName = player and player.job or 'unemployed'
        local job = exports['rp_jobs']:GetJob(jobName)
        onlinePlayers[#onlinePlayers + 1] = {
            id = id, name = name, rawName = rawName, isSelf = id == tonumber(requestingAdminId),
            position = position, job = jobName, jobLabel = job and job.label or jobName,
            grade = player and player.jobGrade or 0, cash = player and player.cash or 0,
            bank = player and player.bank or 0, group = player and player.group or 'user',
            ping = GetPlayerPing(id)
        }
        seen[id] = true
    end
    for _, rawId in pairs(GetPlayers()) do AddOnlinePlayer(rawId) end
    AddOnlinePlayer(requestingAdminId)
    table.sort(onlinePlayers, function(a, b) return a.id < b.id end)
    print(('[rp_tablet_admin] Player snapshot for admin %s: %d online player(s), self=%s'):format(
        tostring(requestingAdminId), #onlinePlayers, tostring(seen[tonumber(requestingAdminId)] == true)))
    return onlinePlayers
end

local function GetOnlineTargetId(value)
    local targetId = tonumber(value)
    if not targetId or targetId < 1 or targetId % 1 ~= 0 or not GetPlayerName(targetId) then
        return nil
    end
    return targetId
end

local function NotifyAdmin(source, message, kind)
    TriggerClientEvent('rp_core:client:notify', source, message, kind or 'error')
end

RegisterNetEvent('rp_tablet_admin:server:requestOpen', function()
    local src = source
    if not IsPlayerAdmin(src) then
        NotifyAdmin(src, "Accès refusé : permissions administrateur requises.")
        return
    end

    local adminPlayer = exports['rp_core']:GetPlayerFromId(src)
    local adminData = {
        name = adminPlayer and ((adminPlayer.firstname or '') .. ' ' .. (adminPlayer.lastname or '')) or (GetPlayerName(src) or 'Administrateur'),
        role = adminPlayer and adminPlayer.group or "Administrateur",
        id = src
    }

    local onlinePlayers, seen = {}, {}
    for _, rawId in pairs(GetPlayers()) do
        local pid = tonumber(rawId)
        if pid and not seen[pid] then
            local player = exports['rp_core']:GetPlayerFromId(pid)
            local rawName = GetPlayerName(pid) or ('Joueur ' .. pid)
            local first = player and tostring(player.firstname or '') or ''
            local last = player and tostring(player.lastname or '') or ''
            local name = (first .. ' ' .. last):gsub('^%s*(.-)%s*

    local jobs = exports['rp_jobs']:GetAllJobs()
    local frozenPlayers = {}
    for targetId, frozen in pairs(FrozenPlayers) do if frozen and GetPlayerName(targetId) then frozenPlayers[#frozenPlayers + 1] = targetId end end
    TriggerClientEvent('rp_tablet_admin:client:openAuthorized', src, adminData, onlinePlayers, jobs, frozenPlayers)
end)

RegisterNetEvent('rp_tablet_admin:server:kickPlayer', function(targetId, reason)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    if type(reason) ~= 'string' then reason = 'Expulsé par un administrateur.' end
    reason = reason:gsub('[%c]', ' '):sub(1, 120)
    if reason == '' then reason = 'Expulsé par un administrateur.' end

    DropPlayer(targetId, '[ADMINISTRATION] ' .. reason)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' expulsé.', 'success')
end)

local FrozenPlayers = {}
RegisterNetEvent('rp_tablet_admin:server:freezePlayer', function(targetId, freezeState)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or type(freezeState) ~= 'boolean' then
        NotifyAdmin(src, 'Paramètres de gel invalides.')
        return
    end

    FrozenPlayers[targetId] = freezeState
    TriggerClientEvent('rp_tablet_admin:client:freezeToggle', targetId, freezeState)
    NotifyAdmin(src, 'Joueur ' .. targetId .. (freezeState and ' gelé.' or ' dégelé.'), 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:teleportToPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
        local coords = GetEntityCoords(targetPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', src, coords)
        NotifyAdmin(src, 'Téléporté vers le joueur ' .. targetId, 'success')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:bringPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    local adminPed = GetPlayerPed(src)
    if adminPed and adminPed ~= 0 and DoesEntityExist(adminPed) then
        local coords = GetEntityCoords(adminPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', targetId, coords)
        NotifyAdmin(src, 'Joueur ' .. targetId .. ' téléporté sur vous.', 'success')
        NotifyAdmin(targetId, 'Vous avez été téléporté par un administrateur.', 'info')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:revivePlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    TriggerClientEvent('rp_tablet_admin:client:revive', targetId)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' réanimé.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:manageEconomy', function(targetId, moneyType, amount, operation)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    amount = tonumber(amount)
    if not targetId or not amount or amount % 1 ~= 0 or amount < 1 or amount > 1000000 then
        NotifyAdmin(src, 'Montant ou joueur invalide (montant maximum : 1 000 000).')
        return
    end
    if moneyType ~= 'cash' and moneyType ~= 'bank' then
        NotifyAdmin(src, 'Type de compte invalide.')
        return
    end
    if operation ~= 'give' and operation ~= 'remove' then
        NotifyAdmin(src, 'Opération économique invalide.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    local succeeded = false
    if operation == 'give' then
        if moneyType == 'cash' then
            target.addCash(amount)
        else
            target.addBank(amount, 'Donation Administrative')
        end
        succeeded = true
    elseif moneyType == 'cash' then
        succeeded = target.removeCash(amount)
    else
        succeeded = target.removeBank(amount, 'Saisie Administrative')
    end

    if not succeeded then
        NotifyAdmin(src, 'Fonds insuffisants : opération annulée.')
        return
    end

    NotifyAdmin(src, (operation == 'give' and 'Ajouté ' or 'Retiré ') .. amount .. ' $ (' .. moneyType .. ') au joueur ' .. targetId, 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setJob', function(targetId, jobName, grade)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    grade = tonumber(grade)
    if not targetId or type(jobName) ~= 'string' or #jobName > 50 or not grade or grade < 0 or grade % 1 ~= 0 then
        NotifyAdmin(src, 'Paramètres de métier invalides.')
        return
    end

    local selectedJob
    for _, job in ipairs(exports['rp_jobs']:GetAllJobs()) do
        if job.name == jobName then
            selectedJob = job
            break
        end
    end
    if not selectedJob or not selectedJob.grades or not selectedJob.grades[grade] then
        NotifyAdmin(src, 'Métier ou grade inexistant.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    target.setJob(jobName, grade)
    NotifyAdmin(src, 'Métier du joueur ' .. targetId .. ' défini sur ' .. jobName .. ' (Grade ' .. grade .. ')', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setWeatherTime', function(weather, hours, minutes)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local allowedWeather = {
        EXTRASUNNY = true, CLEAR = true, CLOUDS = true, SMOG = true,
        FOGGY = true, OVERCAST = true, RAIN = true, THUNDER = true,
        CLEARING = true, NEUTRAL = true, SNOW = true, BLIZZARD = true,
        SNOWLIGHT = true, XMAS = true, HALLOWEEN = true
    }

    if weather ~= nil and weather ~= '' then
        if type(weather) ~= 'string' or not allowedWeather[weather] then
            NotifyAdmin(src, 'Météo invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncWeather', -1, weather)
    end

    if hours ~= nil or minutes ~= nil then
        hours = tonumber(hours)
        minutes = tonumber(minutes)
        if not hours or not minutes or hours % 1 ~= 0 or minutes % 1 ~= 0 or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then
            NotifyAdmin(src, 'Heure invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncTime', -1, hours, minutes)
    end

    NotifyAdmin(src, 'Météo / heure synchronisée sur le serveur.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:broadcastAnnouncement', function(message)
    local src = source
    if not IsPlayerAdmin(src) then return end

    if type(message) ~= 'string' then
        NotifyAdmin(src, 'Annonce invalide.')
        return
    end
    message = message:gsub('[%c]', ' '):sub(1, 500)
    if message == '' then
        NotifyAdmin(src, 'L’annonce ne peut pas être vide.')
        return
    end

    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 69, 0},
        args = {'[ANNONCE ADMIN]', message}
    })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'warning')
end)
, '%1')
            if name == '' then name = rawName end
            local jobName = player and player.job or 'unemployed'
            local job = exports['rp_jobs']:GetJob(jobName)
            local ped = GetPlayerPed(pid)
            local position
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                position = { x = coords.x, y = coords.y, z = coords.z }
            end
            onlinePlayers[#onlinePlayers + 1] = {
                id = pid, name = name, rawName = rawName, isSelf = pid == src, position = position,
                job = jobName, jobLabel = job and job.label or jobName,
                grade = player and player.jobGrade or 0, cash = player and player.cash or 0,
                bank = player and player.bank or 0, group = player and player.group or 'user',
                ping = GetPlayerPing(pid)
            }
            seen[pid] = true
        end
    end
    if not seen[src] and GetPlayerName(src) then
        onlinePlayers[#onlinePlayers + 1] = { id = src, name = GetPlayerName(src), rawName = GetPlayerName(src), isSelf = true }
    end
    table.sort(onlinePlayers, function(a, b) return a.id < b.id end)

    local jobs = exports['rp_jobs']:GetAllJobs()
    TriggerClientEvent('rp_tablet_admin:client:openAuthorized', src, adminData, onlinePlayers, jobs)
end)

RegisterNetEvent('rp_tablet_admin:server:kickPlayer', function(targetId, reason)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    if type(reason) ~= 'string' then reason = 'Expulsé par un administrateur.' end
    reason = reason:gsub('[%c]', ' '):sub(1, 120)
    if reason == '' then reason = 'Expulsé par un administrateur.' end

    DropPlayer(targetId, '[ADMINISTRATION] ' .. reason)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' expulsé.', 'success')
end)

local FrozenPlayers = {}
RegisterNetEvent('rp_tablet_admin:server:freezePlayer', function(targetId, freezeState)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or type(freezeState) ~= 'boolean' then
        NotifyAdmin(src, 'Paramètres de gel invalides.')
        return
    end

    FrozenPlayers[targetId] = freezeState
    TriggerClientEvent('rp_tablet_admin:client:freezeToggle', targetId, freezeState)
    NotifyAdmin(src, 'Joueur ' .. targetId .. (freezeState and ' gelé.' or ' dégelé.'), 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:teleportToPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
        local coords = GetEntityCoords(targetPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', src, coords)
        NotifyAdmin(src, 'Téléporté vers le joueur ' .. targetId, 'success')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:bringPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then
        NotifyAdmin(src, 'Joueur cible invalide.')
        return
    end

    local adminPed = GetPlayerPed(src)
    if adminPed and adminPed ~= 0 and DoesEntityExist(adminPed) then
        local coords = GetEntityCoords(adminPed)
        TriggerClientEvent('rp_tablet_admin:client:teleport', targetId, coords)
        NotifyAdmin(src, 'Joueur ' .. targetId .. ' téléporté sur vous.', 'success')
        NotifyAdmin(targetId, 'Vous avez été téléporté par un administrateur.', 'info')
    end
end)

RegisterNetEvent('rp_tablet_admin:server:revivePlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId then
        NotifyAdmin(src, 'Joueur cible introuvable.')
        return
    end

    TriggerClientEvent('rp_tablet_admin:client:revive', targetId)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' réanimé.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:manageEconomy', function(targetId, moneyType, amount, operation)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    amount = tonumber(amount)
    if not targetId or not amount or amount % 1 ~= 0 or amount < 1 or amount > 1000000 then
        NotifyAdmin(src, 'Montant ou joueur invalide (montant maximum : 1 000 000).')
        return
    end
    if moneyType ~= 'cash' and moneyType ~= 'bank' then
        NotifyAdmin(src, 'Type de compte invalide.')
        return
    end
    if operation ~= 'give' and operation ~= 'remove' then
        NotifyAdmin(src, 'Opération économique invalide.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    local succeeded = false
    if operation == 'give' then
        if moneyType == 'cash' then
            target.addCash(amount)
        else
            target.addBank(amount, 'Donation Administrative')
        end
        succeeded = true
    elseif moneyType == 'cash' then
        succeeded = target.removeCash(amount)
    else
        succeeded = target.removeBank(amount, 'Saisie Administrative')
    end

    if not succeeded then
        NotifyAdmin(src, 'Fonds insuffisants : opération annulée.')
        return
    end

    NotifyAdmin(src, (operation == 'give' and 'Ajouté ' or 'Retiré ') .. amount .. ' $ (' .. moneyType .. ') au joueur ' .. targetId, 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setJob', function(targetId, jobName, grade)
    local src = source
    if not IsPlayerAdmin(src) then return end

    targetId = GetOnlineTargetId(targetId)
    grade = tonumber(grade)
    if not targetId or type(jobName) ~= 'string' or #jobName > 50 or not grade or grade < 0 or grade % 1 ~= 0 then
        NotifyAdmin(src, 'Paramètres de métier invalides.')
        return
    end

    local selectedJob
    for _, job in ipairs(exports['rp_jobs']:GetAllJobs()) do
        if job.name == jobName then
            selectedJob = job
            break
        end
    end
    if not selectedJob or not selectedJob.grades or not selectedJob.grades[grade] then
        NotifyAdmin(src, 'Métier ou grade inexistant.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target then
        NotifyAdmin(src, 'Joueur introuvable.')
        return
    end

    target.setJob(jobName, grade)
    NotifyAdmin(src, 'Métier du joueur ' .. targetId .. ' défini sur ' .. jobName .. ' (Grade ' .. grade .. ')', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setWeatherTime', function(weather, hours, minutes)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local allowedWeather = {
        EXTRASUNNY = true, CLEAR = true, CLOUDS = true, SMOG = true,
        FOGGY = true, OVERCAST = true, RAIN = true, THUNDER = true,
        CLEARING = true, NEUTRAL = true, SNOW = true, BLIZZARD = true,
        SNOWLIGHT = true, XMAS = true, HALLOWEEN = true
    }

    if weather ~= nil and weather ~= '' then
        if type(weather) ~= 'string' or not allowedWeather[weather] then
            NotifyAdmin(src, 'Météo invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncWeather', -1, weather)
    end

    if hours ~= nil or minutes ~= nil then
        hours = tonumber(hours)
        minutes = tonumber(minutes)
        if not hours or not minutes or hours % 1 ~= 0 or minutes % 1 ~= 0 or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then
            NotifyAdmin(src, 'Heure invalide.')
            return
        end
        TriggerClientEvent('rp_tablet_admin:client:syncTime', -1, hours, minutes)
    end

    NotifyAdmin(src, 'Météo / heure synchronisée sur le serveur.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:broadcastAnnouncement', function(message)
    local src = source
    if not IsPlayerAdmin(src) then return end

    if type(message) ~= 'string' then
        NotifyAdmin(src, 'Annonce invalide.')
        return
    end
    message = message:gsub('[%c]', ' '):sub(1, 500)
    if message == '' then
        NotifyAdmin(src, 'L’annonce ne peut pas être vide.')
        return
    end

    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 69, 0},
        args = {'[ANNONCE ADMIN]', message}
    })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'warning')
end)


RegisterNetEvent('rp_tablet_admin:server:requestPlayerPositions', function()
    local src = source
    if not IsPlayerAdmin(src) then return end
    local players = {}
    for _, rawId in pairs(GetPlayers()) do
        local id = tonumber(rawId)
        if id then
            local player = exports['rp_core']:GetPlayerFromId(id)
            local ped = GetPlayerPed(id)
            local position
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                position = { x = coords.x, y = coords.y, z = coords.z }
            end
            local name = player and ((player.firstname or '') .. ' ' .. (player.lastname or '')) or (GetPlayerName(id) or ('Joueur ' .. id))
            players[#players + 1] = { id = id, name = name, rawName = GetPlayerName(id), isSelf = id == src,
                position = position, job = player and player.job or 'unemployed',
                jobLabel = player and (exports['rp_jobs']:GetJob(player.job).label) or 'Sans emploi',
                grade = player and player.jobGrade or 0, cash = player and player.cash or 0,
                bank = player and player.bank or 0, group = player and player.group or 'user', ping = GetPlayerPing(id) }
        end
    end
    TriggerClientEvent('rp_tablet_admin:client:playerPositions', src, players)
end)

RegisterNetEvent('rp_tablet_admin:server:requestAuditLogs', function()
    local src = source
    if not IsPlayerAdmin(src) then return end
    local ok, logs = pcall(MySQL.query.await,
        'SELECT admin_name, action, target_identifier, details, created_at FROM admin_logs ORDER BY id DESC LIMIT 50')
    if not ok then NotifyAdmin(src, 'Impossible de charger les journaux administrateur.'); return end
    TriggerClientEvent('rp_tablet_admin:client:auditLogs', src, logs or {})
end)

RegisterNetEvent('rp_tablet_admin:server:spectatePlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then NotifyAdmin(src, 'Cible invalide pour la surveillance.'); return end
    TriggerClientEvent('rp_tablet_admin:client:startSpectate', src, targetId)
end)
RegisterNetEvent('rp_tablet_admin:server:stopSpectate', function()
    local src = source
    if IsPlayerAdmin(src) then TriggerClientEvent('rp_tablet_admin:client:stopSpectate', src) end
end)
RegisterNetEvent('rp_tablet_admin:server:toggleNoclip', function()
    local src = source
    if IsPlayerAdmin(src) then TriggerClientEvent('rp_tablet_admin:client:toggleNoclip', src) end
end)
RegisterNetEvent('rp_tablet_admin:server:toggleGodmode', function()
    local src = source
    if IsPlayerAdmin(src) then TriggerClientEvent('rp_tablet_admin:client:toggleGodmode', src) end
end)
RegisterNetEvent('rp_tablet_admin:server:spawnVehicle', function(model)
    local src = source
    if not IsPlayerAdmin(src) then return end
    if type(model) ~= 'string' or #model < 2 or #model > 40 or not model:match('^[%w_]+$') then NotifyAdmin(src, 'Modèle de véhicule invalide.'); return end
    TriggerClientEvent('rp_tablet_admin:client:spawnVehicle', src, model)
end)
RegisterNetEvent('rp_tablet_admin:server:banPlayer', function(targetId, rawReason)
    local src = source
    if not IsPlayerAdmin(src) then return end
    targetId = GetOnlineTargetId(targetId)
    if not targetId or targetId == src then NotifyAdmin(src, 'Joueur cible invalide.'); return end
    local reason = type(rawReason) == 'string' and rawReason:gsub('[%c]', ' '):sub(1, 180) or ''
    if reason == '' then NotifyAdmin(src, 'Un motif de bannissement est obligatoire.'); return end
    local license
    for _, identifier in ipairs(GetPlayerIdentifiers(targetId)) do if identifier:sub(1, 8) == 'license:' then license = identifier; break end end
    if not license then NotifyAdmin(src, 'Identifiant license introuvable.'); return end
    local ok, err = pcall(function()
        MySQL.insert.await('INSERT INTO player_bans (identifier, reason, banned_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), created_at = CURRENT_TIMESTAMP',
            { license, reason, 'server:' .. tostring(src) })
    end)
    if not ok then print('[rp_tablet_admin] Ban SQL error: ' .. tostring(err)); NotifyAdmin(src, 'Erreur SQL : bannissement annulé.'); return end
    DropPlayer(targetId, '[ADMINISTRATION - BAN PERMANENT] ' .. reason)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' banni durablement.', 'success')
end)
RegisterNetEvent('rp_tablet_admin:server:healPlayer', function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    targetId = GetOnlineTargetId(targetId)
    if not targetId then NotifyAdmin(src, 'Joueur cible introuvable.'); return end
    TriggerClientEvent('rp_tablet_admin:client:heal', targetId)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' soigné.', 'success')
end)
