fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Stories'
description 'Tablette métier contextuelle F4'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_script '@rp_jobs/shared/jobs_list.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'rp_core',
    'rp_jobs',
    'rp_economy'
}
