Config = {}

Config.PricePerTenMinutes = 100
Config.MinMinutes = 10
Config.MaxHours = 12
Config.ExpiryGraceSeconds = 60
Config.InteractionDistance = 3.5
Config.PedModel = 's_m_m_autoshop_02'

-- Les points correspondent aux choix de première apparition du créateur.
-- Le point hospital est également conservé car il est autorisé côté serveur.
Config.Locations = {
    airport = {
        label = 'Aéroport de Los Santos',
        ped = vector4(-1035.45, -2741.10, 20.1, 330.0),
        vehicle = vector4(-1032.4, -2727.6, 20.1, 330.0)
    },
    train = {
        label = 'Gare Centrale',
        ped = vector4(435.09, -630.25, 28.5, 220.0),
        vehicle = vector4(439.0, -627.8, 28.5, 220.0)
    },
    hospital = {
        label = 'Hôpital',
        ped = vector4(294.27, -582.96, 43.2, 70.0),
        vehicle = vector4(307.0, -583.0, 43.2, 70.0)
    },
    jobcenter = {
        label = 'Pôle Emploi',
        ped = vector4(-266.40, -960.88, 31.2, 205.0),
        vehicle = vector4(-260.5, -958.5, 31.2, 205.0)
    }
}

Config.Vehicles = {
    { model = 'blista', label = 'Dinka Blista', category = 'Citadine' },
    { model = 'asea', label = 'Declasse Asea', category = 'Berline' },
    { model = 'primo', label = 'Albany Primo', category = 'Berline' },
    { model = 'stanier', label = 'Vapid Stanier', category = 'Berline' },
    { model = 'faggio', label = 'Pegassi Faggio', category = 'Scooter' },
    { model = 'sanchez', label = 'Maibatsu Sanchez', category = 'Moto' }
}

-- Repères cartographiques des agences de location.
-- Sprite 225 : icône véhicule ; couleur 3 : bleu.
Config.MapBlip = {
    enabled = true,
    sprite = 225,
    display = 4,
    scale = 0.75,
    colour = 3,
    shortRange = true
}
