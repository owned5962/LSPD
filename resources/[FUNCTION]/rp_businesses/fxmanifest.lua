fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Framework'
description 'Los Santos business locations and map blips'
version '1.1.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies { 'oxmysql', 'rp_core' }

shared_scripts {
    'shared/locations.lua'
}

client_scripts {
    'client/main.lua'
}
