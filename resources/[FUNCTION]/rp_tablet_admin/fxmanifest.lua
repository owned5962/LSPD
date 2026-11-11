fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Modern Tablet-Style Admin Menu OS with Player Management, Economy, 50 Jobs, Weather & Vehicles'
version '1.0.0'

dependencies { 'oxmysql', 'rp_core', 'rp_jobs', 'rp_inventory', 'rp_tablet_creator', 'rp_anticheat' }


ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/images/los_santos_map.svg'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/extended.lua'
}
