fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Roleplay'
description 'Individual weekly claimable map territories'
version '1.0.0'

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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'oxmysql'
