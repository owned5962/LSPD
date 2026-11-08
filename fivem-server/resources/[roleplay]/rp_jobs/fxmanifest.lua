fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description '50 Roleplay Jobs system with job center NUI, duties and salaries'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

shared_scripts {
    'shared/jobs_list.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
