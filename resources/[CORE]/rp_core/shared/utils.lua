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
