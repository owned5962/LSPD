local transferLocks = {}
local saveLocks = {}

local function AcquireCharacterLock(characterIds)
    if type(characterIds) ~= 'table' or #characterIds < 1 then return false end
    local ids, seen = {}, {}
    for _, rawId in ipairs(characterIds) do
        local id = tonumber(rawId)
        if not id or id < 1 or id % 1 ~= 0 or seen[id]
            or transferLocks[id] or saveLocks[id] then return false end
        ids[#ids + 1], seen[id] = id, true
    end
    for _, id in ipairs(ids) do transferLocks[id] = true end
    return true
end

local function ReleaseCharacterLock(characterIds)
    if type(characterIds) ~= 'table' then return false end
    for _, rawId in ipairs(characterIds) do
        local id = tonumber(rawId)
        if id and id > 0 then transferLocks[id] = nil end
    end
    return true
end

exports('AcquireCharacterLock', AcquireCharacterLock)
exports('ReleaseCharacterLock', ReleaseCharacterLock)

local function RequirePositiveInteger(value, fieldName)
    local number = tonumber(value)
    if not number or number < 1 or number % 1 ~= 0 then
        error(('Invalid character field %s: expected a positive integer'):format(fieldName))
    end
    return number
end

local function ReadNonNegativeInteger(value, fallback, fieldName)
    if value == nil then return fallback end
    -- MySQL/oxmysql may return DECIMAL/DOUBLE as 2500.0 or "2500.00".
    -- Coerce near-integers instead of aborting the entire character load.
    local number = tonumber(value)
    if not number or number < 0 then
        error(('Invalid character field %s: expected a non-negative number (got %s)')
            :format(fieldName, tostring(value)))
    end
    number = math.floor(number + 0.0000001)
    if number < 0 then
        error(('Invalid character field %s: expected a non-negative integer'):format(fieldName))
    end
    return number
end
