-- Loads ordered server modules and executes them as ONE chunk so `local` bindings work.
local RESOURCE = GetCurrentResourceName()
local MODULES = {
    'server/modules/01_helpers.lua',
    'server/modules/02_bootstrap.lua',
    'server/modules/03_select_create.lua',
}

local buffer = {}
for _, rel in ipairs(MODULES) do
    local src = LoadResourceFile(RESOURCE, rel)
    if not src or src == '' then
        print(('[rp_characters] FATAL missing server module %s'):format(rel))
        return
    end
    -- Guard against previously truncated uploads.
    if src:match('^%s*%-%-%s*truncated') or #src < 64 then
        print(('[rp_characters] FATAL module %s looks truncated (%d bytes)'):format(rel, #src))
        return
    end
    buffer[#buffer + 1] = src
    if src:sub(-1) ~= '\n' then
        buffer[#buffer + 1] = '\n'
    end
end

local combined = table.concat(buffer)
local chunk, err = load(combined, ('@@%s/server/modules/*'):format(RESOURCE))
if not chunk then
    print(('[rp_characters] FATAL compile server modules: %s'):format(tostring(err)))
    return
end

local ok, runtimeErr = xpcall(chunk, debug.traceback)
if not ok then
    print(('[rp_characters] FATAL runtime server modules: %s'):format(tostring(runtimeErr)))
    return
end

if type(CheckPlayerBootstrap) ~= 'function' then
    print('[rp_characters] WARN: CheckPlayerBootstrap was not published globally')
end

print(('[rp_characters] [OK] Server character pipeline loaded (%d bytes across %d modules)')
    :format(#combined, #MODULES))
