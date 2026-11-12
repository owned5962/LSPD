fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Framework'
description 'Los Santos business locations, shopkeeper NPCs and purchase tablets'
version '1.2.0'

ui_page 'html/index.html'

shared_scripts {
    'shared/locations.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/images/pistol.svg'
}

dependencies { 'oxmysql', 'rp_core', 'rp_ui', 'rp_inventory' }
