fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'FiveM RP Team'
description 'Character registration and character creator for FiveM'
version '1.1.9'
dependencies { 'oxmysql', 'rp_core', 'rp_jobs' }
ui_page 'html/index.html'
files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'client/p1.lua',
    'client/p2.lua',
    'client/p10.lua',
    'client/p11.lua',
    'client/p12.lua',
    'client/p25.lua',
    'client/p26.lua',
    'client/p27.lua',
    'client/p28.lua'
}
client_scripts { 'client/main.lua' }
server_scripts {
    'server/diagnostics.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
