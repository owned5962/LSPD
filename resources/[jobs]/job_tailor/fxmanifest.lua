fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Server'
description 'Dedicated RP Job: Couturier & Designer de Mode (artisanat)'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/main.lua'
}
