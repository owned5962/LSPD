fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Modern Tablet-Style Admin Menu OS with Player Management, Economy, Jobs, Weather & Vehicles'
version '1.0.1'

dependencies { 'oxmysql', 'rp_core', 'rp_jobs', 'rp_inventory', 'rp_tablet_creator', 'rp_anticheat' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/css/f10-sidebar.css',
    'html/js/app.js',
    'html/images/los_santos_map.svg',
    'html/images/admin-hero.svg',
    'html/images/tab-players.svg',
    'html/images/tab-gives.svg',
    'html/images/tab-sanctions.svg',
    'html/images/tab-functions.svg',
    'html/images/tab-jobs.svg',
    'html/images/tab-weather.svg',
    'html/images/tab-map.svg',
    'html/images/tab-reports.svg',
    'html/images/tab-audit.svg'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/extended.lua'
}
