local FrozenPlayers = {}

local function IsPlayerAdmin(source)
    if IsPlayerAceAllowed(source, "rp_admin") then
        return true
    end

    local player = exports['rp_core']:GetPlayerFromId(source)
    return player ~= nil and (player.group == 'admin' or player.group == 'superadmin' or player.group == 'fondateur')
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


-- Every privileged tablet action is authorized and rate-limited server-side.
local function AllowAdminAction(src, action, cooldown)
    if not IsPlayerAdmin(src) then return false end
    local accessOk, tabletAllowed = pcall(function()
        return exports['rp_tablet_creator']:CanUseTablet(src, 'admin')
    end)
    return accessOk and tabletAllowed == true
        and exports['rp_core']:CanPerformAction(src, 'admin:' .. action, cooldown or 500)
end

-- Audit writes are best-effort: a database outage must not crash moderation,
-- but the failure is visible in the server console.
local function LogAdminAction(src, action, targetId, details)
    local admin = exports['rp_core']:GetPlayerFromId(src)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId) or nil
    local adminIdentifier
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then
            adminIdentifier = identifier
            break
        end
    end

    local adminName = admin and ((admin.firstname or '') .. ' ' .. (admin.lastname or '')) or (GetPlayerName(src) or 'Administrateur')
    adminName = adminName:gsub('^%s*(.-)%s*$', '%1')
    if adminName == '' then adminName = GetPlayerName(src) or 'Administrateur' end

    local ok, err = pcall(MySQL.insert.await,
        'INSERT INTO admin_logs (admin_identifier, admin_name, action, target_identifier, details) VALUES (?, ?, ?, ?, ?)',
        {
            adminIdentifier or ('server:' .. tostring(src)),
            adminName:sub(1, 64),
            tostring(action):sub(1, 64),
            target and target.identifier or nil,
            tostring(details or ''):gsub('[%c]', ' '):sub(1, 500)
        }
    )
    if not ok then
        print('[rp_tablet_admin] Audit log failed: ' .. tostring(err))
    end
end

