fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Los Santos Stories cinematic loading screen with live phase telemetry'
version '1.2.0'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'

client_scripts {
    'client/main.lua'
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
    'html/images/los_santos_coast.svg'
}
