-- Distributed server-side rate limiting for FiveM resources.
--
-- "Distributed" here means limits are shared across:
--   - player source sessions (reconnect / source reuse)
--   - stable license identifiers
--   - action categories (economy, inventory, characters, admin, ...)
--   - a global per-identity budget
--
-- Algorithm mix:
--   1) min interval per action key
--   2) fixed window counters per action key
--   3) token buckets per category and per identity (smooth burst control)
--
-- API (backward compatible):
--   exports['rp_core']:CanPerformAction(src, 'inventory:use_item', 1000)
--   exports['rp_core']:CanPerformAction(src, 'character:select', 3000, {
--       maxPerWindow = 3, windowMs = 15000, category = 'characters', cost = 1
--   })

local TIMER_MODULUS = 4294967296

-- Identity-scoped stores (survive source id changes while the player is online).
-- key = license:xxx or src:N fallback
local lastActionAt = {}      -- [identity][action] = ts
local actionWindows = {}     -- [identity][action] = { count, startedAt }
local categoryBuckets = {}   -- [identity][category] = { tokens, updatedAt }
local identityBuckets = {}   -- [identity] = { tokens, updatedAt }
local srcToIdentity = {}     -- [src] = identity
local lastDenyLogAt = {}

local DEFAULT_MIN_INTERVAL = 1000
local DEFAULT_MAX_PER_WINDOW = 12
local DEFAULT_WINDOW_MS = 10000
local DEFAULT_CATEGORY_RATE = 8          -- tokens regenerated per second
local DEFAULT_CATEGORY_BURST = 16        -- bucket capacity
local DEFAULT_IDENTITY_RATE = 20
local DEFAULT_IDENTITY_BURST = 60
local DENY_LOG_COOLDOWN_MS = 15000

-- Category presets (override rate/burst). Unknown categories use defaults.
local CATEGORY_PRESETS = {
    characters = { rate = 2, burst = 4 },
    economy    = { rate = 3, burst = 8 },
    inventory  = { rate = 6, burst = 14 },
    vehicles   = { rate = 3, burst = 8 },
    admin      = { rate = 4, burst = 12 },
    ui         = { rate = 8, burst = 20 },
    core       = { rate = 5, burst = 12 },
    default    = { rate = DEFAULT_CATEGORY_RATE, burst = DEFAULT_CATEGORY_BURST },
}

local function Now()
    return GetGameTimer() % TIMER_MODULUS
end

local function Elapsed(now, thenTs)
    return (now - thenTs) % TIMER_MODULUS
end

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function ClampInt(value, minValue, maxValue, fallback)
    return math.floor(ClampNumber(value, minValue, maxValue, fallback))
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

local function InferCategory(action)
    local prefix = action:match('^([%w]+):')
    if not prefix then return 'default' end
    prefix = prefix:lower()
    if prefix == 'character' or prefix == 'characters' then return 'characters' end
    if prefix == 'inventory' or prefix == 'item' then return 'inventory' end
    if prefix == 'bank' or prefix == 'money' or prefix == 'economy' or prefix == 'jobbank' then return 'economy' end
    if prefix == 'garage' or prefix == 'vehicle' or prefix == 'fuel' then return 'vehicles' end
    if prefix == 'admin' or prefix == 'staff' or prefix == 'anticheat' then return 'admin' end
    if prefix == 'ui' or prefix == 'tablet' then return 'ui' end
    if prefix == 'core' or prefix == 'player' then return 'core' end
    return prefix
end

local function ResolveLicense(src)
    if GetNumPlayerIdentifiers then
        local count = GetNumPlayerIdentifiers(src)
        for i = 0, (count or 0) - 1 do
            local identifier = GetPlayerIdentifier(src, i)
            if type(identifier) == 'string' and identifier:sub(1, 8) == 'license:' then
                return identifier
            end
        end
    end
    return nil
end

local function ResolveIdentity(src)
    src = ValidSource(src)
    if not src then return nil end
    local cached = srcToIdentity[src]
    if cached then return cached end
    local license = ResolveLicense(src)
    local identity = license or ('src:' .. tostring(src))
    srcToIdentity[src] = identity
    return identity
end

local function RefillBucket(bucket, rate, burst, now)
    if not bucket then
        return { tokens = burst, updatedAt = now }
    end
    local elapsedMs = Elapsed(now, bucket.updatedAt)
    if elapsedMs <= 0 then return bucket end
    local refill = (elapsedMs / 1000.0) * rate
    bucket.tokens = math.min(burst, (bucket.tokens or 0) + refill)
    bucket.updatedAt = now
    return bucket
end

