local CURRENT_VERSION = '1.3.0'
local PREVIOUS_VERSION = '1.2.0'
local GITHUB_COMMITS_URL = 'https://api.github.com/repos/owned5962/LSPD/commits?per_page=4'
local CACHE_DURATION_MS = 300000
local REQUEST_COOLDOWN_MS = 10000

local cachedUpdates = nil
local lastFetchAt = 0
local lastRequestByPlayer = {}

local function BuildPayload(updates, source)
    return {
        eventName = 'lssUpdates',
        currentVersion = CURRENT_VERSION,
        previousVersion = PREVIOUS_VERSION,
        updates = updates or {},
        source = source or 'unavailable',
        fetchedAt = os.date('%d/%m/%Y %H:%M:%S')
    }
end

local function SendUpdates(playerId, payload)
    if playerId and playerId > 0 then
        TriggerClientEvent('rp_loadscreen:receiveUpdates', playerId, payload)
    end
end

local function FetchLatestUpdates(callback)
    local now = GetGameTimer()
    if cachedUpdates and (now - lastFetchAt) < CACHE_DURATION_MS then
        callback(cachedUpdates)
        return
    end

    PerformHttpRequest(GITHUB_COMMITS_URL, function(statusCode, responseBody)
        local updates = {}
        local source = 'unavailable'

        if statusCode == 200 and type(responseBody) == 'string' then
            local ok, commits = pcall(json.decode, responseBody)
            if ok and type(commits) == 'table' then
                for index = 1, math.min(#commits, 4) do
                    local item = commits[index]
                    local commit = type(item) == 'table' and item.commit or nil
                    local message = type(commit) == 'table' and commit.message or nil
                    local author = type(commit) == 'table' and commit.author or nil
                    local date = type(author) == 'table' and author.date or nil

                    if type(message) == 'string' then
                        updates[#updates + 1] = {
                            title = message:gsub('[\r\n].*', ''):sub(1, 100),
                            date = type(date) == 'string' and date:sub(1, 16):gsub('T', ' ') or 'Date indisponible',
                            sha = type(item.sha) == 'string' and item.sha:sub(1, 7) or ''
                        }
                    end
                end
                source = 'github'
            end
        else
            print(('[rp_loadscreen] GitHub updates unavailable (HTTP %s)'):format(tostring(statusCode)))
        end

        local payload = BuildPayload(updates, source)
        cachedUpdates = payload
        lastFetchAt = GetGameTimer()
        callback(payload)
    end, 'GET', '', {
        ['Accept'] = 'application/vnd.github+json',
        ['User-Agent'] = 'LSPD-FiveM-Loadscreen'
    })
end

RegisterNetEvent('rp_loadscreen:requestUpdates', function()
    local playerId = source
    local now = GetGameTimer()
    local lastRequest = lastRequestByPlayer[playerId]
    if lastRequest and (now - lastRequest) < REQUEST_COOLDOWN_MS then return end
    lastRequestByPlayer[playerId] = now

    FetchLatestUpdates(function(payload)
        SendUpdates(playerId, payload)
    end)
end)

AddEventHandler('playerDropped', function()
    lastRequestByPlayer[source] = nil
end)
