local res = GetCurrentResourceName()
local PART_COUNT = 28
local parts = {}
for i = 1, PART_COUNT do
    local name = ('client/p%d.lua'):format(i)
    local part = LoadResourceFile(res, name)
    if not part or part == '' then
        print(('[rp_characters] FATAL: missing %s'):format(name))
        return
    end
    parts[i] = part
end
local fn, err = load(table.concat(parts), '@rp_characters/client/main.lua')
if not fn then
    print('[rp_characters] load error: ' .. tostring(err))
    return
end
fn()
