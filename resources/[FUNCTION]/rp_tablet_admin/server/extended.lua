local AdminModes = {}
local function IsExtendedAdmin(src)
    if IsPlayerAceAllowed(src, 'rp_admin') then return true end
    local player = exports['rp_core']:GetPlayerFromId(src)
    return player ~= nil and (player.group == 'admin' or player.group == 'superadmin' or player.group == 'fondateur')
end

local function AllowExtendedAction(src, action, cooldown)
    if not IsExtendedAdmin(src) then return false end

    -- Keep the extended endpoints subject to the same per-player tablet
    -- revocation as the main admin endpoints. Fail closed if the creator
    -- access service is unavailable.
    local accessOk, tabletAllowed = pcall(function()
        return exports['rp_tablet_creator']:CanUseTablet(src, 'admin')
    end)
    if not accessOk or tabletAllowed ~= true then return false end

    return exports['rp_core']:CanPerformAction(src, 'admin:' .. action, cooldown or 500)
end

local function NotifyExtended(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'error')
end

local function TargetId(raw)
    local id = tonumber(raw)
    if not id or id < 1 or id % 1 ~= 0 or not GetPlayerName(id) then return nil end
    return id
end

local function LogExtendedAction(src, action, targetId, details)
    local admin = exports['rp_core']:GetPlayerFromId(src)
    local target = targetId and exports['rp_core']:GetPlayerFromId(targetId) or nil
    local adminName = admin and ((admin.firstname or '') .. ' ' .. (admin.lastname or '')) or (GetPlayerName(src) or 'Administrateur')
    local ok, err = pcall(MySQL.insert.await,
        'INSERT INTO admin_logs (admin_identifier, admin_name, action, target_identifier, details) VALUES (?, ?, ?, ?, ?)',
        { admin and admin.identifier or ('server:' .. tostring(src)), adminName:sub(1, 64),
          tostring(action):sub(1, 64), target and target.identifier or nil,
          tostring(details or ''):gsub('[%c]', ' '):sub(1, 500) })
    if not ok then print('[rp_tablet_admin] Audit log failed: ' .. tostring(err)) end
end

RegisterNetEvent('rp_tablet_admin:server:teleportToMapPoint', function(rawX, rawY)
    local src = source
    if not AllowExtendedAction(src, 'teleport_map_point', 1000) then return end
    local x, y = tonumber(rawX), tonumber(rawY)
    if not x or not y or x ~= x or y ~= y
        or x < -4500 or x > 4500 or y < -4500 or y > 8500 then
        NotifyExtended(src, 'Coordonnées de téléportation invalides.')
        return
    end
    TriggerClientEvent('rp_tablet_admin:client:teleportToMapPoint', src, { x = x, y = y })
    LogExtendedAction(src, 'teleport_map_point', nil,
        ('Téléportation au point X %.1f / Y %.1f défini sur la carte'):format(x, y))
end)

RegisterNetEvent('rp_tablet_admin:server:requestPlayerPositions', function()
    local src = source
    if not AllowExtendedAction(src, 'positions', 1800) then return end

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

            local rawName = GetPlayerName(id) or ('Joueur ' .. id)
            local name = rawName
            if player then
                local first = tostring(player.firstname or '')
                local last = tostring(player.lastname or '')
                local fullName = (first .. ' ' .. last):gsub('^%s*(.-)%s*$', '%1')
                if fullName ~= '' then name = fullName end
            end

            local jobName = player and player.job or 'unemployed'
            local jobInfo = exports['rp_jobs']:GetJob(jobName)
            players[#players + 1] = {
                id = id,
                name = name,
                rawName = rawName,
                characterLoaded = player ~= nil,
                isSelf = id == src,
                position = position,
                job = jobName,
                jobLabel = jobInfo and jobInfo.label or jobName,
                grade = player and player.jobGrade or 0,
                cash = player and player.cash or 0,
                bank = player and player.bank or 0,
                group = player and player.group or 'user',
                ping = GetPlayerPing(id)
            }
        end
    end

    TriggerClientEvent('rp_tablet_admin:client:playerPositions', src, players)
end)

