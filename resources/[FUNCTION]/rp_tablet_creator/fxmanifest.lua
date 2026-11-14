fx_version 'cerulean'
game 'gta5'
nui_callback_strict_mode 'true'
lua54 'yes'

author 'GAutier'
description 'Tablette indépendante de gestion créateur, mapping et blips métiers'
version '1.1.2'

dependencies { 'rp_core', 'rp_jobs', 'rp_inventory', 'rp_characters', 'rp_gangs', 'rp_economy', 'oxmysql' }

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/creator-hero.svg'
}

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
