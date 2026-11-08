fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Core system for GTA 5 Roleplay (events, sessions, permissions, notifications)'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/notify.lua'
}

server_scripts {
    'server/main.lua',
    'server/player.lua',
    'server/commands.lua'
}
