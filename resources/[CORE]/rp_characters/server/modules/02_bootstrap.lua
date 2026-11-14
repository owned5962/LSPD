local function ResumeRegisteredCharacter(src)
    local snapshot = exports['rp_core']:GetPlayerSnapshot(src)
    if type(snapshot) ~= 'table' or tonumber(snapshot.charId) == nil then
        return false, 'Session active détectée mais instantané du personnage indisponible.'
    end

    local position = DecodeJson(snapshot.position, DefaultSpawn)
    local skin = DecodeJson(snapshot.skin, {})
    TriggerClientEvent('rp_characters:client:closeMenu', src)
    TriggerClientEvent('rp_characters:client:spawnPlayer', src, position, snapshot.sex, skin)
    print(('[rp_characters] Existing character session resumed through spawn pipeline for player %s (character %s).')
        :format(tostring(src), tostring(snapshot.charId)))
    return true
end

local function LoadCharacterUnsafe(src, identifier, userGroup, char)
    if exports['rp_core']:IsCharacterSavePending(char.id) then
        local message = 'Votre dernière sauvegarde est encore en cours. Réessayez dans quelques secondes.'
        Notify(src, message, 'warning')
        return false, message
    end

    local currentSession = exports['rp_core']:GetPlayerByIdentifier(identifier)
    if currentSession then
        if tonumber(currentSession.source) ~= tonumber(src) then
            DropPlayer(src, 'Une session est déjà active avec ce compte.')
            return false, 'Une session est déjà active avec ce compte.'
        end
        return ResumeRegisteredCharacter(src)
    end
    if exports['rp_core']:GetPlayerFromId(src) then
        return ResumeRegisteredCharacter(src)
    end

    char.position = DecodeJson(char.position, DefaultSpawn)
    char.skin = DecodeJson(char.skin, {})
    char.group = GetEffectiveUserGroup(src, userGroup)

    local loadOk, player = xpcall(function()
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
    end, debug.traceback)
    if not loadOk or not player then
        pcall(function()
            exports['rp_core']:UnregisterPlayer(src, identifier)
        end)
        print(('[rp_characters] Failed to initialize character for player %s: %s')
            :format(tostring(src), tostring(player)))
        local message = 'Impossible de finaliser le chargement du personnage. Consultez la console serveur.'
        return false, message
    end

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
    TriggerClientEvent('rp_characters:client:closeMenu', src)
    TriggerClientEvent('rp_characters:client:spawnPlayer', src, player.position, char.sex, char.skin)
    Notify(src, ('Bienvenue %s %s !'):format(char.firstname, char.lastname), 'success')
end

local function LoadCharacter(src, identifier, userGroup, char)
    local ok, result, detail = xpcall(LoadCharacterUnsafe, debug.traceback, src, identifier, userGroup, char)
    if ok and result ~= false then return true end

    local reason = ok and detail or result
    print(('[rp_characters] Character load pipeline failed for player %s: %s')
        :format(tostring(src), tostring(reason)))
    pcall(function() exports['rp_core']:UnregisterPlayer(src, identifier) end)
    local message = ok and (detail or 'Le chargement du personnage a été interrompu.')
        or 'Le personnage a été enregistré, mais son chargement a échoué. Consultez la console serveur.'
    Notify(src, message, 'error')
    TriggerClientEvent('rp_characters:client:bootError', src, message)
    TriggerClientEvent('rp_characters:client:creationResult', src, { ok = false, message = message })
    return false
end

function CheckPlayerBootstrap(src)
    local actionOk, allowed = pcall(function()
        return exports['rp_core']:CanPerformAction(src, 'character:check_player', 5000)
    end)
    if not actionOk then
        error('rp_core CanPerformAction export failed: ' .. tostring(allowed))
    end
    if not allowed then
        print(('[rp_characters] Duplicate bootstrap ignored for player %s'):format(tostring(src)))
        return
    end
    print(('[rp_characters] Bootstrap started for player %s'):format(tostring(src)))

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
        local resumed, reason = ResumeRegisteredCharacter(src)
        if not resumed then
            print(('[rp_characters] Existing session resume failed for player %s: %s')
                :format(tostring(src), tostring(reason)))
            local message = 'Votre personnage est chargé côté serveur, mais son apparition a échoué. Reconnectez-vous ou contactez un administrateur.'
            Notify(src, message, 'error')
            TriggerClientEvent('rp_characters:client:bootError', src, message)
        end
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
        local insertOk, insertResult = xpcall(MySQL.insert.await, debug.traceback,
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

    print(('[rp_characters] Account loaded for player %s; querying characters.'):format(tostring(src)))
    local charactersOk, characters = SafeDatabaseCall(src, 'character list query', function()
        return MySQL.query.await(
            'SELECT char_id, firstname, lastname, job FROM characters WHERE identifier = ? ORDER BY char_id ASC',
            { identifier }
        )
    end)
    if not charactersOk then return end
    characters = characters or {}

    if #characters == 0 then
        print(('[rp_characters] No character found for player %s; opening creator.'):format(tostring(src)))
        TriggerClientEvent('rp_characters:client:openMenu', src, MAX_CHARACTERS)
    else
        print(('[rp_characters] %d character(s) found for player %s; opening selector.')
            :format(#characters, tostring(src)))
        TriggerClientEvent('rp_characters:client:openCharacterSelection', src, characters, MAX_CHARACTERS)
    end
end

RegisterNetEvent('rp_characters:server:checkPlayer', function()
    local src = source
    local ok, err = xpcall(CheckPlayerBootstrap, debug.traceback, src)
    if not ok then
        print(('[rp_characters] Bootstrap pipeline crashed for player %s: %s')
            :format(tostring(src), tostring(err)))
        local message = 'Le chargement du compte a rencontré une erreur serveur. Consultez la console FXServer.'
        Notify(src, message, 'error')
        TriggerClientEvent('rp_characters:client:bootError', src, message)
    end
end)

AddEventHandler('rp_characters:server:forceBootstrap', function(src)
    src = tonumber(src)
    if not src or src < 1 or not GetPlayerName(src) then return end
    local ok, err = xpcall(CheckPlayerBootstrap, debug.traceback, src)
    if not ok then
        print(('[rp_characters] forceBootstrap crashed for player %s: %s'):format(tostring(src), tostring(err)))
    end
end)
