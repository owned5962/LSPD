dofile('resources/[CORE]/rp_core/shared/utils.lua')

assert(Utils.FormatCurrency(1234567) == '1 234 567 $')
assert(Utils.FormatCurrency(-1234) == '-1 234 $')
assert(Utils.FormatCurrency(nil) == '0 $')
assert(Utils.FormatCurrency('not-a-number') == '0 $')
assert(Utils.Trim('  Los Santos  ') == 'Los Santos')
assert(Utils.Trim(nil) == '')

local cyclic = { label = 'safe' }
cyclic.self = cyclic
local dump = Utils.TableDump(cyclic)
assert(dump:find('<cycle>', 1, true) ~= nil)

print('Core shared utility tests passed.')

local fallback = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }
local valid = Utils.NormalizePosition({ x = 100.5, y = -200.25, z = 35.0, heading = 450.0 }, fallback)
assert(valid.x == 100.5 and valid.y == -200.25 and valid.z == 35.0 and valid.heading == 90.0)
local invalid = Utils.NormalizePosition({ x = 99999, y = 0, z = 0, heading = 0 }, fallback)
assert(invalid.x == fallback.x and invalid.y == fallback.y and invalid.z == fallback.z)
local malformed = Utils.NormalizePosition({ x = 0, y = 0, z = 0, heading = 0/0 }, fallback)
assert(malformed.heading == fallback.heading)
