fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Framework'
description 'Los Santos business locations and map blips'
version '1.1.0'

server_scripts {\n    '@oxmysql/lib/MySQL.lua',\n    'server/main.lua'\n}\n\ndependencies { 'oxmysql', 'rp_core' }\n\nshared_scripts {
    'shared/locations.lua'
}

client_scripts {
    'client/main.lua'
}