RegisterNetEvent('rp_tablet_admin:server:spectatePlayer', function(rawTargetId)
    local src = source
    if not AllowExtendedAction(src, 'spectate', 500) then return end
    local targetId = TargetId(rawTargetId)
    if not targetId or targetId == src then
        NotifyExtended(src, 'Cible invalide pour la surveillance.')
        return
    end

    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId) then
        NotifyExtended(src, 'Le joueur se trouve dans une instance différente.')
        return
    end
    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
        NotifyExtended(src, 'Position du joueur indisponible.')
        return
    end
    local coords = GetEntityCoords(targetPed)
    LogExtendedAction(src, 'spectate', targetId, 'Début de surveillance')
    TriggerClientEvent('rp_tablet_admin:client:startSpectate', src, targetId, { x = coords.x, y = coords.y, z = coords.z })
end)

RegisterNetEvent('rp_tablet_admin:server:stopSpectate', function()
    local src = source
    if not AllowExtendedAction(src, 'stop_spectate', 500) then return end
    TriggerClientEvent('rp_tablet_admin:client:stopSpectate', src)
end)

RegisterNetEvent('rp_tablet_admin:server:toggleNoclip', function()
    local src = source
    if not AllowExtendedAction(src, 'noclip', 500) then return end
    AdminModes[src] = AdminModes[src] or { godmode = false, noclip = false }
    AdminModes[src].noclip = not AdminModes[src].noclip
    TriggerEvent('rp_anticheat:setAdminInvulnerability', src, AdminModes[src].noclip or AdminModes[src].godmode)
    LogExtendedAction(src, 'noclip', nil, AdminModes[src].noclip and 'Activation NoClip' or 'Désactivation NoClip')
    TriggerClientEvent('rp_tablet_admin:client:toggleNoclip', src, AdminModes[src].noclip)
end)

RegisterNetEvent('rp_tablet_admin:server:toggleGodmode', function()
    local src = source
    if not AllowExtendedAction(src, 'godmode', 500) then return end
    AdminModes[src] = AdminModes[src] or { godmode = false, noclip = false }
    AdminModes[src].godmode = not AdminModes[src].godmode
    TriggerEvent('rp_anticheat:setAdminInvulnerability', src, AdminModes[src].noclip or AdminModes[src].godmode)
    LogExtendedAction(src, 'godmode', nil, AdminModes[src].godmode and 'Activation GodMode' or 'Désactivation GodMode')
    TriggerClientEvent('rp_tablet_admin:client:toggleGodmode', src, AdminModes[src].godmode)
end)

RegisterNetEvent('rp_tablet_admin:server:spawnVehicle', function(rawModel)
    local src = source
    if not AllowExtendedAction(src, 'spawn_vehicle', 1000) then return end
    if type(rawModel) ~= 'string' or #rawModel < 2 or #rawModel > 40 or not rawModel:match('^[%w_]+$') then
        NotifyExtended(src, 'Modèle de véhicule invalide.')
        return
    end

    LogExtendedAction(src, 'spawn_vehicle', nil, rawModel)
    TriggerClientEvent('rp_tablet_admin:client:spawnVehicle', src, rawModel)
end)

