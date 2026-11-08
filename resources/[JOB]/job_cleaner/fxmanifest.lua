fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Server'
description 'Dedicated RP Job: Agent d'Entretien & Nettoyage Urbain (public_service)'
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