local function TryConsumeBucket(store, key, rate, burst, cost, now)
    local bucket = RefillBucket(store[key], rate, burst, now)
    store[key] = bucket
    if (bucket.tokens or 0) < cost then
        return false, bucket
    end
    bucket.tokens = bucket.tokens - cost
    bucket.updatedAt = now
    return true, bucket
end

local function ReadOpts(action, opts)
    opts = type(opts) == 'table' and opts or {}
    local category = opts.category
    if type(category) ~= 'string' or category == '' then
        category = InferCategory(action)
    end
    category = category:lower()
    local preset = CATEGORY_PRESETS[category] or CATEGORY_PRESETS.default
    return {
        maxPerWindow = ClampInt(opts.maxPerWindow, 1, 200, DEFAULT_MAX_PER_WINDOW),
        windowMs = ClampInt(opts.windowMs, 250, 120000, DEFAULT_WINDOW_MS),
        category = category,
        categoryRate = ClampNumber(opts.categoryRate, 0.1, 100, preset.rate),
        categoryBurst = ClampNumber(opts.categoryBurst, 1, 500, preset.burst),
        identityRate = ClampNumber(opts.identityRate, 0.1, 200, DEFAULT_IDENTITY_RATE),
        identityBurst = ClampNumber(opts.identityBurst, 1, 1000, DEFAULT_IDENTITY_BURST),
        cost = ClampNumber(opts.cost, 0.1, 50, 1),
        silent = opts.silent == true,
    }
end

local function LogDeny(identity, action, reason)
    local key = tostring(identity) .. ':' .. tostring(action) .. ':' .. tostring(reason)
    local now = Now()
    local last = lastDenyLogAt[key]
    if last and Elapsed(now, last) < DENY_LOG_COOLDOWN_MS then return end
    lastDenyLogAt[key] = now
    print(('[rp_core][rate_limit] denied id=%s action=%s reason=%s')
        :format(tostring(identity), tostring(action), tostring(reason)))
end

--- Distributed rate-limit check + consume.
--- @return boolean allowed
local function CanPerformAction(src, action, cooldownMs, opts)
    src = ValidSource(src)
    action = ValidAction(action)
    if not src or not action then return false end

    local identity = ResolveIdentity(src)
    if not identity then return false end

    local minInterval = ClampInt(cooldownMs, 0, 120000, DEFAULT_MIN_INTERVAL)
    local conf = ReadOpts(action, opts)
    local now = Now()
    local cost = conf.cost

    -- 1) Min interval (per identity + action)
    lastActionAt[identity] = lastActionAt[identity] or {}
    local last = lastActionAt[identity][action]
    if last ~= nil and Elapsed(now, last) < minInterval then
        if not conf.silent then LogDeny(identity, action, 'min_interval') end
        return false
    end

    -- 2) Fixed window counter (per identity + action)
    actionWindows[identity] = actionWindows[identity] or {}
    local win = actionWindows[identity][action]
    if not win or Elapsed(now, win.startedAt) >= conf.windowMs then
        win = { count = 0, startedAt = now }
        actionWindows[identity][action] = win
    end
    if win.count >= conf.maxPerWindow then
        if not conf.silent then LogDeny(identity, action, 'action_window') end
        return false
    end

    -- 3) Category token bucket (distributed across actions in the same category)
    categoryBuckets[identity] = categoryBuckets[identity] or {}
    local catOk = TryConsumeBucket(
        categoryBuckets[identity],
        conf.category,
        conf.categoryRate,
        conf.categoryBurst,
        cost,
        now
    )
    if not catOk then
        if not conf.silent then LogDeny(identity, action, 'category_bucket:' .. conf.category) end
        return false
    end

    -- 4) Identity token bucket (all categories share this ceiling)
    local idOk = TryConsumeBucket(
        identityBuckets,
        identity,
        conf.identityRate,
        conf.identityBurst,
        cost,
        now
    )
    if not idOk then
        -- refund category token roughly (best-effort)
        local catBucket = categoryBuckets[identity][conf.category]
        if catBucket then
            catBucket.tokens = math.min(conf.categoryBurst, (catBucket.tokens or 0) + cost)
        end
        if not conf.silent then LogDeny(identity, action, 'identity_bucket') end
        return false
    end

    -- Commit interval + window counters
    lastActionAt[identity][action] = now
    win.count = win.count + 1
    return true
end

