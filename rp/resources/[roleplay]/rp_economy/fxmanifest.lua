fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Banking, Cash, ATMs, Automated Salaries and Financial System'
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
