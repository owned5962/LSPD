local RESOURCE = GetCurrentResourceName()
local PART_COUNT = 28
local parts, lineMap = {}, {}
local nextCombinedLine = 1

local function countSourceLines(source)
    local _, count = source:gsub("\n", "")
    if source == "" then return 0 end
    return count + (source:sub(-1) == "\n" and 0 or 1)
end

local function mapCombinedLine(line)
    local entry = lineMap[tonumber(line)]
    if entry then return entry.file, entry.line end
    return "client/main.lua", tonumber(line) or 0
end

local function mapTraceback(traceback)
    local output = {}
    for sourceLine in tostring(traceback or ""):gmatch("[^\n]+") do
        local combined = sourceLine:match("client/main%.lua:(%d+)")
        if combined then
            local file, line = mapCombinedLine(combined)
            output[#output + 1] = sourceLine .. "  ==>  " .. file .. ":" .. tostring(line)
        else
            output[#output + 1] = sourceLine
        end
    end
    return table.concat(output, "\n")
end

local reportWindow, reportCount = GetGameTimer(), 0
local function reportClientError(context, err)
    local trace = mapTraceback(err)
    local file, line = trace:match("==>  ([^\n]+):(%d+)")
    file, line = file or "client/main.lua", tonumber(line) or 0
    local message = tostring(err):sub(1, 2000)
    print(("^1[rp_characters][CLIENT ERROR] %s:%d | %s | %s^7"):format(file, line, tostring(context), message))
    print("^1" .. trace:sub(1, 6000) .. "^7")

    local now = GetGameTimer()
    if now - reportWindow > 10000 then reportWindow, reportCount = now, 0 end
    if reportCount >= 8 then return end
    reportCount = reportCount + 1
    pcall(TriggerServerEvent, "rp_characters:server:reportClientError", {
        resource = RESOURCE, file = file, line = line,
        context = tostring(context):sub(1, 128),
        message = message, traceback = trace:sub(1, 6000)
    })
end

local function tracebackHandler(err)
    return debug.traceback(tostring(err), 2)
end

local function guarded(context, callback)
    return function(...)
        local args = table.pack(...)
        local result = table.pack(xpcall(function()
            return callback(table.unpack(args, 1, args.n))
        end, tracebackHandler))
        if not result[1] then
            reportClientError(context, result[2])
            return nil
        end
        return table.unpack(result, 2, result.n)
    end
end

-- Protect all client-side asynchronous entry points declared by the 28 source
-- fragments. The combined chunk's line numbers are mapped back to each fragment.
local originalRegisterNetEvent = RegisterNetEvent
local originalAddEventHandler = AddEventHandler
local originalCreateThread = CreateThread
local originalSetTimeout = SetTimeout
local originalRegisterNUICallback = RegisterNUICallback

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
RegisterNUICallback = function(name, callback)
    return originalRegisterNUICallback(name, guarded("nui:" .. tostring(name), callback))
end

for i = 1, PART_COUNT do
    local name = ("client/p%d.lua"):format(i)
    local part = LoadResourceFile(RESOURCE, name)
    if not part or part == "" then
        local message = "Missing or empty source file: " .. name
        print("^1[rp_characters][FATAL] " .. message .. "^7")
        reportClientError("loader", message)
        return
    end
    parts[i] = part
    local count = countSourceLines(part)
    for sourceLine = 1, count do
        lineMap[nextCombinedLine + sourceLine - 1] = { file = name, line = sourceLine }
    end
    nextCombinedLine = nextCombinedLine + count + (part:sub(-1) == "\n" and 1 or 0)
end

local chunk, compileError = load(table.concat(parts, "\n"), "@rp_characters/client/main.lua")
if not chunk then
    local combined = tostring(compileError):match("client/main%.lua:(%d+)")
    local file, line = mapCombinedLine(combined)
    local message = ("Lua compilation error at %s:%d: %s"):format(file, line, tostring(compileError))
    print("^1[rp_characters][COMPILE ERROR] " .. message .. "^7")
    reportClientError("compile", message)
    return
end

local ok, runtimeError = xpcall(chunk, tracebackHandler)
if not ok then reportClientError("top-level", runtimeError) end
