RegisterNetEvent('rp_clothing:purchaseHair', function(rawStyle, rawColor, rawHighlight)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    local style, color, highlight = tonumber(rawStyle), tonumber(rawColor), tonumber(rawHighlight) or 0
    if not player or not style or not color or style % 1 ~= 0 or color % 1 ~= 0
        or highlight % 1 ~= 0 or style < 0 or style > 200 or color < 0 or color > 63
        or highlight < 0 or highlight > 63 then
        TriggerClientEvent('rp_clothing:barberPurchaseResult', src, { success = false, message = 'Choix de coiffure invalide.' })
        return
    end

    local price = 100
    if type(player.removeCash) ~= 'function' or not player.removeCash(price) then
        TriggerClientEvent('rp_clothing:barberPurchaseResult', src, { success = false, message = 'Fonds insuffisants : 100 $ en liquide requis.' })
        return
    end

    local skin = type(player.skin) == 'table' and player.skin or {}
    local previousStyle, previousColor, previousHighlight = skin.hairStyle, skin.hairColor, skin.hairHighlight
    skin.hairStyle, skin.hairColor, skin.hairHighlight = style, color, highlight
    local ok, result = pcall(MySQL.update.await,
        'UPDATE characters SET skin = ? WHERE id = ? AND identifier = ?',
        { json.encode(skin), player.charId, player.identifier }
    )
    if not ok or type(result) ~= 'number' or result < 0 then
        skin.hairStyle, skin.hairColor, skin.hairHighlight = previousStyle, previousColor, previousHighlight
        player.addCash(price)
        TriggerClientEvent('rp_clothing:barberPurchaseResult', src, { success = false, message = 'Sauvegarde impossible : paiement remboursé.' })
        print(('[rp_clothing] Barber save failed for character %s: %s'):format(player.charId, tostring(result)))
        return
    end

    player.skin = skin
    TriggerClientEvent('rp_clothing:barberPurchaseResult', src, { success = true, message = 'Nouvelle coupe enregistrée pour 100 $.' })
end)

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

    local ok, result = pcall(function()
        local committed = MySQL.transaction.await({
            {
                query = 'INSERT INTO user_outfits (identifier, character_id, name, skin_data) VALUES (?, ?, ?, ?)',
                values = { player.identifier, player.charId, name, json.encode(appearance) }
            },
            {
                query = 'UPDATE characters SET skin = ? WHERE id = ? AND identifier = ?',
                values = { json.encode(skin), player.charId, player.identifier }
            }
        })
        if not committed then error('Outfit transaction rejected') end
    end)

    if not ok then
        player.addCash(150)
        Notify(src, 'Enregistrement impossible : paiement annulé.', 'error')
        print(('[rp_clothing] Outfit save failed for %s: %s'):format(player.identifier, tostring(result)))
        return
    end

    player.skin = skin
    Notify(src, ('Tenue « %s » enregistrée et appliquée.'):format(name), 'success')
end)


RegisterNetEvent('rp_clothing:requestOutfits', function()
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player then return end

    local ok, rows = pcall(MySQL.query.await,
        'SELECT id, name, skin_data FROM user_outfits WHERE identifier = ? AND character_id = ? ORDER BY created_at DESC, id DESC LIMIT 20',
        { player.identifier, player.charId }
    )
    if not ok then
        Notify(src, 'Impossible de charger vos tenues sauvegardées.', 'error')
        print(('[rp_clothing] Outfit list failed for character %s: %s'):format(player.charId, tostring(rows)))
        return
    end

    local outfits = {}
    for _, row in ipairs(rows or {}) do
        local decoded = row.skin_data
        if type(decoded) == 'string' then
            local decodedOk, value = pcall(json.decode, decoded)
            decoded = decodedOk and value or nil
        end
        if SanitizeAppearance(decoded) then
            outfits[#outfits + 1] = { id = tonumber(row.id), name = tostring(row.name or 'Tenue') }
        end
    end
    TriggerClientEvent('rp_clothing:receiveOutfits', src, outfits)
end)

RegisterNetEvent('rp_clothing:applySavedOutfit', function(rawOutfitId)
    local src = source
    local player = exports['rp_core']:GetPlayerFromId(src)
    local outfitId = tonumber(rawOutfitId)
    if not player or not outfitId or outfitId % 1 ~= 0 or outfitId < 1 then return end

    local ok, row = pcall(MySQL.single.await,
        'SELECT skin_data FROM user_outfits WHERE id = ? AND identifier = ? AND character_id = ?',
        { outfitId, player.identifier, player.charId }
    )
    if not ok or not row then
        Notify(src, 'Tenue introuvable.', 'error')
        return
    end

    local decoded = row.skin_data
    if type(decoded) == 'string' then
        local decodedOk, value = pcall(json.decode, decoded)
        decoded = decodedOk and value or nil
    end
    local appearance = SanitizeAppearance(decoded)
    if not appearance then
        Notify(src, 'Cette tenue contient des données invalides.', 'error')
        return
    end

    local skin = type(player.skin) == 'table' and player.skin or {}
    skin.components, skin.props = appearance.components, appearance.props
    skin.hairStyle, skin.hairColor = appearance.hairStyle, appearance.hairColor
    local saved, result = pcall(MySQL.update.await,
        'UPDATE characters SET skin = ? WHERE id = ? AND identifier = ?',
        { json.encode(skin), player.charId, player.identifier }
    )
    if not saved then
        Notify(src, 'Impossible de sauvegarder cette tenue.', 'error')
        print(('[rp_clothing] Outfit apply failed for character %s: %s'):format(player.charId, tostring(result)))
        return
    end

    player.skin = skin
    TriggerClientEvent('rp_clothing:applyAppearance', src, appearance)
    Notify(src, 'Tenue sauvegardée appliquée.', 'success')
end)
