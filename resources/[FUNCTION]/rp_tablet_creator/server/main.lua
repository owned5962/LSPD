local function isCreator(src)
    if IsPlayerAceAllowed(src, 'rp_creator') or IsPlayerAceAllowed(src, 'rp_admin') then return true end
    local player = exports['rp_core']:GetPlayerFromId(src)
    return player ~= nil and (player.group == 'superadmin' or player.group == 'fondateur')
end

local function reply(src, message, success)
    TriggerClientEvent('rp_tablet_creator:client:result', src, message, success == true)
end

RegisterNetEvent('rp_tablet_creator:server:requestOpen', function()
    local src = source
    if not isCreator(src) then
        reply(src, 'Accès réservé aux créateurs et fondateurs.', false)
        return
    end
    local player = exports['rp_core']:GetPlayerFromId(src)
    local role = player and player.group or 'Créateur'
    TriggerClientEvent('rp_tablet_creator:client:open', src, role)
end)

RegisterNetEvent('rp_tablet_creator:server:setWorld', function(weather, rawHours, rawMinutes)
    local src = source
    if not isCreator(src) then return end

    local allowedWeather = {
        EXTRASUNNY = true, CLEAR = true, CLOUDS = true, SMOG = true, FOGGY = true,
        OVERCAST = true, RAIN = true, THUNDER = true, CLEARING = true, NEUTRAL = true,
        SNOW = true, BLIZZARD = true, SNOWLIGHT = true, XMAS = true, HALLOWEEN = true
    }
    local hasWeather = type(weather) == 'string' and weather ~= ''
    if hasWeather and not allowedWeather[weather] then
        reply(src, 'Type de météo non autorisé.', false)
        return
    end

    local hasTime = rawHours ~= nil or rawMinutes ~= nil
    local hours, minutes
    if hasTime then
        hours, minutes = tonumber(rawHours), tonumber(rawMinutes)
        if not hours or not minutes or hours % 1 ~= 0 or minutes % 1 ~= 0
            or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then
            reply(src, 'Heure invalide. Utilisez un format de 00:00 à 23:59.', false)
            return
        end
    end
    if not hasWeather and not hasTime then
        reply(src, 'Aucun changement demandé.', false)
        return
    end
    if hasWeather then TriggerClientEvent('rp_tablet_admin:client:syncWeather', -1, weather) end
    if hasTime then TriggerClientEvent('rp_tablet_admin:client:syncTime', -1, hours, minutes) end
    reply(src, 'Météo et heure du serveur mises à jour.', true)
end)

RegisterNetEvent('rp_tablet_creator:server:broadcast', function(rawMessage)
    local src = source
    if not isCreator(src) then return end
    if type(rawMessage) ~= 'string' then reply(src, 'Annonce invalide.', false); return end
    local message = rawMessage:gsub('[%c]', ' '):sub(1, 300)
    if message == '' then reply(src, 'Le message ne peut pas être vide.', false); return end
    TriggerClientEvent('chat:addMessage', -1, { color = { 80, 160, 255 }, args = { '[ANNONCE CRÉATEUR]', message } })
    TriggerClientEvent('rp_core:client:notify', -1, 'ANNONCE : ' .. message, 'info')
    reply(src, 'Annonce diffusée à tous les joueurs.', true)
end)
