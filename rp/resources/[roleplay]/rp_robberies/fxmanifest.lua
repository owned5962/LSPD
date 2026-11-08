fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_robberies'
description 'Systeme de braquages de Banques (Fleeca, Pacific) et DAB / ATM avec mini-jeu NUI'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}
