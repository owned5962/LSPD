local MAX_CHARACTERS = 3
local DefaultSpawn = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }

local function GetLicenseIdentifier(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if identifier and identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return nil
end

local function GetEffectiveUserGroup(src, databaseGroup)
    -- ACE is the source of truth for the founder role; never trust client data.
    if IsPlayerAceAllowed(src, 'rp_founder') then return 'fondateur' end
    return databaseGroup or 'user'
end

local function Trim(value)
    if type(value) ~= 'string' then return '' end
    return value:match('^%s*(.-)%s*$') or ''
end

local function IsValidDate(value)
    if type(value) ~= 'string' or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then return false end
    local y, m, d = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or not m or not d or y < 1900 or m < 1 or m > 12 or d < 1 or d > 31 then return false end
    local parsed = os.date('*t', os.time({ year = y, month = m, day = d, hour = 12 }))
    local today = os.date('*t')
    return parsed.year == y and parsed.month == m and parsed.day == d and
        (y < today.year or (y == today.year and m < today.month) or
        (y == today.year and m == today.month and d <= today.day))
end

local function Notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'error')
end

local function SafeDatabaseCall(src, operation, callback)
    local ok, result = pcall(callback)
    if not ok then
        print(('[rp_characters] %s failed for player %s: %s'):format(operation, tostring(src), tostring(result)))
        local message = 'La base de données est temporairement indisponible. Vérifiez oxmysql et la console serveur.'
        Notify(src, message, 'error')
        TriggerClientEvent('rp_characters:client:bootError', src, message)
        return false, nil
    end
    return true, result
end

local function DecodeJson(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or fallback
end

-- The onboarding state is stored in this character's metadata, not on the account.
-- A player who leaves before finishing will see the tutorial again on next login.
local tutorialStarted = {}

RegisterNetEvent('rp_characters:server:requestTutorial', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'character:tutorial_request', 5000) then return end
    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or type(player.metadata) ~= 'table' then return end
    if player.metadata.tutorialCompleted == true then return end

    tutorialStarted[src] = true
    TriggerClientEvent('rp_characters:client:startTutorial', src)
end)

RegisterNetEvent('rp_characters:server:completeTutorial', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'character:tutorial_complete', 3000) then return end
    if tutorialStarted[src] ~= true then return end

    local player = exports['rp_core']:GetPlayerFromId(src)
    if not player or type(player.metadata) ~= 'table' then
        tutorialStarted[src] = nil
        return
    end

    local previous = player.metadata.tutorialCompleted
    player.metadata.tutorialCompleted = true
    if not player.save() then
        player.metadata.tutorialCompleted = previous
        Notify(src, 'La progression du tutoriel n’a pas pu être sauvegardée. Il sera proposé à votre prochaine connexion.', 'warning')
        tutorialStarted[src] = nil
        return
    end

    tutorialStarted[src] = nil
    Notify(src, 'Tutoriel terminé ! Bonne aventure à Los Santos.', 'success')
end)

AddEventHandler('playerDropped', function()
    tutorialStarted[source] = nil
end)

