local res = GetCurrentResourceName()
local parts = {
    LoadResourceFile(res, 'client/p1.lua') or '',
    LoadResourceFile(res, 'client/p2.lua') or '',
    LoadResourceFile(res, 'client/p3.lua') or '',
    LoadResourceFile(res, 'client/p4.lua') or '',
    LoadResourceFile(res, 'client/p5.lua') or '',
    LoadResourceFile(res, 'client/p6.lua') or '',
    LoadResourceFile(res, 'client/p7.lua') or '',
    LoadResourceFile(res, 'client/p8.lua') or '',
    LoadResourceFile(res, 'client/p9.lua') or '',
    LoadResourceFile(res, 'client/p10.lua') or '',
    LoadResourceFile(res, 'client/p11.lua') or '',
    LoadResourceFile(res, 'client/p12.lua') or '',
    LoadResourceFile(res, 'client/p13.lua') or '',
    LoadResourceFile(res, 'client/p14.lua') or '',
    LoadResourceFile(res, 'client/p15.lua') or '',
    LoadResourceFile(res, 'client/p16.lua') or '',
    LoadResourceFile(res, 'client/p17.lua') or '',
    LoadResourceFile(res, 'client/p18.lua') or '',
    LoadResourceFile(res, 'client/p19.lua') or '',
    LoadResourceFile(res, 'client/p20.lua') or '',
    LoadResourceFile(res, 'client/p21.lua') or '',
    LoadResourceFile(res, 'client/p22.lua') or '',
    LoadResourceFile(res, 'client/p23.lua') or '',
    LoadResourceFile(res, 'client/p24.lua') or '',
    LoadResourceFile(res, 'client/p25.lua') or '',
    LoadResourceFile(res, 'client/p26.lua') or '',
    LoadResourceFile(res, 'client/p27.lua') or '',
    LoadResourceFile(res, 'client/p28.lua') or ''
}
local missing = {}
for i, part in ipairs(parts) do
    if not part or part == '' then missing[#missing+1] = i end
end
if #missing > 0 then
    print(('[rp_characters] FATAL missing parts: %s'):format(table.concat(missing, ',')))
    return
end
local fn, err = load(table.concat(parts), '@rp_characters/client/main.lua')
if not fn then
    print('[rp_characters] load error: ' .. tostring(err))
    return
end
fn()
