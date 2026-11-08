local function GetPlayerIdentifierByType(source, idType)
    local num = GetNumPlayerIdentifiers(source)
    for i = 0, num - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and string.find(id, idType .. ':') then
            return id
        end
    end
    return GetPlayerIdentifier(source, 0) or ('steam:' .. tostring(source))
end

local InMemoryCharacters = {}

RegisterNetEvent('rp_characters:server:checkPlayer', function()
    local src = source
    local identifier = GetPlayerIdentifierByType(src, 'license')

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
    local identifier = GetPlayerIdentifierByType(src, 'license')
    
    local charRecord = {
        id = 1,
        firstname = data.firstname or 'Citoyen',
        lastname = data.lastname or 'Inconnu',
        dateofbirth = data.dateofbirth or '1995-01-01',
        sex = data.gender or 'm',
        height = tonumber(data.height) or 175,
        cash = 2500,
        bank = 10000,
        job = 'unemployed',
        job_grade = 0,
        group = 'user',
        skin = data.skin or {}
    }

    InMemoryCharacters[identifier] = charRecord

    local rpPlayer = exports['rp_core']:CreateRPPlayer(src, identifier, charRecord)
    exports['rp_core']:GetAllPlayers()[src] = rpPlayer
    rpPlayer.syncClient()

    local spawnCoords = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }
    if data.spawnPoint == 'train' then
        spawnCoords = { x = 432.2, y = -626.8, z = 28.5, heading = 220.0 }
    elseif data.spawnPoint == 'hospital' then
        spawnCoords = { x = 298.5, y = -584.5, z = 43.2, heading = 70.0 }
    elseif data.spawnPoint == 'jobcenter' then
        spawnCoords = { x = -268.3, y = -956.8, z = 31.2, heading = 205.0 }
    end

    TriggerClientEvent('rp_characters:client:spawnPlayer', src, spawnCoords)
    TriggerClientEvent('rp_core:client:notify', src, 'Personnage enregistré avec succès ! Bienvenue à Los Santos.', 'success')
end)
