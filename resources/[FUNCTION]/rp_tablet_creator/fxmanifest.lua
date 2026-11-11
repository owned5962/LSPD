fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Tablette indépendante de gestion créateur'
version '1.0.0'

dependencies { 'rp_core' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }
