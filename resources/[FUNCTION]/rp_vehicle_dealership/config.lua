Config = {}

Config.InteractionDistance = 2.0
Config.ServerInteractionDistance = 4.0
Config.PurchaseCooldown = 3000

-- Showroom Premium Deluxe Motorsport, Los Santos.
-- Plusieurs concessions peuvent être ajoutées ici sans modifier le système.
Config.Dealerships = {
    {
        id = 'pdm_los_santos',
        label = 'Premium Deluxe Motorsport',
        coords = vector3(-56.0, -1096.6, 26.4),
        spawn = vector4(-42.5, -1097.2, 26.4, 68.0),
        blip = { enabled = true, sprite = 225, colour = 5, scale = 0.85 }
    }
}

-- Modèles GTA V standards. Les prix sont débités sur le compte bancaire.
Config.Vehicles = {
    { model = 'blista', label = 'Dinka Blista', category = 'Citadine', price = 18000, image = 'compact' },
    { model = 'asea', label = 'Declasse Asea', category = 'Berline', price = 22000, image = 'sedan' },
    { model = 'primo', label = 'Albany Primo', category = 'Berline', price = 25000, image = 'sedan' },
    { model = 'stanier', label = 'Vapid Stanier', category = 'Berline', price = 32000, image = 'sedan' },
    { model = 'faggio', label = 'Pegassi Faggio', category = 'Scooter', price = 7500, image = 'motorcycle' },
    { model = 'sanchez', label = 'Maibatsu Sanchez', category = 'Moto', price = 14000, image = 'motorcycle' }
}
