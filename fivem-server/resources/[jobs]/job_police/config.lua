Config = {}

Config.Job = 'police'
Config.Label = 'Los Santos Police Department (LSPD)'
Config.Category = 'public_service'

-- Commissariat Central Mission Row
Config.DutyCoords = vector3(441.79, -982.07, 30.69)
Config.CloakroomCoords = vector3(452.61, -992.83, 30.69)
Config.ArmoryCoords = vector3(451.99, -980.12, 30.69)
Config.VehicleSpawner = vector3(438.42, -1018.3, 28.76)
Config.VehicleSpawnPoint = vector4(438.42, -1025.0, 28.76, 90.0)
Config.HelipadSpawn = vector4(449.2, -981.18, 43.69, 90.0)

Config.Vehicles = {
    { model = 'police', label = 'Vapid Stanier Cruiser LSPD', minGrade = 0 },
    { model = 'police2', label = 'Bravado Buffalo Cruiser LSPD', minGrade = 1 },
    { model = 'police3', label = 'Vapid Interceptor LSPD', minGrade = 2 },
    { model = 'police4', label = 'Cruiser Banalisé Unmarked', minGrade = 2 },
    { model = 'policeb', label = 'Moto de Police LSPD', minGrade = 1 },
    { model = 'policet', label = 'Fourgon de Transport LSPD', minGrade = 1 },
    { model = 'riot', label = 'Blindé Anti-Émeute SWAT / Riot', minGrade = 3 },
    { model = 'polmav', label = 'Hélicoptère Police Maverick', minGrade = 3 }
}

Config.Weapons = {
    { weapon = 'WEAPON_NIGHTSTICK', label = 'Matraque Police', price = 0 },
    { weapon = 'WEAPON_STUNGUN', label = 'Taser X26', price = 0 },
    { weapon = 'WEAPON_COMBATPISTOL', label = 'Pistolet de Combat 9mm', price = 0 },
    { weapon = 'WEAPON_PUMPSHOTGUN', label = 'Fusil à pompe Remington', price = 0 },
    { weapon = 'WEAPON_CARBINERIFLE', label = 'Carabine M4 LSPD', price = 0 },
    { weapon = 'WEAPON_FLASHLIGHT', label = 'Lampe Torche Tactique', price = 0 }
}
