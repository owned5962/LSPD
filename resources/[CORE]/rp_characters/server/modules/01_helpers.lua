local MAX_CHARACTERS = 3
local creationLocks = {}
local DefaultSpawn = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }

local function GetLicenseIdentifier(src)
    local license2
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if type(identifier) == 'string' then
            if identifier:sub(1, 8) == 'license:' then
                return identifier
            end
            if identifier:sub(1, 9) == 'license2:' and not license2 then
                license2 = identifier
            end
        end
    end
    return license2
end

local FOUNDER_FIVEM_IDENTIFIER = 'fivem:12219878'

local function IsFounderAccount(src)
    if IsPlayerAceAllowed(src, 'rp_founder') then return true end
    for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
        if identifier == FOUNDER_FIVEM_IDENTIFIER then return true end
    end
    return false
end

local function GetEffectiveUserGroup(src, databaseGroup)
    if IsFounderAccount(src) then return 'fondateur' end
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

local function CreationError(src, message, kind)
    Notify(src, message, kind)
    TriggerClientEvent('rp_characters:client:creationResult', src, {
        ok = false,
        message = message
    })
end

local function SafeDatabaseCall(src, operation, callback)
    local ok, result = xpcall(callback, debug.traceback)
    if not ok then
        if RPCharacterDiagnostics and RPCharacterDiagnostics.ReportServerError then
            RPCharacterDiagnostics.ReportServerError(operation, result, src)
        else
            print(('[rp_characters] %s failed for player %s: %s'):format(operation, tostring(src), tostring(result)))
        end
        local message = 'La base de données est temporairement indisponible. Vérifiez oxmysql et la console serveur.'
        Notify(src, message, 'error')
        TriggerClientEvent('rp_characters:client:bootError', src, message)
        TriggerClientEvent('rp_characters:client:creationResult', src, { ok = false, message = message })
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
        Notify(src, 'La progression du tutoriel n\'a pas pu être sauvegardée. Il sera proposé à votre prochaine connexion.', 'warning')
        tutorialStarted[src] = nil
        return
    end

    tutorialStarted[src] = nil
    Notify(src, 'Tutoriel terminé ! Bonne aventure à Los Santos.', 'success')
end)

AddEventHandler('playerDropped', function()
    tutorialStarted[source] = nil
    creationLocks[source] = nil
end)
