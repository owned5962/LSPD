fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Los Santos Roleplay'
description 'Registre persistant des gangs créé depuis la tablette Creator'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies { 'oxmysql' }
