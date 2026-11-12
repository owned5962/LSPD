local CURRENT_VERSION = '1.3.0'
local PREVIOUS_VERSION = '1.2.0'
local REQUEST_COOLDOWN_MS = 10000

local cachedPayload = nil
local lastRequestByPlayer = {}

local function BuildLoadscreenPayload()
    local updates = type(LoadscreenUpdates) == 'table' and LoadscreenUpdates or {}
    local recent = type(updates.recent) == 'table' and updates.recent or {}
    local future = type(updates.future) == 'table' and updates.future or {}

    local payload = {
        eventName = 'lssUpdates',
        currentVersion = CURRENT_VERSION,
        previousVersion = PREVIOUS_VERSION,
        updates = {},
        future = {},
        source = 'config',
        fetchedAt = os.date('%d/%m/%Y %H:%M:%S')
    }

    for index = 1, math.min(#recent, 10) do
        local entry = recent[index]
        if type(entry) == 'table' and type(entry.title) == 'string' then
            payload.updates[#payload.updates + 1] = {
                title = entry.title:sub(1, 100),
                date = type(entry.date) == 'string' and entry.date:sub(1, 40) or 'Nouveauté récente'
            }
        elseif type(entry) == 'string' then
            payload.updates[#payload.updates + 1] = entry:sub(1, 100)
        end
    end

    for index = 1, math.min(#future, 10) do
        if type(future[index]) == 'string' then
            payload.future[#payload.future + 1] = future[index]:sub(1, 140)
        end
    end

    return payload
end

local function SendUpdates(playerId)
    if not playerId or playerId < 1 or not GetPlayerName(playerId) then return end
    if not cachedPayload then cachedPayload = BuildLoadscreenPayload() end
    TriggerClientEvent('rp_loadscreen:receiveUpdates', playerId, cachedPayload)
end

RegisterNetEvent('rp_loadscreen:requestUpdates', function()
    local playerId = source
    local now = GetGameTimer()
    local lastRequest = lastRequestByPlayer[playerId]
    if lastRequest and (now - lastRequest) < REQUEST_COOLDOWN_MS then return end
    lastRequestByPlayer[playerId] = now
    SendUpdates(playerId)
end)

AddEventHandler('playerDropped', function()
    lastRequestByPlayer[source] = nil
end)
