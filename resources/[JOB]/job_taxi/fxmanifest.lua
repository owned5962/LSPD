fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Server'
description 'Dedicated RP Job: Chauffeur de Taxi Downtown Cab (transport)'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies { 'rp_core', 'rp_ui' }
