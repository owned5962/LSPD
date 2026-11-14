-- Loader: reconstructs the character server runtime from ordered modules.
-- Kept small so GitHub/API pushes cannot truncate the gameplay logic.
local RESOURCE = GetCurrentResourceName()
local MODULES = {
    'server/modules/01_helpers.lua',
    'server/modules/02_bootstrap.lua',
    'server/modules/03_select_create.lua',
}

for _, rel in ipairs(MODULES) do
    local src = LoadResourceFile(RESOURCE, rel)
    if not src or src == '' then
        print(('[rp_characters] FATAL missing server module %s'):format(rel))
        return
    end
    local chunk, err = load(src, ('@@%s/%s'):format(RESOURCE, rel))
    if not chunk then
        print(('[rp_characters] FATAL compile %s: %s'):format(rel, tostring(err)))
        return
    end
    local ok, runtimeErr = xpcall(chunk, debug.traceback)
    if not ok then
        print(('[rp_characters] FATAL runtime %s: %s'):format(rel, tostring(runtimeErr)))
        return
    end
end

print('[rp_characters] [OK] Server modules loaded')