local function LoadCharacter(src, identifier, userGroup, char)
    if exports['rp_core']:IsCharacterSavePending(char.id) then
        Notify(src, 'Votre dernière sauvegarde est en cours. Réessayez dans quelques secondes.', 'warning')
        return
    end

    local currentSession = exports['rp_core']:GetPlayerByIdentifier(identifier)
    if currentSession then
        if currentSession.source ~= src then
            DropPlayer(src, 'Une session est déjà active avec ce compte.')
        end
        return
    end
    if exports['rp_core']:GetPlayerFromId(src) then
        Notify(src, 'Un personnage est déjà chargé.')
        return
    end

    char.position = DecodeJson(char.position, DefaultSpawn)
    char.skin = DecodeJson(char.skin, {})
    char.group = GetEffectiveUserGroup(src, userGroup)

    -- Keep export/runtime errors visible in the server console instead of silently
    -- leaving the client waiting after character selection.
    local loadOk, player = pcall(function()
        local createdPlayer = exports['rp_core']:CreateRPPlayer(src, identifier, char)
        if not exports['rp_core']:RegisterPlayer(src, createdPlayer) then
            error('Central player registration rejected')
        end
        createdPlayer.syncClient()
        TriggerClientEvent('rp_core:client:playerLoaded', src, {
            source = src,
            charId = createdPlayer.charId,
            characterSlot = createdPlayer.slot,
            name = createdPlayer.name
        })
        return createdPlayer
    end)
    if not loadOk or not player then
        pcall(function()
            exports['rp_core']:UnregisterPlayer(src, identifier)
        end)
        print(('[rp_characters] Failed to initialize character for player %s: %s')
            :format(tostring(src), tostring(player)))
        Notify(src, 'Impossible de finaliser le chargement du personnage. Consultez la console serveur.', 'error')
        return
    end

    -- Publish the saved RP identity as the server player name (scoreboard/player list).
    local roleplayName = tostring(char.firstname or '') .. ' ' .. tostring(char.lastname or '')
    if roleplayName ~= ' ' then
        local nameOk, nameError = pcall(function()
            SetPlayerName(src, roleplayName)
        end)
        if not nameOk then
            print(('[rp_characters] Unable to publish RP name for player %s: %s'):format(tostring(src), tostring(nameError)))
        end
    end
    print(('[rp_characters] Character loaded for player %s; sending spawn event.'):format(tostring(src)))
    TriggerClientEvent('rp_characters:client:spawnPlayer', src, char.position, char.sex, char.skin)
    TriggerClientEvent('rp_characters:client:closeMenu', src)
    Notify(src, ('Bienvenue %s %s !'):format(char.firstname, char.lastname), 'success')
end

RegisterNetEvent('rp_characters:server:checkPlayer', function()
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'character:check_player', 5000) then
        -- Duplicate bootstrap requests are expected when core and character
        -- resources start together. Ignore them instead of showing a false error.
        return
    end
    local identifier = GetLicenseIdentifier(src)
    if not identifier then
        DropPlayer(src, 'Identifiant FiveM license introuvable.')
        return
    end

    local existing = exports['rp_core']:GetPlayerByIdentifier(identifier)
    if existing and existing.source ~= src then
        DropPlayer(src, 'Une session est déjà active avec ce compte.')
        return
    end
    if exports['rp_core']:GetPlayerFromId(src) then
        TriggerClientEvent('rp_characters:client:resumeLoadedCharacter', src)
        return
    end

    local dbOk, user = SafeDatabaseCall(src, 'account lookup', function()
        return MySQL.single.await('SELECT identifier, `group` FROM users WHERE identifier = ?', { identifier })
    end)
    if not dbOk then return end
    if not user then
        local license = identifier:gsub('^license:', '')
        local discord
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local value = GetPlayerIdentifier(src, i)
            if value and value:sub(1, 8) == 'discord:' then discord = value:gsub('^discord:', '') break end
        end
        local insertOk, insertResult = pcall(MySQL.insert.await,
            'INSERT IGNORE INTO users (identifier, license, discord, name, `group`) VALUES (?, ?, ?, ?, ?)',
            { identifier, license, discord, GetPlayerName(src) or 'Citoyen', 'user' }
        )
        if not insertOk then
            print(('[rp_characters] Account creation failed for %s: %s'):format(identifier, tostring(insertResult)))
            local message = 'Impossible de créer ou charger votre compte. Vérifiez la base de données et la console serveur.'
            Notify(src, message)
            TriggerClientEvent('rp_characters:client:bootError', src, message)
            return
        end
        local reloadOk
        reloadOk, user = SafeDatabaseCall(src, 'account reload', function()
            return MySQL.single.await('SELECT identifier, `group` FROM users WHERE identifier = ?', { identifier })
        end)
        if not reloadOk then return end
        if not user then
            local message = 'Compte introuvable après sa création. Vérifiez la table users.'
            Notify(src, message)
            TriggerClientEvent('rp_characters:client:bootError', src, message)
            return
        end
    else
        local updateOk = SafeDatabaseCall(src, 'last-seen update', function()
            return MySQL.update.await('UPDATE users SET name = ?, last_seen = CURRENT_TIMESTAMP WHERE identifier = ?',
                { GetPlayerName(src) or 'Citoyen', identifier })
        end)
        if not updateOk then return end
    end

    local charactersOk, characters = SafeDatabaseCall(src, 'character list query', function()
        return MySQL.query.await(
            'SELECT id, char_id, firstname, lastname, dateofbirth, sex, height, phone_number, cash, bank, job, job_grade, position, skin, metadata, is_dead FROM characters WHERE identifier = ? ORDER BY char_id ASC',
            { identifier }
        )
    end)
    if not charactersOk then return end
    characters = characters or {}

    if #characters == 0 then
        TriggerClientEvent('rp_characters:client:openMenu', src, MAX_CHARACTERS)
    else
        TriggerClientEvent('rp_characters:client:openCharacterSelection', src, characters, MAX_CHARACTERS)
    end
