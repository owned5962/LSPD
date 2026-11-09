local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(tonumber(src))
end

local function isOfficerOnDuty(src)
    local player = getPlayer(src)
    if not player or player.job ~= 'police' then return false end
    if GetResourceState('job_police') ~= 'started' then return false end
    local ok, onDuty = pcall(function()
        return exports['job_police']:IsOnDuty(src)
    end)
    return ok and onDuty == true
end

local function getDispatches()
    if GetResourceState('rp_crime') ~= 'started' then return {} end
    local ok, calls = pcall(function()
        return exports['rp_crime']:GetActiveDispatches()
    end)
    return ok and type(calls) == 'table' and calls or {}
end

local function buildData(requester)
    local citizens, officers = {}, {}
    local all = exports['rp_core']:GetAllPlayers() or {}
    for rawId, player in pairs(all) do
        local id = tonumber(rawId)
        if id and player then
            local first = tostring(player.firstname or '')
            local last = tostring(player.lastname or '')
            local name = (first .. ' ' .. last):gsub('^%s*(.-)%s*$', '%1')
            if name == '' then name = GetPlayerName(id) or ('Citoyen #' .. id) end
            local entry = {
                id = id,
                name = name,
                job = tostring(player.job or 'unemployed'),
                grade = tonumber(player.jobGrade) or 0,
                ping = GetPlayerPing(id) or 0
            }
            citizens[#citizens + 1] = entry
            if entry.job == 'police' and isOfficerOnDuty(id) then
                officers[#officers + 1] = entry
            end
        end
    end
    table.sort(citizens, function(a, b) return a.name:lower() < b.name:lower() end)
    table.sort(officers, function(a, b) return a.id < b.id end)
    return {
        citizens = citizens,
        officers = officers,
        dispatches = getDispatches(),
        officer = (function()
            local current = getPlayer(requester)
            local name = current and (tostring(current.firstname or '') .. ' ' .. tostring(current.lastname or '')):gsub('^%s*(.-)%s*
            citizens = #citizens,
            officers = #officers,
            dispatches = #getDispatches()
        }
    }
end

RegisterNetEvent('rp_police_mdt:server:requestOpen', function()
    local src = source
    if not isOfficerOnDuty(src) then
        TriggerClientEvent('rp_core:client:notify', src,
            'Accès refusé : tablette réservée aux policiers en service.', 'error')
        return
    end
    TriggerClientEvent('rp_police_mdt:client:open', src, buildData(src))
end)

RegisterNetEvent('rp_police_mdt:server:requestData', function()
    local src = source
    if not isOfficerOnDuty(src) then
        TriggerClientEvent('rp_police_mdt:client:close', src)
        TriggerClientEvent('rp_core:client:notify', src, 'Votre accès MDT a été révoqué.', 'error')
        return
    end
    TriggerClientEvent('rp_police_mdt:client:updateData', src, buildData(src))
end)

RegisterNetEvent('rp_police_mdt:server:locateCitizen', function(rawId)
    local src = source
    if not isOfficerOnDuty(src) then return end
    local targetId = tonumber(rawId)
    if not targetId or targetId % 1 ~= 0 or targetId < 1 or not GetPlayerName(targetId) then
        TriggerClientEvent('rp_core:client:notify', src, 'Citoyen introuvable ou hors ligne.', 'error')
        return
    end
    local ped = GetPlayerPed(targetId)
    if ped == 0 or not DoesEntityExist(ped) then
        TriggerClientEvent('rp_core:client:notify', src, 'Position du citoyen indisponible.', 'error')
        return
    end
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('rp_police_mdt:client:waypoint', src,
        { x = coords.x, y = coords.y, z = coords.z }, 'citoyen #' .. targetId)
end)

AddEventHandler('playerDropped', function()
    -- No per-player server state is retained by the MDT.
end)
, '%1') or ''
            if name == '' then name = GetPlayerName(requester) or 'Officier' end
            return { id = tonumber(requester), name = name, grade = tonumber(current and current.jobGrade) or 0 }
        end)(),
        totals = {
            citizens = #citizens,
            officers = #officers,
            dispatches = #getDispatches()
        }
    }
end

RegisterNetEvent('rp_police_mdt:server:requestOpen', function()
    local src = source
    if not isOfficerOnDuty(src) then
        TriggerClientEvent('rp_core:client:notify', src,
            'Accès refusé : tablette réservée aux policiers en service.', 'error')
        return
    end
    TriggerClientEvent('rp_police_mdt:client:open', src, buildData())
end)

RegisterNetEvent('rp_police_mdt:server:requestData', function()
    local src = source
    if not isOfficerOnDuty(src) then
        TriggerClientEvent('rp_police_mdt:client:close', src)
        TriggerClientEvent('rp_core:client:notify', src, 'Votre accès MDT a été révoqué.', 'error')
        return
    end
    TriggerClientEvent('rp_police_mdt:client:updateData', src, buildData())
end)

RegisterNetEvent('rp_police_mdt:server:locateCitizen', function(rawId)
    local src = source
    if not isOfficerOnDuty(src) then return end
    local targetId = tonumber(rawId)
    if not targetId or targetId % 1 ~= 0 or targetId < 1 or not GetPlayerName(targetId) then
        TriggerClientEvent('rp_core:client:notify', src, 'Citoyen introuvable ou hors ligne.', 'error')
        return
    end
    local ped = GetPlayerPed(targetId)
    if ped == 0 or not DoesEntityExist(ped) then
        TriggerClientEvent('rp_core:client:notify', src, 'Position du citoyen indisponible.', 'error')
        return
    end
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('rp_police_mdt:client:waypoint', src,
        { x = coords.x, y = coords.y, z = coords.z }, 'citoyen #' .. targetId)
end)

AddEventHandler('playerDropped', function()
    -- No per-player server state is retained by the MDT.
end)
