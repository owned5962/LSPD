local function GetLicenseIdentifier(src)
    local count = GetNumPlayerIdentifiers(src)
    for i = 0, count - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if identifier and identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end
    return nil
end

local function Trim(value)
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function IsValidDate(value)
    if type(value) ~= 'string' or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return false
    end

    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day or year < 1900 or month < 1 or month > 12 or day < 1 or day > 31 then
        return false
    end

    local parsed = os.date('*t', os.time({ year = year, month = month, day = day, hour = 12 }))
    local today = os.date('*t')
    if parsed.year ~= year or parsed.month ~= month or parsed.day ~= day then
        return false
    end
    if year > today.year or (year == today.year and month > today.month) or
        (year == today.year and month == today.month and day > today.day) then
        return false
    end
    return true
end

local function NotifyCharacterError(src, message)
    TriggerClientEvent('rp_core:client:notify', src, message, 'error')
end

local InMemoryCharacters = {}

RegisterNetEvent('rp_characters:server:checkPlayer', function()
    local src = source
    local identifier = GetLicenseIdentifier(src)
    if not identifier then
        NotifyCharacterError(src, 'Identifiant FiveM license introuvable. Connexion refusée.')
        DropPlayer(src, 'Identifiant FiveM license introuvable.')
        return
    end

    local existingSession = exports['rp_core']:GetPlayerByIdentifier(identifier)
    if existingSession and existingSession.source ~= src then
        NotifyCharacterError(src, 'Une session est déjà active avec ce compte.')
        DropPlayer(src, 'Session déjà active pour ce compte.')
        return
    end

    if InMemoryCharacters[identifier] then
        local char = InMemoryCharacters[identifier]
        local rpPlayer = exports['rp_core']:CreateRPPlayer(src, identifier, char)
        exports['rp_core']:GetAllPlayers()[src] = rpPlayer
        rpPlayer.syncClient()
        TriggerClientEvent('rp_characters:client:spawnPlayer', src, { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 })
        TriggerClientEvent('rp_core:client:notify', src, 'Bon retour, ' .. char.firstname .. ' ' .. char.lastname .. ' !', 'success')
    else
        TriggerClientEvent('rp_characters:client:openMenu', src)
    end
end)

RegisterNetEvent('rp_characters:server:createCharacter', function(data)
    local src = source
    local identifier = GetLicenseIdentifier(src)
    if not identifier then
        NotifyCharacterError(src, 'Identifiant FiveM license introuvable.')
        return
    end
    if type(data) ~= 'table' then
        NotifyCharacterError(src, 'Données de personnage invalides.')
        return
    end
    if exports['rp_core']:GetPlayerFromId(src) or exports['rp_core']:GetPlayerByIdentifier(identifier) then
        NotifyCharacterError(src, 'Un personnage est déjà chargé pour ce compte.')
        return
    end
    if InMemoryCharacters[identifier] then
        NotifyCharacterError(src, 'Un personnage existe déjà pour ce compte.')
        return
    end

    local firstname = type(data.firstname) == 'string' and Trim(data.firstname) or ''
    local lastname = type(data.lastname) == 'string' and Trim(data.lastname) or ''
    if #firstname < 2 or #firstname > 32 or #lastname < 2 or #lastname > 32 or
        firstname:find('[%c<>]') or lastname:find('[%c<>]') then
        NotifyCharacterError(src, 'Prénom ou nom invalide (2 à 32 caractères).')
        return
    end

    if not IsValidDate(data.dateofbirth) then
        NotifyCharacterError(src, 'Date de naissance invalide.')
        return
    end

    local gender = data.gender
    if gender ~= 'm' and gender ~= 'f' then
        NotifyCharacterError(src, 'Genre invalide.')
        return
    end

    local height = tonumber(data.height)
    if not height or height % 1 ~= 0 or height < 120 or height > 220 then
        NotifyCharacterError(src, 'Taille invalide (120 à 220 cm).')
        return
    end

    local allowedSpawns = {
        airport = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 },
        train = { x = 432.2, y = -626.8, z = 28.5, heading = 220.0 },
        hospital = { x = 298.5, y = -584.5, z = 43.2, heading = 70.0 },
        jobcenter = { x = -268.3, y = -956.8, z = 31.2, heading = 205.0 }
    }
    local spawnPoint = type(data.spawnPoint) == 'string' and data.spawnPoint or 'airport'
    local spawnCoords = allowedSpawns[spawnPoint] or allowedSpawns.airport

    local skin = {}
    if type(data.skin) == 'table' then
        local hairStyle = tonumber(data.skin.hairStyle)
        local hairColor = tonumber(data.skin.hairColor)
        local clothing = data.skin.clothing
        if hairStyle and hairStyle % 1 == 0 and hairStyle >= 0 and hairStyle <= 100 then
            skin.hairStyle = hairStyle
        end
        if hairColor and hairColor % 1 == 0 and hairColor >= 0 and hairColor <= 63 then
            skin.hairColor = hairColor
        end
        if type(clothing) == 'string' and #clothing <= 32 and not clothing:find('[%c<>]') then
            skin.clothing = clothing
        end
    end

    local charRecord = {
        id = 1,
        firstname = firstname,
        lastname = lastname,
        dateofbirth = data.dateofbirth,
        sex = gender,
        height = height,
        cash = 2500,
        bank = 10000,
        job = 'unemployed',
        job_grade = 0,
        group = 'user',
        skin = skin
    }

    InMemoryCharacters[identifier] = charRecord

    local rpPlayer = exports['rp_core']:CreateRPPlayer(src, identifier, charRecord)
    exports['rp_core']:GetAllPlayers()[src] = rpPlayer
    rpPlayer.syncClient()

    TriggerClientEvent('rp_characters:client:spawnPlayer', src, spawnCoords)
    TriggerClientEvent('rp_core:client:notify', src, 'Personnage enregistré avec succès ! Bienvenue à Los Santos.', 'success')
end)
