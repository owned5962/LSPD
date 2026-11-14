fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'FiveM RP Team'
description 'Character registration and character creator for FiveM'
version '1.2.0'
dependencies { 'oxmysql', 'rp_core', 'rp_jobs' }
ui_page 'html/index.html'
files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'client/c1.lua',
    'client/c2.lua',
    'client/c3.lua',
    'client/c4.lua',
    'server/modules/01_helpers.lua',
    'server/modules/02_bootstrap.lua',
    'server/modules/03_select_create.lua'
}
client_scripts { 'client/main.lua' }
server_scripts {
    'server/diagnostics.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/bootstrap_hook.lua'
}
