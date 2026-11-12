fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Roleplay'
description 'Auto-école : examens théoriques et pratiques pour cinq catégories de permis'
version '1.0.0'

dependency 'oxmysql'
dependencies { 'rp_core', 'rp_ui' }

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
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
