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
