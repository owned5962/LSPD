fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Roleplay'
description 'Location de véhicules aux points de première apparition'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies { 'rp_core', 'rp_ui' }
