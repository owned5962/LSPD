local CURRENT_VERSION = '1.3.0'
local PREVIOUS_VERSION = '1.2.0'
local UPDATES_URL = 'https://raw.githubusercontent.com/owned5962/LSPD/main/nouveaut%C3%A9s.txt'
local FUTURE_URL = 'https://raw.githubusercontent.com/owned5962/LSPD/main/futur.txt'
local CACHE_DURATION_MS = 300000
local REQUEST_COOLDOWN_MS = 10000

local cachedPayload = nil
local lastFetchAt = 0
local lastRequestByPlayer = {}

local function ParseLines(content, limit)
    local entries = {}
    if type(content) ~= 'string' then return entries end

    for line in content:gmatch('[^\r\n]+') do
        local value = line:gsub('^%s+', ''):gsub('%s+$', '')
        if value ~= '' and value:sub(1, 1) ~= '#' then
            entries[#entries + 1] = value:sub(1, 140)
            if #entries >= limit then break end
        end
    end

    return entries
end

local function SendUpdates(playerId, payload)
    if playerId and playerId > 0 then
        TriggerClientEvent('rp_loadscreen:receiveUpdates', playerId, payload)
    end
end

local function FetchText(url, callback)
    PerformHttpRequest(url, function(statusCode, body)
        if statusCode == 200 and type(body) == 'string' then
            callback(body)
        else
            print(('[rp_loadscreen] Impossible de lire %s (HTTP %s)'):format(url, tostring(statusCode)))
            callback(nil)
        end
    end, 'GET', '', {
        ['Accept'] = 'text/plain',
        ['User-Agent'] = 'LSPD-FiveM-Loadscreen'
    })
end

local function FetchLoadscreenData(callback)
    local now = GetGameTimer()
    if cachedPayload and (now - lastFetchAt) < CACHE_DURATION_MS then
        callback(cachedPayload)
        return
    end

    local pending = 2
    local updatesText, futureText

    local function finishOne()
        pending = pending - 1
        if pending > 0 then return end

        local payload = {
            eventName = 'lssUpdates',
            currentVersion = CURRENT_VERSION,
            previousVersion = PREVIOUS_VERSION,
            updates = ParseLines(updatesText, 6),
            future = ParseLines(futureText, 10),
            source = updatesText and futureText and 'files' or 'unavailable',
            fetchedAt = os.date('%d/%m/%Y %H:%M:%S')
        }

        cachedPayload = payload
        lastFetchAt = GetGameTimer()
        callback(payload)
    end

    FetchText(UPDATES_URL, function(body)
        updatesText = body
        finishOne()
    end)

    FetchText(FUTURE_URL, function(body)
        futureText = body
        finishOne()
    end)
end

RegisterNetEvent('rp_loadscreen:requestUpdates', function()
    local playerId = source
    local now = GetGameTimer()
    local lastRequest = lastRequestByPlayer[playerId]
    if lastRequest and (now - lastRequest) < REQUEST_COOLDOWN_MS then return end
    lastRequestByPlayer[playerId] = now

    FetchLoadscreenData(function(payload)
        SendUpdates(playerId, payload)
    end)
end)

AddEventHandler('playerDropped', function()
    lastRequestByPlayer[source] = nil
end)