local function PeekCanPerformAction(src, action, cooldownMs, opts)
    src = ValidSource(src)
    action = ValidAction(action)
    if not src or not action then return false end
    local identity = ResolveIdentity(src)
    if not identity then return false end

    local minInterval = ClampInt(cooldownMs, 0, 120000, DEFAULT_MIN_INTERVAL)
    local conf = ReadOpts(action, opts)
    local now = Now()

    local lastBucket = lastActionAt[identity]
    if lastBucket and lastBucket[action] ~= nil and Elapsed(now, lastBucket[action]) < minInterval then
        return false
    end

    local windows = actionWindows[identity]
    local win = windows and windows[action] or nil
    if win and Elapsed(now, win.startedAt) < conf.windowMs and win.count >= conf.maxPerWindow then
        return false
    end

    -- Peek category bucket without mutate via local copy
    local catStore = categoryBuckets[identity] or {}
    local catBucket = RefillBucket(catStore[conf.category], conf.categoryRate, conf.categoryBurst, now)
    if (catBucket.tokens or 0) < conf.cost then return false end

    local idBucket = RefillBucket(identityBuckets[identity], conf.identityRate, conf.identityBurst, now)
    if (idBucket.tokens or 0) < conf.cost then return false end

    return true
end

local function GetActionCooldownRemaining(src, action, cooldownMs)
    src = ValidSource(src)
    action = ValidAction(action)
    if not src or not action then return 0 end
    local identity = ResolveIdentity(src)
    if not identity then return 0 end
    local minInterval = ClampInt(cooldownMs, 0, 120000, DEFAULT_MIN_INTERVAL)
    local bucket = lastActionAt[identity]
    if not bucket or bucket[action] == nil then return 0 end
    local remaining = minInterval - Elapsed(Now(), bucket[action])
    if remaining < 0 then return 0 end
    return remaining
end

local function GetRateLimitStatus(src, action, opts)
    src = ValidSource(src)
    if not src then return nil end
    local identity = ResolveIdentity(src)
    if not identity then return nil end
    action = ValidAction(action) or 'default'
    local conf = ReadOpts(action, opts)
    local now = Now()

    local catStore = categoryBuckets[identity] or {}
    local catBucket = RefillBucket(catStore[conf.category], conf.categoryRate, conf.categoryBurst, now)
    local idBucket = RefillBucket(identityBuckets[identity], conf.identityRate, conf.identityBurst, now)

    return {
        identity = identity,
        category = conf.category,
        categoryTokens = catBucket.tokens or 0,
        categoryBurst = conf.categoryBurst,
        identityTokens = idBucket.tokens or 0,
        identityBurst = conf.identityBurst,
        actionCooldownMs = GetActionCooldownRemaining(src, action, opts and opts.cooldownMs or DEFAULT_MIN_INTERVAL),
    }
end

local function ClearPlayerRateLimits(src)
    src = ValidSource(src)
    if not src then return false end
    local identity = srcToIdentity[src] or ResolveIdentity(src)
    srcToIdentity[src] = nil
    if not identity then return true end

    -- Only clear if no other source still mapped to this identity
    for otherSrc, otherId in pairs(srcToIdentity) do
        if otherId == identity and otherSrc ~= src then
            return true
        end
    end

    lastActionAt[identity] = nil
    actionWindows[identity] = nil
    categoryBuckets[identity] = nil
    identityBuckets[identity] = nil
    return true
end

local function ClearIdentityRateLimits(identity)
    if type(identity) ~= 'string' or identity == '' then return false end
    lastActionAt[identity] = nil
    actionWindows[identity] = nil
    categoryBuckets[identity] = nil
    identityBuckets[identity] = nil
    for src, id in pairs(srcToIdentity) do
        if id == identity then srcToIdentity[src] = nil end
    end
    return true
end

exports('CanPerformAction', CanPerformAction)
exports('PeekCanPerformAction', PeekCanPerformAction)
exports('GetActionCooldownRemaining', GetActionCooldownRemaining)
exports('GetRateLimitStatus', GetRateLimitStatus)
exports('ClearPlayerRateLimits', ClearPlayerRateLimits)
exports('ClearIdentityRateLimits', ClearIdentityRateLimits)

-- Cleanup orphaned identities every 2 minutes
CreateThread(function()
    while true do
        Wait(120000)
        local live = {}
        for _, id in pairs(srcToIdentity) do
            live[id] = true
        end
        -- Drop cached maps for sources that left
        for src in pairs(srcToIdentity) do
            if not GetPlayerName(src) then
                local identity = srcToIdentity[src]
                srcToIdentity[src] = nil
                local stillUsed = false
                for _, id in pairs(srcToIdentity) do
                    if id == identity then stillUsed = true break end
                end
                if identity and not stillUsed then
                    lastActionAt[identity] = nil
                    actionWindows[identity] = nil
                    categoryBuckets[identity] = nil
                    identityBuckets[identity] = nil
                end
            end
        end
    end
end)

print('[rp_core] [OK] Distributed rate-limit module loaded (identity + category token buckets)')
