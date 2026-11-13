fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Roleplay'
description 'Garages personnels avec persistance des véhicules'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua', 'client/job_garage.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/job_garage.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies { 'oxmysql', 'rp_core', 'rp_ui', 'rp_vehicle_dealership' }
