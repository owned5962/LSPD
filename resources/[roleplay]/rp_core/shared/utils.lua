Utils = {}

function Utils.FormatCurrency(amount)
    local formatted = tostring(math.floor(amount or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
        if k == 0 then break end
    end
    return formatted .. " $"
end

function Utils.Trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function Utils.TableDump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. Utils.TableDump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end
