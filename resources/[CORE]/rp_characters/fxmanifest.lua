fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Character registration and character creator for FiveM'
version '1.1.1'

dependencies { 'oxmysql', 'rp_core', 'rp_jobs' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'client/p1.lua',
    'client/p2.lua',
    'client/p3.lua',
    'client/p4.lua',
    'client/p5.lua',
    'client/p6.lua',
    'client/p7.lua',
    'client/p8.lua'
}

client_scripts {
    'client/bootstrap.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
