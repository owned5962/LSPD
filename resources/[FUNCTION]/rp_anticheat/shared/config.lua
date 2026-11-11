Config = {}

-- Real-time in-game configurable toggles
Config.Protections = {
    ['godmode'] = { label = 'Détection GodMode (Invincibilité)', enabled = true },
    ['speedhack'] = { label = 'Détection SpeedHack / SuperVitesse', enabled = true },
    ['blacklisted_weapons'] = { label = 'Armes Blacklistées (RPG, Minigun)', enabled = true },
    ['thermal_night_vision'] = { label = 'Vision Thermique / Nocturne Illégale', enabled = true },
    ['spectate_monitoring'] = { label = 'Surveillance Staff en Direct', enabled = true },
    ['explosion_spam'] = { label = 'Protection anti-spam d’explosions (serveur)', enabled = true },
    ['weapon_damage'] = { label = 'Blocage serveur des armes interdites', enabled = true },
    ['entity_spam'] = { label = 'Protection anti-spam d’entités (serveur)', enabled = true }
}

Config.BlacklistedWeapons = {
    GetHashKey('WEAPON_RPG'),
    GetHashKey('WEAPON_MINIGUN'),
    GetHashKey('WEAPON_RAILGUN'),
    GetHashKey('WEAPON_HOMINGLAUNCHER'),
    GetHashKey('WEAPON_COMPACTLAUNCHER'),
    GetHashKey('WEAPON_GRENADELAUNCHER')
}

Config.MaxSpeed = 10.0 -- Max pedestrian speed (m/s) before flag
Config.AlertStaffChat = true

Config.MaxExplosionsPerWindow = 5
Config.ExplosionWindowSeconds = 5

Config.MaxEntitiesPerWindow = 35
Config.EntityWindowSeconds = 10
