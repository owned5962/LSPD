fx_version 'cerulean'
game 'gta5'
author 'FiveM RP Server'
description 'Activités illégales RP : récolte, vente, braquages et dispatch LSPD'
version '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies { 'oxmysql', 'rp_core', 'rp_inventory', 'job_police' }
