-- rp_characters server diagnostics. Must load before server/main.lua.
local RESOURCE = GetCurrentResourceName()
local reportWindows = {}

local function clean(value, limit)
    if type(value) ~= "string" then return "" end
    return value:gsub("[%c]", " "):sub(1, limit)
end

local function locate(trace)
    local file, line = tostring(trace or ""):match("@([^\n]-%.lua):(%d+)")
    if not file then file, line = tostring(trace or ""):match("([^\n]-%.lua):(%d+)") end
    return file or "server/unknown.lua", tonumber(line) or 0
end

local function report(context, err, player)
    local trace = tostring(err)
    local file, line = locate(trace)
    print(("^1[rp_characters][SERVER ERROR] %s:%d | context=%s | player=%s | %s^7")
        :format(file, line, clean(tostring(context), 128), tostring(player or "server"), clean(trace, 2000)))
    print("^1" .. trace:sub(1, 6000) .. "^7")
end

RPCharacterDiagnostics = RPCharacterDiagnostics or {}
RPCharacterDiagnostics.ReportServerError = report

local function guarded(context, callback)
    return function(...)
        local args = table.pack(...)
        local player = source
        local result = table.pack(xpcall(function()
            return callback(table.unpack(args, 1, args.n))
        end, function(err) return debug.traceback(tostring(err), 2) end))
        if not result[1] then
            report(context, result[2], player)
            return nil
        end
        return table.unpack(result, 2, result.n)
    end
end

local originalRegisterNetEvent = RegisterNetEvent
local originalAddEventHandler = AddEventHandler
local originalCreateThread = CreateThread
local originalSetTimeout = SetTimeout

RegisterNetEvent = function(name, callback)
    if type(callback) == "function" then
        return originalRegisterNetEvent(name, guarded("net-event:" .. tostring(name), callback))
    end
    return originalRegisterNetEvent(name)
end
AddEventHandler = function(name, callback)
    return originalAddEventHandler(name, guarded("event:" .. tostring(name), callback))
end
CreateThread = function(callback)
    return originalCreateThread(guarded("thread", callback))
end
if type(originalSetTimeout) == "function" then
    SetTimeout = function(delay, callback)
        return originalSetTimeout(delay, guarded("timeout:" .. tostring(delay), callback))
    end
end

RegisterNetEvent("rp_characters:server:reportClientError", function(payload)
    local src = source
    if type(payload) ~= "table" or payload.resource ~= RESOURCE then return end
    local file = clean(payload.file, 160)
    if not file:match("^client/[%w_/%-]+%.lua$") then return end
    local line = tonumber(payload.line)
    if not line or line < 0 or line > 1000000 or line % 1 ~= 0 then return end

    local now = GetGameTimer()
    local window = reportWindows[src]
    if not window or now - window.started > 60000 then
        window = { started = now, count = 0 }
        reportWindows[src] = window
    end
    if window.count >= 10 then return end
    window.count = window.count + 1

    print(("^3[rp_characters][CLIENT-REPORTED ERROR] player=%s %s:%d | %s | %s^7")
        :format(tostring(src), file, line, clean(payload.context, 128), clean(payload.message, 2000)))
    local trace = clean(payload.traceback, 6000)
    if trace ~= "" then print("^3" .. trace .. "^7") end
end)

AddEventHandler("playerDropped", function()
    reportWindows[source] = nil
end)

print(("[rp_characters] Server diagnostics active (%s)."):format(RESOURCE))
