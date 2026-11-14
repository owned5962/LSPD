local function SelectCharacter(src, slot)
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
end

RegisterNetEvent('rp_characters:server:selectCharacter', function(slot)
    local src = source
    local ok, err = xpcall(SelectCharacter, debug.traceback, src, slot)
    if not ok then
        print(('[rp_characters] Character selection failed for player %s: %s')
            :format(tostring(src), tostring(err)))
        local message = 'La sélection du personnage a échoué côté serveur. Consultez la console FXServer.'
        Notify(src, message, 'error')
        TriggerClientEvent('rp_characters:client:bootError', src, message)
    end
end)

local function CreateCharacter(src, data)
    if not exports['rp_core']:CanPerformAction(src, 'character:create', 5000) then
        CreationError(src, 'Veuillez patienter quelques secondes avant de réessayer.', 'warning')
        return
    end
    local identifier = GetLicenseIdentifier(src)
    if not identifier or type(data) ~= 'table' then
        CreationError(src, 'Données de création invalides.')
        return
    end
    local activeSession = exports['rp_core']:GetPlayerByIdentifier(identifier)
    if exports['rp_core']:GetPlayerFromId(src) or activeSession then
        CreationError(src, 'Une session est déjà active pour ce compte.')
        return
    end

    local firstname = type(data.firstname) == 'string' and Trim(data.firstname) or ''
    local lastname = type(data.lastname) == 'string' and Trim(data.lastname) or ''
    if #firstname < 2 or #firstname > 32 or #lastname < 2 or #lastname > 32 or
        firstname:find('[%c<>]') or lastname:find('[%c<>]') then
        CreationError(src, 'Prénom ou nom invalide (2 à 32 caractères).')
        return
    end
    if not IsValidDate(data.dateofbirth) then
        CreationError(src, 'Date de naissance invalide.')
        return
    end
    if data.gender ~= 'm' and data.gender ~= 'f' then
        CreationError(src, 'Genre invalide.')
        return
    end

    local height = tonumber(data.height)
    if not height or height % 1 ~= 0 or height < 120 or height > 220 then
        CreationError(src, 'Taille invalide (120 à 220 cm).')
        return
    end

    local userOk, user = SafeDatabaseCall(src, 'character creation account lookup', function()
        return MySQL.single.await('SELECT `group` FROM users WHERE identifier = ?', { identifier })
    end)
    if not userOk then return end
    if not user then
        CreationError(src, 'Compte introuvable. Reconnectez-vous.')
        return
    end

    local countOk, count = SafeDatabaseCall(src, 'character count query', function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE identifier = ?', { identifier })
    end)
    if not countOk then return end
    count = tonumber(count) or 0
    if count >= MAX_CHARACTERS then
        CreationError(src, ('Vous avez atteint la limite de %s personnages.'):format(MAX_CHARACTERS))
        return
    end

    if creationLocks[identifier] then
        CreationError(src, 'Une création est déjà en cours pour ce compte.', 'warning')
        return
    end
    creationLocks[identifier] = true

    local slotOk, slot = SafeDatabaseCall(src, 'character slot query', function()
        return MySQL.scalar.await(
            'SELECT COALESCE(MIN(t.slot), 1) FROM (SELECT 1 AS slot UNION SELECT 2 UNION SELECT 3) t LEFT JOIN characters c ON c.char_id = t.slot AND c.identifier = ? WHERE c.id IS NULL',
            { identifier }
        )
    end)
    if not slotOk then creationLocks[identifier] = nil return end
    slot = tonumber(slot) or 1

    local allowedSpawns = {
        airport = DefaultSpawn,
        train = { x = 432.2, y = -626.8, z = 28.5, heading = 220.0 },
        hospital = { x = 298.5, y = -584.5, z = 43.2, heading = 70.0 },
        jobcenter = { x = -268.3, y = -956.8, z = 31.2, heading = 205.0 }
    }
    local spawnKey = type(data.spawnPoint) == 'string' and data.spawnPoint or 'airport'
    local spawn = allowedSpawns[spawnKey] or DefaultSpawn
    local skin = type(data.skin) == 'table' and data.skin or {}

    local encodeOk, encodedPosition, encodedSkin = pcall(function()
        return json.encode(spawn), json.encode(skin)
    end)
    if not encodeOk or type(encodedPosition) ~= 'string' or type(encodedSkin) ~= 'string'
        or #encodedPosition > 1024 or #encodedSkin > 16384 then
        creationLocks[identifier] = nil
        CreationError(src, 'L\'apparence du personnage contient trop de données. Réduisez les options et réessayez.')
        return
    end

    local insertOk, charId = pcall(MySQL.insert.await,
        'INSERT INTO characters (identifier, char_id, firstname, lastname, dateofbirth, sex, height, cash, bank, job, job_grade, position, skin) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { identifier, slot, firstname, lastname, data.dateofbirth, data.gender, height,
          2500, 10000, 'unemployed', 0, encodedPosition, encodedSkin }
    )
    creationLocks[identifier] = nil
    if not insertOk or not charId then
        if not insertOk then
            print(('[rp_characters] Character insert failed for %s: %s'):format(identifier, tostring(charId)))
        end
        CreationError(src, 'Impossible d\'enregistrer le personnage en base de données.')
        return
    end

    local char = {
        id = charId, char_id = slot, firstname = firstname, lastname = lastname,
        dateofbirth = data.dateofbirth, sex = data.gender, height = height,
        phone_number = nil, is_dead = 0,
        cash = 2500, bank = 10000, job = 'unemployed', job_grade = 0,
        position = spawn, skin = skin
    }
    LoadCharacter(src, identifier, GetEffectiveUserGroup(src, user.group), char)
end

RegisterNetEvent('rp_characters:server:createCharacter', function(data)
    local src = source
    local ok, err = xpcall(CreateCharacter, debug.traceback, src, data)
    if not ok then
        local identifier = GetLicenseIdentifier(src)
        if identifier then creationLocks[identifier] = nil end
        print(('[rp_characters] Character creation pipeline failed for player %s: %s')
            :format(tostring(src), tostring(err)))
        CreationError(src, 'La création du personnage a rencontré une erreur serveur. Consultez la console FXServer.')
    end
end)