end)

RegisterNetEvent('rp_characters:server:selectCharacter', function(slot)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'character:select', 3000) then return end
    local identifier = GetLicenseIdentifier(src)
    slot = tonumber(slot)
    if not identifier or not slot or slot % 1 ~= 0 or slot < 1 or slot > MAX_CHARACTERS then
        Notify(src, 'Sélection de personnage invalide.')
        return
    end

    local userOk, user = SafeDatabaseCall(src, 'character account lookup', function()
        return MySQL.single.await('SELECT `group` FROM users WHERE identifier = ?', { identifier })
    end)
    if not userOk then return end
    if not user then
        Notify(src, 'Compte introuvable. Reconnectez-vous.')
        return
    end

    local charOk, char = SafeDatabaseCall(src, 'character selection query', function()
        return MySQL.single.await(
            'SELECT id, char_id, firstname, lastname, dateofbirth, sex, height, phone_number, cash, bank, job, job_grade, position, skin, metadata, is_dead FROM characters WHERE identifier = ? AND char_id = ?',
            { identifier, slot }
        )
    end)
    if not charOk then return end
    if not char then
        Notify(src, 'Personnage introuvable.')
        return
    end

    LoadCharacter(src, identifier, GetEffectiveUserGroup(src, user.group), char)
end)

