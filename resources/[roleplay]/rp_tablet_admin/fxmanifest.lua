fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Modern Tablet-Style Admin Menu OS with Player Management, Economy, 50 Jobs, Weather & Vehicles'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
