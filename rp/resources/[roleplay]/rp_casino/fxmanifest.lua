fx_version 'cerulean'
game 'gta5'

name 'rp_casino'
description 'The Diamond Casino & Resort - Jetons, Roue de la Fortune, Machines à Sous & Roulette'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

client_scripts {
    'config.lua',
    'client/main.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}
