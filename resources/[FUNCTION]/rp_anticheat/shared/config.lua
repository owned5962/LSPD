Config = {}

-- Real-time in-game configurable toggles
Config.Protections = {
    ['godmode'] = { label = 'Détection GodMode (Invincibilité)', enabled = true },
    ['speedhack'] = { label = 'Détection SpeedHack / SuperVitesse', enabled = true },
    ['blacklisted_weapons'] = { label = 'Armes interdites (liste administrateur)', enabled = true },
    ['thermal_night_vision'] = { label = 'Vision Thermique / Nocturne Illégale', enabled = true },
    ['spectate_monitoring'] = { label = 'Surveillance Staff en Direct', enabled = true },
    ['explosion_spam'] = { label = 'Protection anti-spam d’explosions (serveur)', enabled = true },
    ['weapon_damage'] = { label = 'Blocage serveur des armes interdites', enabled = true },
    ['entity_spam'] = { label = 'Protection anti-spam d’entités (serveur)', enabled = true }
}

-- Catalogue central des armes. enabled=true signifie autorisée ; false signifie interdite.
-- Les états effectifs sont chargés depuis MySQL par rp_anticheat au démarrage.
Config.WeaponCatalog = {
    { name = 'WEAPON_KNIFE', label = "Couteau", category = "Mêlée", enabled = true },
    { name = 'WEAPON_NIGHTSTICK', label = "Matraque", category = "Mêlée", enabled = true },
    { name = 'WEAPON_HAMMER', label = "Marteau", category = "Mêlée", enabled = true },
    { name = 'WEAPON_BAT', label = "Batte", category = "Mêlée", enabled = true },
    { name = 'WEAPON_GOLFCLUB', label = "Club de golf", category = "Mêlée", enabled = true },
    { name = 'WEAPON_CROWBAR', label = "Pied-de-biche", category = "Mêlée", enabled = true },
    { name = 'WEAPON_BOTTLE', label = "Bouteille", category = "Mêlée", enabled = true },
    { name = 'WEAPON_DAGGER', label = "Dague", category = "Mêlée", enabled = true },
    { name = 'WEAPON_HATCHET', label = "Hachette", category = "Mêlée", enabled = true },
    { name = 'WEAPON_MACHETE', label = "Machette", category = "Mêlée", enabled = true },
    { name = 'WEAPON_FLASHLIGHT', label = "Lampe torche", category = "Mêlée", enabled = true },
    { name = 'WEAPON_SWITCHBLADE', label = "Couteau à cran d'arrêt", category = "Mêlée", enabled = true },
    { name = 'WEAPON_BATTLEAXE', label = "Hache de combat", category = "Mêlée", enabled = true },
    { name = 'WEAPON_POOLCUE', label = "Queue de billard", category = "Mêlée", enabled = true },
    { name = 'WEAPON_WRENCH', label = "Clé anglaise", category = "Mêlée", enabled = true },
    { name = 'WEAPON_PISTOL', label = "Pistolet", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_COMBATPISTOL', label = "Pistolet de combat", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_APPISTOL', label = "Pistolet automatique", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_PISTOL50', label = "Pistolet calibre .50", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_SNSPISTOL', label = "Pistolet SNS", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_HEAVYPISTOL', label = "Pistolet lourd", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_VINTAGEPISTOL', label = "Pistolet vintage", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_MARKSMANPISTOL', label = "Pistolet de précision", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_REVOLVER', label = "Revolver", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_DOUBLEACTION', label = "Revolver double action", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_CERAMICPISTOL', label = "Pistolet céramique", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_NAVYREVOLVER', label = "Revolver Navy", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_GADGETPISTOL', label = "Pistolet Perico", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_STUNGUN', label = "Taser", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_MICROSMG', label = "Micro-SMG", category = "Mitraillettes", enabled = true },
    { name = 'WEAPON_SMG', label = "SMG", category = "Mitraillettes", enabled = true },
    { name = 'WEAPON_ASSAULTSMG', label = "SMG d'assaut", category = "Mitraillettes", enabled = true },
    { name = 'WEAPON_COMBATPDW', label = "PDW de combat", category = "Mitraillettes", enabled = true },
    { name = 'WEAPON_MACHINEPISTOL', label = "Pistolet-mitrailleur", category = "Mitraillettes", enabled = true },
    { name = 'WEAPON_MINISMG', label = "Mini-SMG", category = "Mitraillettes", enabled = true },
    { name = 'WEAPON_ASSAULTRIFLE', label = "Fusil d'assaut", category = "Fusils", enabled = true },
    { name = 'WEAPON_CARBINERIFLE', label = "Carabine", category = "Fusils", enabled = true },
    { name = 'WEAPON_ADVANCEDRIFLE', label = "Fusil avancé", category = "Fusils", enabled = true },
    { name = 'WEAPON_SPECIALCARBINE', label = "Carabine spéciale", category = "Fusils", enabled = true },
    { name = 'WEAPON_BULLPUPRIFLE', label = "Fusil bullpup", category = "Fusils", enabled = true },
    { name = 'WEAPON_COMPACTRIFLE', label = "Fusil compact", category = "Fusils", enabled = true },
    { name = 'WEAPON_MILITARYRIFLE', label = "Fusil militaire", category = "Fusils", enabled = true },
    { name = 'WEAPON_HEAVYRIFLE', label = "Fusil lourd", category = "Fusils", enabled = true },
    { name = 'WEAPON_TACTICALRIFLE', label = "Fusil tactique", category = "Fusils", enabled = true },
    { name = 'WEAPON_PUMPSHOTGUN', label = "Fusil à pompe", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_SAWNOFFSHOTGUN', label = "Fusil à canon scié", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_ASSAULTSHOTGUN', label = "Fusil à pompe d'assaut", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_BULLPUPSHOTGUN', label = "Fusil à pompe bullpup", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_MUSKET', label = "Mousquet", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_HEAVYSHOTGUN', label = "Fusil à pompe lourd", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_DBSHOTGUN', label = "Fusil à double canon", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_AUTOSHOTGUN', label = "Fusil à pompe automatique", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_SNIPERRIFLE', label = "Fusil de précision", category = "Fusils de précision", enabled = true },
    { name = 'WEAPON_HEAVYSNIPER', label = "Fusil de précision lourd", category = "Fusils de précision", enabled = true },
    { name = 'WEAPON_MARKSMANRIFLE', label = "Fusil de tireur d'élite", category = "Fusils de précision", enabled = true },
    { name = 'WEAPON_PRECISIONRIFLE', label = "Fusil de précision tactique", category = "Fusils de précision", enabled = true },
    { name = 'WEAPON_GRENADE', label = "Grenade", category = "Explosifs", enabled = true },
    { name = 'WEAPON_STICKYBOMB', label = "Bombe collante", category = "Explosifs", enabled = true },
    { name = 'WEAPON_SMOKEGRENADE', label = "Grenade fumigène", category = "Explosifs", enabled = true },
    { name = 'WEAPON_BZGAS', label = "Gaz BZ", category = "Explosifs", enabled = true },
    { name = 'WEAPON_MOLOTOV', label = "Cocktail Molotov", category = "Explosifs", enabled = true },
    { name = 'WEAPON_PROXMINE', label = "Mine de proximité", category = "Explosifs", enabled = true },
    { name = 'WEAPON_PIPEBOMB', label = "Bombe artisanale", category = "Explosifs", enabled = true },
    { name = 'WEAPON_RPG', label = "Lance-roquettes RPG", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_MINIGUN', label = "Minigun", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_RAILGUN', label = "Railgun", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_HOMINGLAUNCHER', label = "Lance-missiles téléguidé", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_COMPACTLAUNCHER', label = "Lance-grenades compact", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_GRENADELAUNCHER', label = "Lance-grenades", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_FIREWORK', label = "Lance-feux d'artifice", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_RAYMINIGUN', label = "Up-n-Atomizer", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_RAYPISTOL', label = "Pistolet alien", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_RAYCARBINE', label = "Carabine alien", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_EMPLAUNCHER', label = "Lanceur EMP", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_BALL', label = "Balle", category = "Divers", enabled = true },
    { name = 'WEAPON_SNOWBALL', label = "Boule de neige", category = "Divers", enabled = true },
    { name = 'WEAPON_FLARE', label = "Fusée de détresse", category = "Divers", enabled = true },
    { name = 'WEAPON_PETROLCAN', label = "Bidon d'essence", category = "Divers", enabled = true },
    { name = 'WEAPON_FIREEXTINGUISHER', label = "Extincteur", category = "Divers", enabled = true },
    { name = 'WEAPON_HAZARDCAN', label = "Bidon dangereux", category = "Divers", enabled = true },
    { name = 'WEAPON_KNUCKLE', label = "Poing américain", category = "Mêlée", enabled = true },
    { name = 'WEAPON_STONE_HATCHET', label = "Hache en pierre", category = "Mêlée", enabled = true },
    { name = 'WEAPON_CANDYCANE', label = "Canne en sucre", category = "Mêlée", enabled = true },
    { name = 'WEAPON_PISTOLXM3', label = "Pistolet XM3", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_TECPISTOL', label = "Pistolet tactique", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_FLAREGUN', label = "Pistolet de détresse", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_MG', label = "Mitrailleuse", category = "Mitrailleuses", enabled = true },
    { name = 'WEAPON_COMBATMG', label = "Mitrailleuse de combat", category = "Mitrailleuses", enabled = true },
    { name = 'WEAPON_COMBATMG_MK2', label = "Mitrailleuse de combat Mk II", category = "Mitrailleuses", enabled = true },
    { name = 'WEAPON_GUSENBERG', label = "Mitrailleuse Gusenberg", category = "Mitrailleuses", enabled = true },
    { name = 'WEAPON_ASSAULTRIFLE_MK2', label = "Fusil d'assaut Mk II", category = "Fusils", enabled = true },
    { name = 'WEAPON_CARBINERIFLE_MK2', label = "Carabine Mk II", category = "Fusils", enabled = true },
    { name = 'WEAPON_SPECIALCARBINE_MK2', label = "Carabine spéciale Mk II", category = "Fusils", enabled = true },
    { name = 'WEAPON_BULLPUPRIFLE_MK2', label = "Fusil bullpup Mk II", category = "Fusils", enabled = true },
    { name = 'WEAPON_BATTLERIFLE', label = "Fusil de combat", category = "Fusils", enabled = true },
    { name = 'WEAPON_SMG_MK2', label = "SMG Mk II", category = "Mitraillettes", enabled = true },
    { name = 'WEAPON_PUMPSHOTGUN_MK2', label = "Fusil à pompe Mk II", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_HEAVYSNIPER_MK2', label = "Fusil de précision lourd Mk II", category = "Fusils de précision", enabled = true },
    { name = 'WEAPON_MARKSMANRIFLE_MK2', label = "Fusil de tireur d'élite Mk II", category = "Fusils de précision", enabled = true },
    { name = 'WEAPON_SNIPERRIFLE_MK2', label = "Fusil de précision Mk II", category = "Fusils de précision", enabled = true },
    { name = 'WEAPON_GRENADELAUNCHER_SMOKE', label = "Lance-grenades fumigènes", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_PISTOL_MK2', label = "Pistolet Mk II", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_SNSPISTOL_MK2', label = "Pistolet SNS Mk II", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_REVOLVER_MK2', label = "Revolver Mk II", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_SWEEPERSHOTGUN', label = "Fusil à pompe balayeur", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_COMBATSHOTGUN', label = "Fusil à pompe de combat", category = "Fusils à pompe", enabled = true },
    { name = 'WEAPON_STUNGUN_MP', label = "Taser MP", category = "Armes de poing", enabled = true },
    { name = 'WEAPON_RAILGUNXM3', label = "Railgun XM3", category = "Armes lourdes", enabled = false },
    { name = 'WEAPON_RAYPISTOL', label = "Pistolet alien", category = "Armes lourdes", enabled = false }
}
Config.WeaponPolicy = {}
Config.WeaponHashToName = {}
Config.BlacklistedWeapons = {}
for _, weapon in ipairs(Config.WeaponCatalog) do
    Config.WeaponPolicy[weapon.name] = weapon.enabled
    Config.WeaponHashToName[GetHashKey(weapon.name)] = weapon.name
    if not weapon.enabled then Config.BlacklistedWeapons[#Config.BlacklistedWeapons + 1] = GetHashKey(weapon.name) end
end

Config.MaxSpeed = 10.0 -- Max pedestrian speed (m/s) before flag
Config.AlertStaffChat = true

Config.MaxExplosionsPerWindow = 5
Config.ExplosionWindowSeconds = 5

Config.MaxEntitiesPerWindow = 35
Config.EntityWindowSeconds = 10


-- Automatic sanctions are deliberately set to warning by default.
-- Administrators can configure each detection category from the AEGIS tablet.
Config.Sanctions = {
    godmode = 'warn',
    money = 'warn',
    vehicle_spawn = 'warn',
    weapon_spawn = 'warn',
    weapon_blacklist = 'warn',
    speedhack = 'warn',
    gravity = 'warn',
    spam = 'warn',
    vision = 'warn',
    other = 'warn'
}
Config.PrisonMinutes = 30
Config.PrisonJailCoords = { x = 1690.5, y = 2565.8, z = 45.6 }
Config.PrisonReleaseCoords = { x = 1848.5, y = 2586.0, z = 45.7 }
Config.PrisonRadius = 90.0
