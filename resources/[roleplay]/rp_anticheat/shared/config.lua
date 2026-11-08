Config = {}

-- Real-time in-game configurable toggles
Config.Protections = {
    ['godmode'] = { label = 'Détection GodMode (Invincibilité)', enabled = true },
    ['speedhack'] = { label = 'Détection SpeedHack / SuperVitesse', enabled = true },
    ['blacklisted_weapons'] = { label = 'Armes Blacklistées (RPG, Minigun)', enabled = true },
    ['thermal_night_vision'] = { label = 'Vision Thermique / Nocturne Illégale', enabled = true },
    ['spectate_monitoring'] = { label = 'Surveillance Staff en Direct', enabled = true }
}

Config.BlacklistedWeapons = {
    `WEAPON_RPG`,
    `WEAPON_MINIGUN`,
    `WEAPON_RAILGUN`,
    `WEAPON_HOMINGLAUNCHER`,
    `WEAPON_COMPACTLAUNCHER`,
    `WEAPON_GRENADELAUNCHER`
}

Config.MaxSpeed = 10.0 -- Max pedestrian speed (m/s) before flag
Config.AlertStaffChat = true
