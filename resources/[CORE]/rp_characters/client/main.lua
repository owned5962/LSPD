-- Optimized client loader: boundary-split parts (fewer I/O, cut at block ends).
local res = GetCurrentResourceName()
local PART_COUNT = 7
local parts = {}
for i = 1, PART_COUNT do
    local name = ('client/p%d.lua'):format(i)
    local part = LoadResourceFile(res, name)
    if not part or part == '' then
        print(('[rp_characters] FATAL: missing %s — cannot assemble client'):format(name))
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
