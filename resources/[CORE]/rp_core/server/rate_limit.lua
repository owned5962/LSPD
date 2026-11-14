-- Server-side rate limiting for net events and sensitive actions.
-- Provides:
--   1) minimum interval between two identical actions (cooldownMs)
--   2) burst window (max N identical actions per window)
--   3) global per-player action budget across all keys
--
-- Usage from any resource:
--   if not exports['rp_core']:CanPerformAction(src, 'inventory:use_item', 1000) then return end
--   if not exports['rp_core']:CanPerformAction(src, 'character:select', 3000, { maxPerWindow = 3, windowMs = 15000 }) then return end

local TIMER_MODULUS = 4294967296

-- [src] = { [action] = lastTimestamp }
local lastActionAt = {}
-- [src] = { [action] = { count = n, startedAt = t } }
local actionWindows = {}
-- [src] = { count = n, startedAt = t }
local globalWindows = {}
-- Rate-limit the rate-limit logs themselves
local lastDenyLogAt = {}

local DEFAULT_MIN_INTERVAL = 1000
local DEFAULT_MAX_PER_WINDOW = 12
local DEFAULT_WINDOW_MS = 10000
local DEFAULT_GLOBAL_MAX = 48
local DEFAULT_GLOBAL_WINDOW_MS = 10000
local DENY_LOG_COOLDOWN_MS = 15000

local function Now()
    return GetGameTimer() % TIMER_MODULUS
end

local function Elapsed(now, thenTs)
    return (now - thenTs) % TIMER_MODULUS
end

local function ClampInt(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    return math.floor(math.max(minValue, math.min(maxValue, value)))
end

local function ValidSource(src)
    src = tonumber(src)
    if not src or src < 1 or src % 1 ~= 0 then return nil end
    return src
end

local function ValidAction(action)
    if type(action) ~= 'string' or action == '' or #action > 96 then return nil end
    return action
end

local function ReadOpts(opts)
    opts = type(opts) == 'table' and opts or {}
    return {
        maxPerWindow = ClampInt(opts.maxPerWindow, 1, 200, DEFAULT_MAX_PER_WINDOW),
        windowMs = ClampInt(opts.windowMs, 250, 120000, DEFAULT_WINDOW_MS),
        globalMax = ClampInt(opts.globalMax, 1, 500, DEFAULT_GLOBAL_MAX),
        globalWindowMs = ClampInt(opts.globalWindowMs, 250, 120000, DEFAULT_GLOBAL_WINDOW_MS),
        silent = opts.silent == true,
    }
end

local function LogDeny(src, action, reason)
    local key = tostring(src) .. ':' .. tostring(action) .. ':' .. tostring(reason)
    local now = Now()
    local last = lastDenyLogAt[key]
    if last and Elapsed(now, last) < DENY_LOG_COOLDOWN_MS then return end
    lastDenyLogAt[key] = now
    print(('[rp_core][rate_limit] denied src=%s action=%s reason=%s')
        :format(tostring(src), tostring(action), tostring(reason)))
end

--- Check and consume rate-limit budget.
--- @param src number player source
--- @param action string action key (e.g. 'inventory:use_item')
--- @param cooldownMs number|nil min interval between two identical actions (default 1000)
--- @param opts table|nil { maxPerWindow, windowMs, globalMax, globalWindowMs, silent }
--- @return boolean allowed
local function CanPerformAction(src, action, cooldownMs, opts)
    src = ValidSource(src)
    action = ValidAction(action)
    if not src or not action then return false end

    local minInterval = ClampInt(cooldownMs, 0, 120000, DEFAULT_MIN_INTERVAL)
    local conf = ReadOpts(opts)
    local now = Now()

    -- 1) Minimum interval for this action
    lastActionAt[src] = lastActionAt[src] or {}
    local last = lastActionAt[src][action]
    if last ~= nil and Elapsed(now, last) < minInterval then
        if not conf.silent then LogDeny(src, action, 'min_interval') end
        return false
    end

    -- 2) Burst window for this action
    actionWindows[src] = actionWindows[src] or {}
    local win = actionWindows[src][action]
    if not win or Elapsed(now, win.startedAt) >= conf.windowMs then
        win = { count = 0, startedAt = now }
        actionWindows[src][action] = win
    end
    if win.count >= conf.maxPerWindow then
        if not conf.silent then LogDeny(src, action, 'action_window') end
        return false
    end

    -- 3) Global per-player budget
    local gwin = globalWindows[src]
    if not gwin or Elapsed(now, gwin.startedAt) >= conf.globalWindowMs then
        gwin = { count = 0, startedAt = now }
        globalWindows[src] = gwin
    end
    if gwin.count >= conf.globalMax then
        if not conf.silent then LogDeny(src, action, 'global_window') end
        return false
    end

    -- Consume budget only when allowed
    lastActionAt[src][action] = now
    win.count = win.count + 1
    gwin.count = gwin.count + 1
    return true
end

--- Remaining ms before the same action is allowed again (interval only).
local function GetActionCooldownRemaining(src, action, cooldownMs)
    src = ValidSource(src)
    action = ValidAction(action)
    if not src or not action then return 0 end
    local minInterval = ClampInt(cooldownMs, 0, 120000, DEFAULT_MIN_INTERVAL)
    local bucket = lastActionAt[src]
    if not bucket or bucket[action] == nil then return 0 end
    local remaining = minInterval - Elapsed(Now(), bucket[action])
    if remaining < 0 then return 0 end
    return remaining
end

--- Clear all rate-limit state for a player (disconnect / admin).
local function ClearPlayerRateLimits(src)
    src = ValidSource(src)
    if not src then return false end
    lastActionAt[src] = nil
    actionWindows[src] = nil
    globalWindows[src] = nil
    return true
end

--- Peek whether an action would be allowed without consuming budget.
local function PeekCanPerformAction(src, action, cooldownMs, opts)
    src = ValidSource(src)
    action = ValidAction(action)
    if not src or not action then return false end

    local minInterval = ClampInt(cooldownMs, 0, 120000, DEFAULT_MIN_INTERVAL)
    local conf = ReadOpts(opts)
    local now = Now()

    local bucket = lastActionAt[src]
    if bucket and bucket[action] ~= nil and Elapsed(now, bucket[action]) < minInterval then
        return false
    end

    local srcWindows = actionWindows[src]
    local win = srcWindows and srcWindows[action] or nil
    if win and Elapsed(now, win.startedAt) < conf.windowMs and win.count >= conf.maxPerWindow then
        return false
    end

    local gwin = globalWindows[src]
    if gwin and Elapsed(now, gwin.startedAt) < conf.globalWindowMs and gwin.count >= conf.globalMax then
        return false
    end

    return true
end

exports('CanPerformAction', CanPerformAction)
exports('GetActionCooldownRemaining', GetActionCooldownRemaining)
exports('ClearPlayerRateLimits', ClearPlayerRateLimits)
exports('PeekCanPerformAction', PeekCanPerformAction)

-- Periodic cleanup of disconnected sources (safety net; playerDropped also clears).
CreateThread(function()
    while true do
        Wait(120000)
        for src in pairs(lastActionAt) do
            if not GetPlayerName(src) then
                lastActionAt[src] = nil
                actionWindows[src] = nil
                globalWindows[src] = nil
            end
        end
        for src in pairs(actionWindows) do
            if not GetPlayerName(src) then
                actionWindows[src] = nil
            end
        end
        for src in pairs(globalWindows) do
            if not GetPlayerName(src) then
                globalWindows[src] = nil
            end
        end
    end
end)

print('[rp_core] [OK] Server rate-limit module loaded')
