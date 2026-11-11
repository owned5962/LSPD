local AdminModes = {}
local function IsExtendedAdmin(src)
    if IsPlayerAceAllowed(src, 'rp_admin') then return true end
    local player = exports['rp_core']:GetPlayerFromId(src)
    return player ~= nil and (player.group == 'admin' or player.group == 'superadmin' or player.group == 'fondateur')
end

local function AllowExtendedAction(src, action, cooldown)
    return IsExtendedAdmin(src) and exports['rp_core']:CanPerformAction(src, 'admin:' .. action, cooldown or 500)
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
    if not AllowExtendedAction(src, 'give_weapon', 750) then return end
    local targetId = TargetId(rawTargetId)
    local weapon = type(rawWeapon) == 'string' and rawWeapon:upper() or ''
    local policyOk, allowed = pcall(function() return exports['rp_anticheat']:IsWeaponAllowed(weapon) end)
    if not targetId or not policyOk or allowed ~= true then
        NotifyExtended(src, 'Joueur ou arme non autorisée.')
        return
    end
    LogExtendedAction(src, 'give_weapon', targetId, weapon)
    TriggerClientEvent('rp_tablet_admin:client:giveWeapon', targetId, weapon)
    NotifyExtended(src, 'Arme attribuée au joueur ' .. targetId .. '.', 'success')
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
