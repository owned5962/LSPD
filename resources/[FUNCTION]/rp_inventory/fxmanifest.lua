fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Framework'
description 'Grid-based Drag & Drop Inventory System'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/job_storage.lua'
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

dependencies { 'oxmysql', 'rp_core', 'rp_ui' }

