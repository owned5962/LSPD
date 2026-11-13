Utils = {}

local function ToFiniteNumber(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return fallback or 0
    end
    return number
end

function Utils.FormatCurrency(amount)
    local formatted = string.format('%.0f', math.floor(ToFiniteNumber(amount, 0)))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
        if k == 0 then break end
    end
    return formatted .. " $"
end

function Utils.Trim(value)
    if type(value) ~= 'string' then return '' end
    return (value:gsub("^%s*(.-)%s*$", "%1"))
end

local function DumpValue(value, seen, depth)
    if type(value) ~= 'table' then return tostring(value) end
    if seen[value] then return '<cycle>' end
    if depth >= 12 then return '<max-depth>' end

    seen[value] = true
    local parts = { '{ ' }
    for key, item in pairs(value) do
        local renderedKey
        if type(key) == 'number' then
            renderedKey = tostring(key)
        else
            renderedKey = string.format('%q', tostring(key))
        end
        parts[#parts + 1] = '[' .. renderedKey .. '] = ' .. DumpValue(item, seen, depth + 1) .. ','
    end
    parts[#parts + 1] = '} '
    seen[value] = nil
    return table.concat(parts)
end

function Utils.TableDump(value)
    return DumpValue(value, {}, 0)
end

function Utils.NormalizePosition(value, fallback)
    fallback = type(fallback) == 'table' and fallback or { x = 0.0, y = 0.0, z = 0.0, heading = 0.0 }
    local x = type(value) == 'table' and tonumber(value.x) or nil
    local y = type(value) == 'table' and tonumber(value.y) or nil
    local z = type(value) == 'table' and tonumber(value.z) or nil
    local heading = type(value) == 'table' and tonumber(value.heading) or nil

    local function finite(number)
        return number ~= nil and number == number and number ~= math.huge and number ~= -math.huge
    end
    local function defaultPosition()
        return {
            x = tonumber(fallback.x) or 0.0,
            y = tonumber(fallback.y) or 0.0,
            z = tonumber(fallback.z) or 0.0,
            heading = tonumber(fallback.heading) or 0.0
        }
    end

    if not finite(x) or not finite(y) or not finite(z)
        or x < -6000 or x > 6000 or y < -6000 or y > 6000
        or z < -500 or z > 2000 then
        return defaultPosition()
    end

    if not finite(heading) then heading = tonumber(fallback.heading) or 0.0 end
    return { x = x, y = y, z = z, heading = heading % 360 }
end