RegisterNetEvent('rp_tablet_admin:server:requestOpen', function()
    local src = source
    if not IsPlayerAdmin(src) or not exports['rp_core']:CanPerformAction(src, 'admin:open', 1000) then
        NotifyAdmin(src, "Accès refusé : permissions administrateur requises.")
        return
    end

    local accessOk, tabletAllowed = pcall(function()
        return exports['rp_tablet_creator']:CanUseTablet(src, 'admin')
    end)
    if not accessOk or tabletAllowed ~= true then
        NotifyAdmin(src, "Votre accès à la tablette administrateur est désactivé.")
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
            local name = first .. ' ' .. last
            if name == ' ' then name = rawName end
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
                characterLoaded = player ~= nil,
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
    local itemCatalog = {}
    local itemOk, catalog = pcall(function() return exports['rp_inventory']:GetItemCatalog() end)
    if itemOk and type(catalog) == 'table' then itemCatalog = catalog end
    local frozenPlayers = {}
    for targetId, isFrozen in pairs(FrozenPlayers) do
        if isFrozen and GetPlayerName(targetId) then frozenPlayers[#frozenPlayers + 1] = targetId end
    end
    local weaponPolicy = {}
    local weaponsOk, weapons = pcall(function() return exports['rp_anticheat']:GetWeaponPolicy() end)
    if weaponsOk and type(weapons) == 'table' then weaponPolicy = weapons end
    TriggerClientEvent('rp_tablet_admin:client:openAuthorized', src, adminData, onlinePlayers, jobs, frozenPlayers, itemCatalog, weaponPolicy)
end)

RegisterNetEvent('rp_tablet_admin:server:saveWeaponPolicy', function(rawPolicy)
    local src = source
    if not AllowAdminAction(src, 'weapon_policy', 1500) then return end
    local ok, saved, result = pcall(function()
        return exports['rp_anticheat']:SaveWeaponPolicy(src, rawPolicy)
    end)
    if not ok or saved ~= true then
        local message = type(result) == 'string' and result or 'Impossible d’enregistrer les règles des armes.'
        NotifyAdmin(src, message)
        TriggerClientEvent('rp_tablet_admin:client:weaponPolicySaveFailed', src, message)
        return
    end
    LogAdminAction(src, 'weapon_policy', nil, 'Mise à jour des armes autorisées/interdites')
    TriggerClientEvent('rp_tablet_admin:client:weaponPolicySaved', src, result)
    NotifyAdmin(src, 'Liste des armes enregistrée et synchronisée avec l’anticheat.', 'success')
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

    LogAdminAction(src, 'kick', targetId, reason)
    DropPlayer(targetId, '[ADMINISTRATION] ' .. reason)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' expulsé.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:freezePlayer', function(targetId, freezeState)
    local src = source
    if not AllowAdminAction(src, 'freeze', 500) then return end

    targetId = GetOnlineTargetId(targetId)
    if not targetId or type(freezeState) ~= 'boolean' then
        NotifyAdmin(src, 'Paramètres de gel invalides.')
        return
    end

    LogAdminAction(src, 'freeze', targetId, freezeState and 'Gel du joueur' or 'Dégel du joueur')
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
        LogAdminAction(src, 'goto', targetId, 'Téléportation vers le joueur')
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
        LogAdminAction(src, 'bring', targetId, 'Téléportation du joueur vers l’administrateur')
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

    LogAdminAction(src, 'revive', targetId, 'Réanimation administrateur')
    TriggerClientEvent('rp_tablet_admin:client:revive', targetId)
    NotifyAdmin(src, 'Joueur ' .. targetId .. ' réanimé.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:manageEconomy', function(targetId, moneyType, amount, operation)
    local src = source
    if not AllowAdminAction(src, 'economy', 750) then return end

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

    LogAdminAction(src, 'economy', targetId, operation .. ' ' .. amount .. ' ' .. moneyType)
    NotifyAdmin(src, (operation == 'give' and 'Ajouté ' or 'Retiré ') .. amount .. ' $ (' .. moneyType .. ') au joueur ' .. targetId, 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setJob', function(targetId, jobName, grade)
    local src = source
    if not AllowAdminAction(src, 'setjob', 750) then return end

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

    -- A player can appear in GetPlayers() before rp_core has finished loading
    -- the selected character. Retry briefly, while ensuring the same server ID
    -- is still connected, instead of immediately reporting "Joueur introuvable".
    local target
    for attempt = 1, 10 do
        if not GetPlayerName(targetId) then break end
        target = exports['rp_core']:GetPlayerFromId(targetId)
        if target then break end
        Wait(200)
    end
    if not target then
        NotifyAdmin(src, GetPlayerName(targetId)
            and 'Le personnage de ce joueur est encore en cours de chargement. Actualisez la liste puis réessayez.'
            or 'Ce joueur vient de se déconnecter. Actualisez la liste des joueurs.')
        return
    end

    local ok, applied = pcall(target.setJob, jobName, grade)
    if not ok or applied ~= true then
        print(('[rp_tablet_admin] setJob failed: admin=%s target=%s job=%s grade=%s error=%s')
            :format(src, targetId, jobName, grade, tostring(applied)))
        NotifyAdmin(src, 'Le métier n’a pas pu être enregistré. Consultez les logs serveur.')
        return
    end

    LogAdminAction(src, 'setjob', targetId, jobName .. ' grade ' .. grade)
    NotifyAdmin(src, 'Métier du joueur ' .. targetId .. ' défini sur ' .. jobName .. ' (Grade ' .. grade .. ')', 'success')
    TriggerClientEvent('rp_core:client:notify', targetId,
        'Votre métier a été défini sur ' .. (selectedJob.label or jobName) .. ' (Grade ' .. grade .. ').', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:setWeatherTime', function(weather, hours, minutes)
    local src = source
    if not AllowAdminAction(src, 'world', 1000) then return end

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

    LogAdminAction(src, 'world', nil, 'Météo=' .. tostring(weather) .. ' heure=' .. tostring(hours) .. ':' .. tostring(minutes))
    NotifyAdmin(src, 'Météo / heure synchronisée sur le serveur.', 'info')
end)

RegisterNetEvent('rp_tablet_admin:server:broadcastAnnouncement', function(message)
    local src = source
    if not AllowAdminAction(src, 'broadcast', 2000) then return end

    if type(message) ~= 'string' then
        NotifyAdmin(src, 'Annonce invalide.')
        return
    end
    message = message:gsub('[%c]', ' '):sub(1, 500)
    if message == '' then
        NotifyAdmin(src, 'L’annonce ne peut pas être vide.')
        return
    end

    LogAdminAction(src, 'broadcast', nil, message)
    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 69, 0},
        args = {'[ANNONCE ADMIN]', message}
    })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'warning')
end)
RegisterNetEvent('rp_tablet_admin:server:requestAuditLogs', function()
    local src = source
    if not AllowAdminAction(src, 'audit_logs', 2000) then
        NotifyAdmin(src, 'Accès aux journaux refusé ou demande trop fréquente.')
        return
    end

    local ok, logs = pcall(MySQL.query.await,
        'SELECT admin_name, action, target_identifier, details, created_at FROM admin_logs ORDER BY id DESC LIMIT 50')
    if not ok then
        print('[rp_tablet_admin] Audit log query failed: ' .. tostring(logs))
        NotifyAdmin(src, 'Impossible de charger les journaux administrateur.')
        return
    end

    TriggerClientEvent('rp_tablet_admin:client:auditLogs', src, logs or {})
end)

