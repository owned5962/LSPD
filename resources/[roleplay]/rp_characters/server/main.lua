local MAX_CHARACTERS = 3
local DefaultSpawn = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }

local function GetLicenseIdentifier(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if identifier and identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return nil
end

local function Trim(value)
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
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

local function DecodeJson(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or fallback
end

local function LoadCharacter(src, identifier, userGroup, char)
    if exports['rp_core']:GetPlayerFromId(src) then
        Notify(src, 'Un personnage est déjà chargé.')
        return
    end

    char.position = DecodeJson(char.position, DefaultSpawn)
    char.skin = DecodeJson(char.skin, {})
    char.group = userGroup or 'user'

    local player = exports['rp_core']:CreateRPPlayer(src, identifier, char)
    exports['rp_core']:GetAllPlayers()[src] = player
    player.syncClient()

    TriggerClientEvent('rp_characters:client:spawnPlayer', src, char.position)
    TriggerClientEvent('rp_characters:client:closeMenu', src)
    Notify(src, ('Bienvenue %s %s !'):format(char.firstname, char.lastname), 'success')
end

RegisterNetEvent('rp_characters:server:checkPlayer', function()
    local src = source
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

    local user = MySQL.single.await('SELECT identifier, `group` FROM users WHERE identifier = ?', { identifier })
    if not user then
        local license = identifier:gsub('^license:', '')
        local discord
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local value = GetPlayerIdentifier(src, i)
            if value and value:sub(1, 8) == 'discord:' then discord = value:gsub('^discord:', '') break end
        end
        MySQL.insert.await(
            'INSERT INTO users (identifier, license, discord, name, `group`) VALUES (?, ?, ?, ?, ?)',
            { identifier, license, discord, GetPlayerName(src) or 'Citoyen', 'user' }
        )
        user = { identifier = identifier, group = 'user' }
    else
        MySQL.update.await('UPDATE users SET name = ?, last_seen = CURRENT_TIMESTAMP WHERE identifier = ?',
            { GetPlayerName(src) or 'Citoyen', identifier })
    end

    local characters = MySQL.query.await(
        'SELECT id, char_id, firstname, lastname, dateofbirth, sex, height, cash, bank, job, job_grade, position, skin FROM characters WHERE identifier = ? ORDER BY char_id ASC',
        { identifier }
    ) or {}

    if #characters == 0 then
        TriggerClientEvent('rp_characters:client:openMenu', src, MAX_CHARACTERS)
    else
        TriggerClientEvent('rp_characters:client:openCharacterSelection', src, characters, MAX_CHARACTERS)
    end
end)

RegisterNetEvent('rp_characters:server:selectCharacter', function(slot)
    local src = source
    local identifier = GetLicenseIdentifier(src)
    slot = tonumber(slot)
    if not identifier or not slot or slot % 1 ~= 0 or slot < 1 or slot > MAX_CHARACTERS then
        Notify(src, 'Sélection de personnage invalide.')
        return
    end

    local user = MySQL.single.await('SELECT `group` FROM users WHERE identifier = ?', { identifier })
    if not user then
        Notify(src, 'Compte introuvable. Reconnectez-vous.')
        return
    end

    local char = MySQL.single.await(
        'SELECT id, char_id, firstname, lastname, dateofbirth, sex, height, cash, bank, job, job_grade, position, skin FROM characters WHERE identifier = ? AND char_id = ?',
        { identifier, slot }
    )
    if not char then
        Notify(src, 'Personnage introuvable.')
        return
    end

    LoadCharacter(src, identifier, user.group, char)
end)

RegisterNetEvent('rp_characters:server:createCharacter', function(data)
    local src = source
    local identifier = GetLicenseIdentifier(src)
    if not identifier or type(data) ~= 'table' then
        Notify(src, 'Données de création invalides.')
        return
    end
    if exports['rp_core']:GetPlayerFromId(src) or exports['rp_core']:GetPlayerByIdentifier(identifier) then
        Notify(src, 'Un personnage est déjà chargé.')
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

    local user = MySQL.single.await('SELECT `group` FROM users WHERE identifier = ?', { identifier })
    if not user then
        Notify(src, 'Compte introuvable. Reconnectez-vous.')
        return
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE identifier = ?', { identifier }) or 0
    if count >= MAX_CHARACTERS then
        Notify(src, ('Vous avez atteint la limite de %s personnages.'):format(MAX_CHARACTERS))
        return
    end

    local slot = (MySQL.scalar.await(
        'SELECT COALESCE(MIN(t.slot), 1) FROM (SELECT 1 AS slot UNION SELECT 2 UNION SELECT 3) t LEFT JOIN characters c ON c.char_id = t.slot AND c.identifier = ? WHERE c.id IS NULL',
        { identifier }
    ) or 1)
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
        local hairStyle, hairColor = tonumber(data.skin.hairStyle), tonumber(data.skin.hairColor)
        if hairStyle and hairStyle % 1 == 0 and hairStyle >= 0 and hairStyle <= 100 then skin.hairStyle = hairStyle end
        if hairColor and hairColor % 1 == 0 and hairColor >= 0 and hairColor <= 63 then skin.hairColor = hairColor end
        if type(data.skin.clothing) == 'string' and #data.skin.clothing <= 32 and not data.skin.clothing:find('[%c<>]') then
            skin.clothing = data.skin.clothing
        end
    end

    local charId = MySQL.insert.await(
        'INSERT INTO characters (identifier, char_id, firstname, lastname, dateofbirth, sex, height, cash, bank, job, job_grade, position, skin) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { identifier, slot, firstname, lastname, data.dateofbirth, data.gender, height,
          2500, 10000, 'unemployed', 0, json.encode(spawn), json.encode(skin) }
    )
    if not charId then
        Notify(src, 'Impossible d’enregistrer le personnage en base de données.')
        return
    end

    local char = {
        id = charId, char_id = slot, firstname = firstname, lastname = lastname,
        dateofbirth = data.dateofbirth, sex = data.gender, height = height,
        cash = 2500, bank = 10000, job = 'unemployed', job_grade = 0,
        position = spawn, skin = skin
    }
    LoadCharacter(src, identifier, user.group, char)
end)
