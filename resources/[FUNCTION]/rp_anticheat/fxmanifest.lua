fx_version 'cerulean'
game 'gta5'

author 'FiveM RP Team'
description 'AEGIS Security Center: live monitoring, detections, protections and ban management'
version '2.0.0'

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

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

dependencies { 'oxmysql', 'rp_tablet_creator', 'rp_inventory', 'rp_core', 'rp_jobs' }
