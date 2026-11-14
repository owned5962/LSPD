-- Bootstrap: assemble split source and run as one chunk (preserves locals).
local res = GetCurrentResourceName()
local parts = {
    LoadResourceFile(res, 'client/p1.lua'),
    LoadResourceFile(res, 'client/p2.lua'),
    LoadResourceFile(res, 'client/p3.lua'),
    LoadResourceFile(res, 'client/p4.lua'),
    LoadResourceFile(res, 'client/p5.lua'),
    LoadResourceFile(res, 'client/p6.lua'),
    LoadResourceFile(res, 'client/p7.lua'),
    LoadResourceFile(res, 'client/p8.lua'),
    LoadResourceFile(res, 'client/p9.lua'),
    LoadResourceFile(res, 'client/p10.lua'),
    LoadResourceFile(res, 'client/p11.lua'),
    LoadResourceFile(res, 'client/p12.lua'),
    LoadResourceFile(res, 'client/p13.lua'),
    LoadResourceFile(res, 'client/p14.lua'),
    LoadResourceFile(res, 'client/p15.lua'),
    LoadResourceFile(res, 'client/p16.lua'),
    LoadResourceFile(res, 'client/p17.lua')
}
for i, part in ipairs(parts) do
    if not part or part == '' then
        print(('[rp_characters] missing client/p%d.lua'):format(i))
        return
    end
end
local src = table.concat(parts)
local fn, err = load(src, '@client/main.lua')
if not fn then
    print('[rp_characters] load error: ' .. tostring(err))
    return
end
fn()
