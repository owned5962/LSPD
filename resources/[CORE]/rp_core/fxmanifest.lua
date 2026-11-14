fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM RP Team'
description 'Core system for GTA 5 Roleplay (events, sessions, permissions, notifications)'
version '1.1.4'

dependency 'oxmysql'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/notify.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/rate_limit.lua',
    'server/main.lua',
    'server/player.lua',
    'server/commands.lua'
}

server_exports {
    'CanPerformAction',
    'GetActionCooldownRemaining',
    'ClearPlayerRateLimits',
    'PeekCanPerformAction',
    'IsCharacterSavePending',
    'WaitForPlayerLoaded',
    'IsPlayerLoaded',
    'SetPlayerDuty',
    'GetPlayerSnapshot',
    'RegisterPlayer',
    'UnregisterPlayer',
    'GetPlayer',
    'GetPlayerFromId',
    'GetPlayerByIdentifier',
    'GetAllPlayers',
    'CreateRPPlayer',
    'TransferCash',
    'AcquireCharacterLock',
    'ReleaseCharacterLock'
}
