fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rp_stockmarket'
description 'Bourse financiere BAWSAQ de Los Santos avec fluctuations en temps reel, achat/vente d actions'
version '1.0.0'

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
