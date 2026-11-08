Config = {}

-- Nombre minimal de policiers en service pour déclencher un braquage
Config.RequiredCops = {
    ATM = 1,
    Fleeca = 2,
    CentralBank = 4
}

-- Cooldown en secondes (temps d'attente entre deux braquages)
Config.Cooldowns = {
    ATM = 300,        -- 5 minutes
    Fleeca = 1800,     -- 30 minutes
    CentralBank = 3600 -- 60 minutes
}

-- Récompenses en argent sale ou liquide
Config.Rewards = {
    ATM = { min = 1500, max = 5000 },
    Fleeca = { min = 25000, max = 65000 },
    CentralBank = { min = 120000, max = 350000 }
}

-- Banques configurées
Config.Banks = {
    {
        id = 'fleeca_legion',
        name = 'Fleeca Bank - Legion Square',
        type = 'Fleeca',
        coords = vector3(147.049, -1044.944, 29.367),
        vaultCoords = vector3(148.65, -1046.2, 29.37),
        timeToRob = 25, -- secondes
        doorModel = `v_ilev_bk_vaultdoor`
    },
    {
        id = 'fleeca_vinewood',
        name = 'Fleeca Bank - Vinewood Boulevard',
        type = 'Fleeca',
        coords = vector3(311.53, -284.45, 54.16),
        vaultCoords = vector3(314.15, -282.88, 54.16),
        timeToRob = 25
    },
    {
        id = 'fleeca_delperro',
        name = 'Fleeca Bank - Del Perro Boulevard',
        type = 'Fleeca',
        coords = vector3(-1212.98, -330.84, 37.78),
        vaultCoords = vector3(-1209.68, -332.95, 37.78),
        timeToRob = 25
    },
    {
        id = 'pacific_standard',
        name = 'Pacific Standard - Banque Centrale',
        type = 'CentralBank',
        coords = vector3(232.86, 216.94, 106.28),
        vaultCoords = vector3(255.45, 222.85, 101.68),
        timeToRob = 45
    }
}

-- Modèles d'ATM ciblables
Config.ATMModels = {
    `prop_atm_01`,
    `prop_atm_02`,
    `prop_atm_03`,
    `prop_fleeca_atm`
}
