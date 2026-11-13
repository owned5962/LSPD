local GangCache = {}
local GangReady = false

local function normalizeGang(data)
    if type(data) ~= 'table' then return nil, 'Données de gang invalides.' end
    local name = type(data.name) == 'string' and data.name:lower() or ''
    local label = type(data.label) == 'string' and data.label:gsub('[%c<>]', ' '):sub(1, 64) or ''
    local description = type(data.description) == 'string' and data.description:gsub('[%c<>]', ' '):sub(1, 255) or ''
    local color = type(data.color) == 'string' and data.color:lower() or ''
    if #name < 3 or #name > 40 or not name:match('^[a-z][a-z0-9_]+$') then
        return nil, 'Identifiant invalide (3 à 40 caractères).'
    end
    if #label < 2 or #description < 3 then return nil, 'Nom ou description invalide.' end
    if not color:match('^#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$') then
        return nil, 'Couleur hexadécimale invalide.'
    end
    return { name=name, label=label, description=description, color=color }
end

local function loadGangs()
    local rows = MySQL.query.await('SELECT name, label, description, color FROM rp_gangs ORDER BY label ASC') or {}
    GangCache = {}
    for _, row in ipairs(rows) do GangCache[row.name] = row end
    GangReady = true
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS rp_gangs (
            name VARCHAR(40) NOT NULL PRIMARY KEY,
            label VARCHAR(64) NOT NULL,
            description VARCHAR(255) NOT NULL,
            color CHAR(7) NOT NULL DEFAULT '#64748b',
            created_by VARCHAR(80) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        loadGangs()
    end)
    if not ok then
        GangReady = false
        print(('[rp_gangs] Database initialization failed: %s'):format(tostring(err)))
    else
        local count = 0
        for _ in pairs(GangCache) do count = count + 1 end
        print(('[rp_gangs] %d gangs loaded.'):format(count))
    end
end)

local function CreateGang(rawData, createdBy)
    if not GangReady then return false, 'Le registre des gangs est indisponible.' end
    local gang, validationError = normalizeGang(rawData)
    if not gang then return false, validationError end
    if GangCache[gang.name] then return false, 'Cet identifiant de gang existe déjà.' end
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO rp_gangs (name, label, description, color, created_by) VALUES (?, ?, ?, ?, ?)',
        { gang.name, gang.label, gang.description, gang.color, tostring(createdBy or 'Creator'):sub(1, 80) })
    if not ok or not id then
        print(('[rp_gangs] Gang insert failed: %s'):format(tostring(id)))
        return false, 'Erreur SQL : le gang n’a pas été enregistré.'
    end
    GangCache[gang.name] = gang
    return true, gang
end

local function UpdateGang(rawData)
    if not GangReady then return false, 'Le registre des gangs est indisponible.' end
    if type(rawData) ~= 'table' or type(rawData.name) ~= 'string' then return false, 'Gang invalide.' end
    local existingName = rawData.name:lower()
    if not GangCache[existingName] then return false, 'Gang introuvable.' end
    local gang, validationError = normalizeGang(rawData)
    if not gang then return false, validationError end
    local ok, affected = pcall(MySQL.update.await,
        'UPDATE rp_gangs SET label = ?, description = ?, color = ? WHERE name = ?',
        { gang.label, gang.description, gang.color, existingName })
    if not ok or type(affected) ~= 'number' then
        print(('[rp_gangs] Gang update failed: %s'):format(tostring(affected)))
        return false, 'Erreur SQL : modification non enregistrée.'
    end
    GangCache[existingName] = gang
    return true, gang
end

local function DeleteGang(rawName)
    if not GangReady then return false, 'Le registre des gangs est indisponible.' end
    if type(rawName) ~= 'string' or not GangCache[rawName] then return false, 'Gang introuvable.' end
    local ok, affected = pcall(MySQL.update.await, 'DELETE FROM rp_gangs WHERE name = ?', { rawName })
    if not ok or type(affected) ~= 'number' or affected < 1 then
        print(('[rp_gangs] Gang deletion failed: %s'):format(tostring(affected)))
        return false, 'Erreur SQL : suppression impossible.'
    end
    GangCache[rawName] = nil
    return true
end

local function GetAllGangs()
    local list = {}
    for _, gang in pairs(GangCache) do list[#list + 1] = gang end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

exports('CreateGang', CreateGang)
exports('UpdateGang', UpdateGang)
exports('DeleteGang', DeleteGang)
exports('GetGang', function(name) return GangCache[tostring(name or '')] end)
exports('GetAllGangs', GetAllGangs)
exports('IsValidGang', function(name) return GangCache[tostring(name or '')] ~= nil end)
