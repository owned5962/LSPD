local RESOURCE = GetCurrentResourceName()
local CLIENT_PARTS = { 2, 25, 26, 27, 28 }
local PART_COUNT = #CLIENT_PARTS
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

local originalRegisterNetEvent = RegisterNetEvent
local originalAddEventHandler = AddEventHandler
local originalCreateThread = CreateThread
local originalSetTimeout = SetTimeout
local originalRegisterNUICallback = RegisterNUICallback

RegisterNetEvent = function(name, callback)
    if type(callback) == "function" then
        return originalRegisterNetEvent(name, guarded("net-event:" .. tostring(name), callback))
    end
    return originalRegisterNetEvent(name, callback)
end

AddEventHandler = function(name, callback)
    if type(callback) == "function" then
        return originalAddEventHandler(name, guarded("event:" .. tostring(name), callback))
    end
    return originalAddEventHandler(name, callback)
end

CreateThread = function(callback)
    if type(callback) == "function" then
        return originalCreateThread(guarded("thread", callback))
    end
    return originalCreateThread(callback)
end

SetTimeout = function(msec, callback)
    if type(callback) == "function" then
        return originalSetTimeout(msec, guarded("timeout", callback))
    end
    return originalSetTimeout(msec, callback)
end

RegisterNUICallback = function(name, callback)
    if type(callback) == "function" then
        return originalRegisterNUICallback(name, guarded("nui:" .. tostring(name), callback))
    end
    return originalRegisterNUICallback(name, callback)
end

local missing = {}
for _, i in ipairs(CLIENT_PARTS) do
    local rel = ("client/p%d.lua"):format(i)
    local src = LoadResourceFile(RESOURCE, rel)
    if not src or src == "" or #src < 32 or src:match("^%s*%-%-%s*truncated") then
        missing[#missing + 1] = rel
    else
        local lineCount = countSourceLines(src)
        for line = 1, lineCount do
            lineMap[nextCombinedLine] = { file = rel, line = line }
            nextCombinedLine = nextCombinedLine + 1
        end
        parts[#parts + 1] = src
        if src:sub(-1) ~= "\n" then parts[#parts + 1] = "\n" end
    end
end

if #missing > 0 then
    print("[rp_characters] FATAL missing client parts: " .. table.concat(missing, ", "))
    return
end

local combined = table.concat(parts)
local chunk, err = load(combined, ("@@%s/client/main.lua"):format(RESOURCE))
if not chunk then
    print(("[rp_characters] FATAL client compile: %s"):format(tostring(err)))
    return
end

local ok, runtimeErr = xpcall(chunk, tracebackHandler)
if not ok then
    reportClientError("client-boot", runtimeErr)
    print(("[rp_characters] FATAL client runtime: %s"):format(tostring(runtimeErr)))
    return
end
