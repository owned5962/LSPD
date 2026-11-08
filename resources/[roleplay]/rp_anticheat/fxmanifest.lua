fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Team'
description 'In-Game Configurable Anticheat with Live Player Surveillance & Notifications'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

dependency 'oxmysql'
