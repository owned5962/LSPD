fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Character registration and character creator for FiveM'
version '1.1.3'

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
    'client/p8.lua',
    'client/p9.lua',
    'client/p10.lua',
    'client/p11.lua',
    'client/p12.lua',
    'client/p13.lua',
    'client/p14.lua',
    'client/p15.lua',
    'client/p16.lua',
    'client/p17.lua',
    'client/p18.lua',
    'client/p19.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
