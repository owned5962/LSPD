local function Notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function SanitizeAppearance(data)
    if type(data) ~= 'table' or type(data.components) ~= 'table' or type(data.props) ~= 'table' then
        return nil
    end

    local clean = { components = {}, props = {} }
    for component = 0, 11 do
        local item = data.components[tostring(component)]
        if type(item) ~= 'table' then return nil end
        local drawable, texture = tonumber(item.drawable), tonumber(item.texture)
        if not drawable or not texture or drawable % 1 ~= 0 or texture % 1 ~= 0 or drawable < 0 or drawable > 500 or texture < 0 or texture > 100 then
            return nil
        end
        clean.components[tostring(component)] = { drawable = drawable, texture = texture }
    end

    for prop = 0, 7 do
        local item = data.props[tostring(prop)]
        if type(item) ~= 'table' then return nil end
        local drawable, texture = tonumber(item.drawable), tonumber(item.texture)
        if not drawable or not texture or drawable % 1 ~= 0 or texture % 1 ~= 0 or drawable < -1 or drawable > 500 or texture < 0 or texture > 100 then
            return nil
        end
        clean.props[tostring(prop)] = { drawable = drawable, texture = texture }
    end

    clean.hairStyle = tonumber(data.hairStyle) or 0
    clean.hairColor = math.max(0, math.min(63, tonumber(data.hairColor) or 0))
    return clean
end

RegisterNetEvent('rp_clothing:saveOutfit', function(name, skinData)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then
        Notify(src, 'Personnage non chargé.', 'error')
        return
    end

    if type(name) ~= 'string' then name = 'Nouvelle tenue' end
    name = name:gsub('[%c<>]', ''):sub(1, 50):match('^%s*(.-)%s*$')
    if name == '' then name = 'Nouvelle tenue' end

    local appearance = SanitizeAppearance(skinData)
    if not appearance then
        Notify(src, 'Données de tenue invalides.', 'error')
        return
    end

    if not player.removeCash or not player.removeCash(150) then
        Notify(src, 'Fonds insuffisants en liquide (150 $ requis).', 'error')
        return
    end

    local skin = type(player.skin) == 'table' and player.skin or {}
    skin.components = appearance.components
    skin.props = appearance.props
    skin.hairStyle = appearance.hairStyle
    skin.hairColor = appearance.hairColor
    player.skin = skin

    local ok, result = pcall(function()
        MySQL.insert.await(
            'INSERT INTO user_outfits (identifier, character_id, name, skin_data) VALUES (?, ?, ?, ?)',
            { player.identifier, player.charId, name, json.encode(appearance) }
        )
        MySQL.update.await(
            'UPDATE characters SET skin = ? WHERE id = ? AND identifier = ?',
            { json.encode(skin), player.charId, player.identifier }
        )
    end)

    if not ok then
        player.addCash(150)
        Notify(src, 'Enregistrement impossible : paiement annulé.', 'error')
        print(('[rp_clothing] Outfit save failed for %s: %s'):format(player.identifier, tostring(result)))
        return
    end

    Notify(src, ('Tenue « %s » enregistrée et appliquée.'):format(name), 'success')
end)
