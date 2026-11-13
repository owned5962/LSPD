fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Framework'
description 'F6 Job Actions, Cuffing, Billing, and Player Interactions'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies { 'oxmysql', 'rp_core' }

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}
