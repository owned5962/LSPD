fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'GAutier'
description 'Stations-service et gestion du carburant'
version '1.0.0'

dependencies { 'rp_core', 'rp_ui', 'oxmysql' }

shared_scripts { 'shared/config.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/css/style.css', 'html/js/app.js' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
