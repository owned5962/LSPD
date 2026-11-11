fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Roleplay'
description 'Concessionnaire automobile avec achats persistants'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/images/compact.svg',
    'html/images/sedan.svg',
    'html/images/motorcycle.svg'
}

dependencies { 'oxmysql', 'rp_core', 'rp_ui' }