RegisterNetEvent('rp_tablet_admin:server:giveVehicle', function(rawTargetId, rawModel)
    local src = source
    if not AllowExtendedAction(src, 'give_vehicle', 1000) then return end

    local targetId = TargetId(rawTargetId)
    if not targetId or type(rawModel) ~= 'string' or #rawModel < 2 or #rawModel > 40 or not rawModel:match('^[%w_]+$') then
        NotifyExtended(src, 'Joueur ou modèle de véhicule invalide.')
        return
    end

    LogExtendedAction(src, 'give_vehicle', targetId, rawModel)
    TriggerClientEvent('rp_tablet_admin:client:spawnVehicleForPlayer', targetId, rawModel:lower())
    NotifyExtended(src, 'Création du véhicule demandée pour le joueur ' .. targetId .. '.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:giveItem', function(rawTargetId, rawItem, rawCount)
    local src = source
    if not AllowExtendedAction(src, 'give_item', 750) then return end

    local targetId = TargetId(rawTargetId)
    local count = tonumber(rawCount)
    local itemName = type(rawItem) == 'string' and rawItem or ''
    if not targetId or #itemName < 1 or #itemName > 64 or not itemName:match('^[%w_]+$')
        or not count or count % 1 ~= 0 or count < 1 or count > 1000 then
        NotifyExtended(src, 'Joueur, item ou quantité invalide.')
        return
    end

    local ok, granted = pcall(function()
        return exports['rp_inventory']:AdminSetItem(targetId, itemName, 'add', count)
    end)
    if not ok or granted ~= true then
        NotifyExtended(src, 'Attribution impossible : item inconnu, inventaire plein ou sauvegarde indisponible.')
        return
    end

    LogExtendedAction(src, 'give_item', targetId, itemName .. ' x' .. count)
    NotifyExtended(src, 'Item ' .. itemName .. ' x' .. count .. ' attribué au joueur ' .. targetId .. '.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:giveWeapon', function(rawTargetId, rawWeapon)
    local src = source
    if not AllowExtendedAction(src, 'give_weapon', 1500) then return end

    local targetId = TargetId(rawTargetId)
    local weapon = type(rawWeapon) == 'string' and rawWeapon:upper() or ''
    local policyOk, allowed = pcall(function()
        return exports['rp_anticheat']:IsWeaponAllowed(weapon)
    end)
    if not targetId or not weapon:match('^WEAPON_[A-Z0-9_]+$') or not policyOk or allowed ~= true then
        NotifyExtended(src, 'Joueur ou arme non autorisée.')
        return
    end

    local target = exports['rp_core']:GetPlayerFromId(targetId)
    if not target or type(target.metadata) ~= 'table' then
        NotifyExtended(src, 'Le personnage du joueur cible n’est pas chargé.')
        return
    end

    local previous = target.metadata.weapons
    local savedWeapons, found = {}, false
    if type(previous) == 'table' then
        for _, entry in ipairs(previous) do
            if type(entry) == 'table' and type(entry.name) == 'string'
                and entry.name:match('^WEAPON_[A-Z0-9_]+$') then
                if entry.name == weapon then
                    savedWeapons[#savedWeapons + 1] = { name = weapon, ammo = 120 }
                    found = true
                else
                    savedWeapons[#savedWeapons + 1] = {
                        name = entry.name,
                        ammo = math.max(0, math.min(9999, math.floor(tonumber(entry.ammo) or 0)))
                    }
                end
            end
        end
    end
    if not found then
        savedWeapons[#savedWeapons + 1] = { name = weapon, ammo = 120 }
    end

    target.metadata.weapons = savedWeapons
    local saveOk, saved = pcall(target.save, true)
    if not saveOk or saved ~= true then
        target.metadata.weapons = previous
        print(('[rp_tablet_admin] Weapon save failed for player %s: %s'):format(targetId, tostring(saved)))
        NotifyExtended(src, 'Impossible de sauvegarder cette arme. Attribution annulée.')
        return
    end

    LogExtendedAction(src, 'give_weapon', targetId, weapon .. ' (120 munitions, sauvegardée)')
    TriggerClientEvent('rp_tablet_admin:client:giveWeapon', targetId, weapon, 120)
    NotifyExtended(src, 'Arme enregistrée et attribuée au joueur ' .. targetId .. '.', 'success')
    TriggerClientEvent('rp_core:client:notify', targetId,
        'Un administrateur vous a attribué : ' .. weapon:gsub('^WEAPON_', '') .. '.', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    AdminModes[src] = nil
    TriggerEvent('rp_anticheat:setAdminInvulnerability', src, false)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'rp_anticheat' then return end
    for src, modes in pairs(AdminModes) do
        TriggerEvent('rp_anticheat:setAdminInvulnerability', src, modes.noclip or modes.godmode)
    end
end)

RegisterNetEvent('rp_tablet_admin:server:banPlayer', function(rawTargetId, rawReason)
    local src = source
    if not AllowExtendedAction(src, 'ban', 1500) then return end
    local targetId = TargetId(rawTargetId)
    if not targetId or targetId == src then
        NotifyExtended(src, 'Joueur cible invalide.')
        return
    end

    local reason = type(rawReason) == 'string' and rawReason:gsub('[%c]', ' '):sub(1, 180) or ''
    if reason == '' then
        NotifyExtended(src, 'Un motif de bannissement est obligatoire.')
        return
    end

    local license
    for _, identifier in ipairs(GetPlayerIdentifiers(targetId)) do
        if identifier:sub(1, 8) == 'license:' then license = identifier; break end
    end
    if not license then
        NotifyExtended(src, 'Identifiant license introuvable : bannissement annulé.')
        return
    end

    local adminLicense
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then adminLicense = identifier; break end
    end

    local ok, err = pcall(MySQL.insert.await, [[
        INSERT INTO player_bans (identifier, reason, banned_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), created_at = CURRENT_TIMESTAMP
    ]], { license, reason, adminLicense or ('server:' .. tostring(src)) })
    if not ok then
        print('[rp_tablet_admin] Persistent ban failed: ' .. tostring(err))
        NotifyExtended(src, 'Erreur SQL : bannissement annulé.')
        return
    end

    LogExtendedAction(src, 'ban', targetId, reason)
    DropPlayer(targetId, '[ADMINISTRATION - BAN PERMANENT] ' .. reason)
    NotifyExtended(src, 'Joueur ' .. targetId .. ' banni durablement.', 'success')
end)

RegisterNetEvent('rp_tablet_admin:server:healPlayer', function(rawTargetId)
    local src = source
    if not AllowExtendedAction(src, 'heal', 500) then return end
    local targetId = TargetId(rawTargetId)
    if not targetId then
        NotifyExtended(src, 'Joueur cible introuvable.')
        return
    end

    LogExtendedAction(src, 'heal', targetId, 'Soin administrateur')
    TriggerClientEvent('rp_tablet_admin:client:heal', targetId)
    NotifyExtended(src, 'Joueur ' .. targetId .. ' soigné.', 'success')
end)


-- Signalements joueurs : commande publique limitée et modération réservée au staff.
local ReportCooldowns = {}

RegisterCommand('report', function(src, args)
    if src == 0 then return end
    local now = os.time()
    if ReportCooldowns[src] and now - ReportCooldowns[src] < 60 then
        NotifyExtended(src, 'Veuillez attendre 60 secondes avant un nouveau signalement.')
        return
    end
    local message = table.concat(args or {}, ' '):gsub('[%c]', ' '):gsub('%s+', ' ')
    message = message:match('^%s*(.-)%s*$') or ''
    if #message < 10 or #message > 500 then
        NotifyExtended(src, 'Utilisation : /report suivi d’un message de 10 à 500 caractères.')
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local identifier = player and player.identifier or nil
    if not identifier then
        for _, value in ipairs(GetPlayerIdentifiers(src) or {}) do
            if value:sub(1, 8) == 'license:' then identifier = value; break end
        end
    end
    if not identifier then
        NotifyExtended(src, 'Impossible d’identifier votre personnage. Réessayez plus tard.')
        return
    end
    local ok, reportId = pcall(MySQL.insert.await,
        'INSERT INTO player_reports (player_identifier, player_name, message) VALUES (?, ?, ?)',
        { tostring(identifier):sub(1, 80), (GetPlayerName(src) or 'Joueur'):sub(1, 64), message })
    if not ok or not reportId then
        print('[rp_tablet_admin] Player report insert failed: ' .. tostring(reportId))
        NotifyExtended(src, 'Votre signalement n’a pas pu être enregistré.')
        return
    end
    ReportCooldowns[src] = now
    NotifyExtended(src, 'Signalement #' .. tostring(reportId) .. ' enregistré. Merci.', 'success')
end, false)

AddEventHandler('playerDropped', function()
    ReportCooldowns[source] = nil
end)

RegisterNetEvent('rp_tablet_admin:server:submitPlayerReport', function(rawMessage)
    local src = source
    local now = os.time()
    if ReportCooldowns[src] and now - ReportCooldowns[src] < 60 then
        TriggerClientEvent('rp_tablet_admin:client:playerReportResult', src, false,
            'Veuillez attendre 60 secondes avant un nouveau signalement.')
        return
    end
    if type(rawMessage) ~= 'string' then
        TriggerClientEvent('rp_tablet_admin:client:playerReportResult', src, false, 'Message de signalement invalide.')
        return
    end
    local message = rawMessage:gsub('[%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*    local src = source
    if not AllowExtendedAction(src, 'reports_read', 1200) then return end
    local ok, reports = pcall(MySQL.query.await, [[
        SELECT id, player_name, message, status, handled_by, created_at, handled_at
        FROM player_reports
        ORDER BY CASE status WHEN 'open' THEN 0 WHEN 'accepted' THEN 1 ELSE 2 END, created_at DESC
        LIMIT 100
    ]])
    if not ok then
        print('[rp_tablet_admin] Report query failed: ' .. tostring(reports))
        NotifyExtended(src, 'Impossible de charger les signalements.')
        return
    end
    TriggerClientEvent('rp_tablet_admin:client:reports', src, reports or {})
end)

RegisterNetEvent('rp_tablet_admin:server:updateReport', function(rawReportId, rawStatus)
    local src = source
    if not AllowExtendedAction(src, 'reports_update', 700) then return end
    local reportId = tonumber(rawReportId)
    local status = (rawStatus == 'accepted' or rawStatus == 'resolved' or rawStatus == 'rejected') and rawStatus or nil
    if not reportId or reportId < 1 or reportId % 1 ~= 0 or not status then
        NotifyExtended(src, 'Signalement ou statut invalide.')
        return
    end
    local staff = exports['rp_core']:GetPlayerFromId(src)
    local staffName = staff and (((staff.firstname or '') .. ' ' .. (staff.lastname or '')):gsub('^%s*(.-)%s*$', '%1'))
        or (GetPlayerName(src) or 'Staff')
    local lookupOk, owner = pcall(MySQL.single.await,
        "SELECT player_identifier FROM player_reports WHERE id = ? AND status = 'open'", { reportId })
    if not lookupOk then
        NotifyExtended(src, 'Impossible de vérifier le propriétaire du signalement.')
        return
    end
    if not owner then
        NotifyExtended(src, 'Signalement introuvable ou déjà pris en charge.')
        return
    end
    local ok, affected = pcall(MySQL.update.await, [[
        UPDATE player_reports
        SET status = ?, handled_by = ?, handled_at = CURRENT_TIMESTAMP
        WHERE id = ? AND status = 'open'
    ]], { status, staffName:sub(1, 64), reportId })
    if not ok then
        print('[rp_tablet_admin] Report update failed: ' .. tostring(affected))
        NotifyExtended(src, 'Impossible de mettre à jour le signalement.')
        return
    end
    if not affected or affected < 1 then
        NotifyExtended(src, 'Signalement introuvable ou déjà pris en charge.')
        return
    end
    LogExtendedAction(src, 'report_' .. status, nil, 'Signalement #' .. reportId)
    TriggerClientEvent('rp_tablet_admin:client:reportUpdated', src, reportId, status, staffName)
    for _, rawId in ipairs(GetPlayers()) do
        local staffId = tonumber(rawId)
        if staffId and staffId ~= src then
            local member = exports['rp_core']:GetPlayerFromId(staffId)
            local group = member and tostring(member.group or '') or ''
            if IsPlayerAceAllowed(staffId, 'rp_admin') or group == 'admin'
                or group == 'superadmin' or group == 'fondateur' then
                TriggerClientEvent('rp_tablet_admin:client:reportsRefresh', staffId)
            end
        end
    end
    if status == 'accepted' then
        for _, rawId in ipairs(GetPlayers()) do
            local playerId = tonumber(rawId)
            local player = playerId and exports['rp_core']:GetPlayerFromId(playerId)
            if player and player.identifier == owner.player_identifier then
                TriggerClientEvent('rp_core:client:notify', playerId,
                    'Votre rapport a bien été pris en charge par un membre du staff.', 'success')
                break
            end
        end
    end
    NotifyExtended(src, status == 'accepted'
        and ('Signalement #' .. reportId .. ' pris en charge.')
        or ('Signalement #' .. reportId .. (status == 'resolved' and ' marqué comme traité.' or ' rejeté.')), 'success')
end)
) or ''
    if #message < 10 or #message > 500 then
        TriggerClientEvent('rp_tablet_admin:client:playerReportResult', src, false,
            'Votre message doit contenir entre 10 et 500 caractères.')
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local identifier = player and player.identifier or nil
    if not identifier then
        for _, value in ipairs(GetPlayerIdentifiers(src) or {}) do
            if value:sub(1, 8) == 'license:' then identifier = value; break end
        end
    end
    if not identifier then
        TriggerClientEvent('rp_tablet_admin:client:playerReportResult', src, false,
            'Impossible d’identifier votre personnage. Réessayez plus tard.')
        return
    end
    local ok, reportId = pcall(MySQL.insert.await,
        'INSERT INTO player_reports (player_identifier, player_name, message) VALUES (?, ?, ?)',
        { tostring(identifier):sub(1, 80), (GetPlayerName(src) or 'Joueur'):sub(1, 64), message })
    if not ok or not reportId then
        print('[rp_tablet_admin] NUI report insert failed: ' .. tostring(reportId))
        TriggerClientEvent('rp_tablet_admin:client:playerReportResult', src, false,
            'Votre signalement n’a pas pu être enregistré.')
        return
    end
    ReportCooldowns[src] = now
    TriggerClientEvent('rp_tablet_admin:client:playerReportResult', src, true,
        'Votre signalement #' .. tostring(reportId) .. ' a bien été envoyé.')
    for _, rawId in ipairs(GetPlayers()) do
        local staffId = tonumber(rawId)
        local staff = staffId and exports['rp_core']:GetPlayerFromId(staffId)
        local group = staff and tostring(staff.group or '') or ''
        if staffId and (IsPlayerAceAllowed(staffId, 'rp_admin') or IsPlayerAceAllowed(staffId, 'rp_founder')
            or group == 'admin' or group == 'superadmin' or group == 'fondateur' or group == 'moderator') then
            TriggerClientEvent('rp_tablet_admin:client:reportsRefresh', staffId)
        end
    end
end)

RegisterNetEvent('rp_tablet_admin:server:requestReports', function()
    local src = source
    if not AllowExtendedAction(src, 'reports_read', 1200) then return end
    local ok, reports = pcall(MySQL.query.await, [[
        SELECT id, player_name, message, status, handled_by, created_at, handled_at
        FROM player_reports
        ORDER BY CASE status WHEN 'open' THEN 0 ELSE 1 END, created_at DESC
        LIMIT 100
    ]])
    if not ok then
        print('[rp_tablet_admin] Report query failed: ' .. tostring(reports))
        NotifyExtended(src, 'Impossible de charger les signalements.')
        return
    end
    TriggerClientEvent('rp_tablet_admin:client:reports', src, reports or {})
end)

RegisterNetEvent('rp_tablet_admin:server:updateReport', function(rawReportId, rawStatus)
    local src = source
    if not AllowExtendedAction(src, 'reports_update', 700) then return end
    local reportId = tonumber(rawReportId)
    local status = rawStatus == 'resolved' and 'resolved' or rawStatus == 'rejected' and 'rejected' or nil
    if not reportId or reportId < 1 or reportId % 1 ~= 0 or not status then
        NotifyExtended(src, 'Signalement ou statut invalide.')
        return
    end
    local staff = exports['rp_core']:GetPlayerFromId(src)
    local staffName = staff and (((staff.firstname or '') .. ' ' .. (staff.lastname or '')):gsub('^%s*(.-)%s*$', '%1'))
        or (GetPlayerName(src) or 'Staff')
    local ok, affected = pcall(MySQL.update.await, [[
        UPDATE player_reports
        SET status = ?, handled_by = ?, handled_at = CURRENT_TIMESTAMP
        WHERE id = ? AND status = 'open'
    ]], { status, staffName:sub(1, 64), reportId })
    if not ok then
        print('[rp_tablet_admin] Report update failed: ' .. tostring(affected))
        NotifyExtended(src, 'Impossible de mettre à jour le signalement.')
        return
    end
    if not affected or affected < 1 then
        NotifyExtended(src, 'Signalement introuvable ou déjà traité.')
        return
    end
    LogExtendedAction(src, 'report_' .. status, nil, 'Signalement #' .. reportId)
    TriggerClientEvent('rp_tablet_admin:client:reportUpdated', src, reportId, status)
    NotifyExtended(src, 'Signalement #' .. reportId .. (status == 'resolved' and ' marqué comme traité.' or ' rejeté.'), 'success')
end)
