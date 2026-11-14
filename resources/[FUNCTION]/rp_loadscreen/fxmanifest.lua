fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'GAutier'
description 'Los Santos Stories live loading screen'
version '1.3.0'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'

shared_scripts {
    'updates.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/images/los_santos_skyline.svg',
    'html/images/los_santos_police.svg',
    'html/images/los_santos_downtown.svg',
    'html/images/los_santos_ems.svg',
    'html/images/los_santos_jobs.svg',
    'html/images/los_santos_coast.svg',
    'html/images/los_santos_illegal.svg'
}
