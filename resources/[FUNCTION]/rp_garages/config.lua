Config = {}

Config.InteractionDistance = 2.0
Config.ServerInteractionDistance = 5.0
Config.SpawnClearDistance = 3.0
Config.ActionCooldown = 1800
Config.SpawnTimeout = 45

-- Emplacements publics. Chaque garage possède une zone d'accès et une sortie dédiée.
Config.Garages = {
    {
        id = 'legion',
        label = 'Parking Legion Square',
        coords = vector3(215.8, -810.1, 30.7),
        spawn = vector4(229.7, -800.1, 30.6, 157.0),
        blip = { enabled = true, sprite = 357, colour = 3, scale = 0.72 }
    },
    {
        id = 'sandy',
        label = 'Garage Sandy Shores',
        coords = vector3(1737.2, 3710.6, 34.1),
        spawn = vector4(1725.4, 3711.8, 34.2, 20.0),
        blip = { enabled = true, sprite = 357, colour = 3, scale = 0.72 }
    },
    {
        id = 'paleto',
        label = 'Garage Paleto Bay',
        coords = vector3(105.2, 6613.8, 31.8),
        spawn = vector4(112.1, 6609.7, 31.9, 225.0),
        blip = { enabled = true, sprite = 357, colour = 3, scale = 0.72 }
    }
}

Config.Workshops = {
    { id = 'bennys', label = 'Bennys Motor Works', coords = vector3(117.4, -1818.7, 25.7) },
    { id = 'harmony', label = 'Los Santos Customs - Harmony', coords = vector3(1174.8, 2640.2, 37.8) }
}

Config.TuningCategories = {
    [11] = { id = 'engine', label = 'Moteur', basePrice = 1800, maxIndex = 10 },
    [12] = { id = 'brakes', label = 'Freins', basePrice = 1200, maxIndex = 10 },
    [13] = { id = 'transmission', label = 'Transmission', basePrice = 1500, maxIndex = 10 },
    [15] = { id = 'suspension', label = 'Suspension', basePrice = 900, maxIndex = 10 },
    [16] = { id = 'armor', label = 'Blindage', basePrice = 2500, maxIndex = 10 },
    [18] = { id = 'turbo', label = 'Turbo', basePrice = 3500, maxIndex = 1, toggle = true },
    [22] = { id = 'xenon', label = 'Phares xenon', basePrice = 900, maxIndex = 1, toggle = true }
}