RegisterNetEvent('rp_characters:server:createCharacter', function(data)
    local src = source
    if not exports['rp_core']:CanPerformAction(src, 'character:create', 5000) then return end
    local identifier = GetLicenseIdentifier(src)
    if not identifier or type(data) ~= 'table' then
        Notify(src, 'Données de création invalides.')
        return
    end
    local activeSession = exports['rp_core']:GetPlayerByIdentifier(identifier)
    if exports['rp_core']:GetPlayerFromId(src) or activeSession then
        Notify(src, 'Une session est déjà active pour ce compte.')
        return
    end

    local firstname = type(data.firstname) == 'string' and Trim(data.firstname) or ''
    local lastname = type(data.lastname) == 'string' and Trim(data.lastname) or ''
    if #firstname < 2 or #firstname > 32 or #lastname < 2 or #lastname > 32 or
        firstname:find('[%c<>]') or lastname:find('[%c<>]') then
        Notify(src, 'Prénom ou nom invalide (2 à 32 caractères).')
        return
    end
    if not IsValidDate(data.dateofbirth) then
        Notify(src, 'Date de naissance invalide.')
        return
    end
    if data.gender ~= 'm' and data.gender ~= 'f' then
        Notify(src, 'Genre invalide.')
        return
    end

    local height = tonumber(data.height)
    if not height or height % 1 ~= 0 or height < 120 or height > 220 then
        Notify(src, 'Taille invalide (120 à 220 cm).')
        return
    end

    local userOk, user = SafeDatabaseCall(src, 'character creation account lookup', function()
        return MySQL.single.await('SELECT `group` FROM users WHERE identifier = ?', { identifier })
    end)
    if not userOk then return end
    if not user then
        Notify(src, 'Compte introuvable. Reconnectez-vous.')
        return
    end

    local countOk, count = SafeDatabaseCall(src, 'character count query', function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE identifier = ?', { identifier })
    end)
    if not countOk then return end
    count = count or 0
    if count >= MAX_CHARACTERS then
        Notify(src, ('Vous avez atteint la limite de %s personnages.'):format(MAX_CHARACTERS))
        return
    end

    local slotOk, slot = SafeDatabaseCall(src, 'character slot query', function()
        return MySQL.scalar.await(
            'SELECT COALESCE(MIN(t.slot), 1) FROM (SELECT 1 AS slot UNION SELECT 2 UNION SELECT 3) t LEFT JOIN characters c ON c.char_id = t.slot AND c.identifier = ? WHERE c.id IS NULL',
            { identifier }
        )
    end)
    if not slotOk then return end
    slot = slot or 1
    slot = tonumber(slot) or 1

    local allowedSpawns = {
        airport = DefaultSpawn,
        train = { x = 432.2, y = -626.8, z = 28.5, heading = 220.0 },
        hospital = { x = 298.5, y = -584.5, z = 43.2, heading = 70.0 },
        jobcenter = { x = -268.3, y = -956.8, z = 31.2, heading = 205.0 }
    }
    local spawnKey = type(data.spawnPoint) == 'string' and data.spawnPoint or 'airport'
    local spawn = allowedSpawns[spawnKey] or DefaultSpawn

    local skin = {}
    if type(data.skin) == 'table' then
        local input = data.skin
        local hairStyle, hairColor = tonumber(input.hairStyle), tonumber(input.hairColor)
        if hairStyle and hairStyle % 1 == 0 and hairStyle >= 0 and hairStyle <= 100 then skin.hairStyle = hairStyle end
        if hairColor and hairColor % 1 == 0 and hairColor >= 0 and hairColor <= 63 then skin.hairColor = hairColor end
        if type(input.clothing) == 'string' and #input.clothing <= 32 and not input.clothing:find('[%c<>]') then skin.clothing = input.clothing end
        local function safeNumber(value, minimum, maximum, integer)
            local number = tonumber(value)
            if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
            if integer then number = math.floor(number) end
            return math.max(minimum, math.min(maximum, number))
        end
        local blend = type(input.headBlend) == 'table' and input.headBlend or {}
        skin.headBlend = {
            shapeFirst = safeNumber(blend.shapeFirst, 0, 45, true) or 0,
            shapeSecond = safeNumber(blend.shapeSecond, 0, 45, true) or 21,
            shapeThird = safeNumber(blend.shapeThird, 0, 45, true) or 0,
            skinFirst = safeNumber(blend.skinFirst, 0, 45, true) or 0,
            skinSecond = safeNumber(blend.skinSecond, 0, 45, true) or 21,
            skinThird = safeNumber(blend.skinThird, 0, 45, true) or 0,
            shapeMix = safeNumber(blend.shapeMix, 0, 1, false) or 0.5,
            skinMix = safeNumber(blend.skinMix, 0, 1, false) or 0.5,
            thirdMix = safeNumber(blend.thirdMix, 0, 1, false) or 0.0
        }
        skin.faceFeatures = {}
        if type(input.faceFeatures) == 'table' then
            for feature = 0, 19 do
                skin.faceFeatures[tostring(feature)] = safeNumber(input.faceFeatures[tostring(feature)] or input.faceFeatures[feature], -1, 1, false) or 0.0
            end
        end
        skin.overlays = {}
        if type(input.overlays) == 'table' then
            for _, overlay in ipairs({ 1, 2 }) do
                local item = input.overlays[tostring(overlay)] or input.overlays[overlay]
                if type(item) == 'table' then
                    skin.overlays[tostring(overlay)] = {
                        index = safeNumber(item.index, 0, 33, true) or 0,
                        opacity = safeNumber(item.opacity, 0, 1, false) or 1.0,
                        color = safeNumber(item.color, 0, 63, true) or 0,
                        secondColor = safeNumber(item.secondColor, 0, 63, true) or 0
                    }
                end
            end
        end
        skin.eyeColor = safeNumber(input.eyeColor, 0, 31, true) or 0
    end

    local insertOk, charId = pcall(MySQL.insert.await,
        'INSERT INTO characters (identifier, char_id, firstname, lastname, dateofbirth, sex, height, cash, bank, job, job_grade, position, skin) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { identifier, slot, firstname, lastname, data.dateofbirth, data.gender, height,
          2500, 10000, 'unemployed', 0, json.encode(spawn), json.encode(skin) }
    )
    if not insertOk or not charId then
        Notify(src, 'Impossible d’enregistrer le personnage en base de données.')
        return
    end

    local char = {
        id = charId, char_id = slot, firstname = firstname, lastname = lastname,
        dateofbirth = data.dateofbirth, sex = data.gender, height = height,
        phone_number = nil, is_dead = 0,
        cash = 2500, bank = 10000, job = 'unemployed', job_grade = 0,
        position = spawn, skin = skin
    }
    LoadCharacter(src, identifier, user.group, char)
end)