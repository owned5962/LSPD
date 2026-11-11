fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Stories'
description 'Interpellations PNJ sans étoiles Wanted et alertes LSPD'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'rp_core', 'job_police' }
