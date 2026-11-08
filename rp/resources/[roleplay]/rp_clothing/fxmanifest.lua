fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Framework'
description 'Clothing Store & Dressing System'
version '1.0.0'

ui_page 'html/index.html'

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}
