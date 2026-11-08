fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_phone'
description 'Smartphone Roleplay ultra-moderne avec Appels, SMS, Contacts, Banque, Services Urgences & Twitter'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}
