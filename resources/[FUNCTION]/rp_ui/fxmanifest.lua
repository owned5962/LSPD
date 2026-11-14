fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Framework'
description 'Modern TextUI & Animated Progress Bar'
version '1.1.0'

dependency 'rp_core'
dependency 'rp_jobs'
dependency 'oxmysql'

ui_page 'html/index.html'

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
    'html/js/app.js',
    'html/images/diagnostics-hero.svg'
}
