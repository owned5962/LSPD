Config = {}

-- Produits et points de récolte fictifs. Les délais et rendements sont réglables.
Config.Drugs = {
    weed_bag = { label = 'Cannabis', min = 2, max = 5, wait = 12000, cooldown = 45000, priceMin = 90, priceMax = 140, zone = vector3(2221.4, 5577.0, 53.8) },
    coke_bag = { label = 'Poudre blanche', min = 1, max = 3, wait = 18000, cooldown = 65000, priceMin = 350, priceMax = 520, zone = vector3(1391.2, 3605.3, 38.9) },
    meth_bag = { label = 'Cristaux', min = 1, max = 3, wait = 20000, cooldown = 70000, priceMin = 300, priceMax = 470, zone = vector3(2434.7, 4968.2, 42.3) },
    heroin_bag = { label = 'Poudre brune', min = 1, max = 3, wait = 22000, cooldown = 75000, priceMin = 280, priceMax = 440, zone = vector3(1525.0, 1710.6, 109.7) },
    crack_rock = { label = 'Crack', min = 1, max = 3, wait = 16000, cooldown = 60000, priceMin = 240, priceMax = 380, zone = vector3(1245.0, -2565.0, 42.7) },
    ecstasy_pill = { label = 'Comprimés', min = 2, max = 5, wait = 15000, cooldown = 55000, priceMin = 120, priceMax = 190, zone = vector3(-1172.0, -1572.0, 4.7) },
    lsd_tab = { label = 'Buvars', min = 2, max = 4, wait = 17000, cooldown = 60000, priceMin = 180, priceMax = 260, zone = vector3( -114.0, 6368.0, 31.5) },
    opium_pack = { label = 'Opium', min = 1, max = 3, wait = 20000, cooldown = 70000, priceMin = 220, priceMax = 340, zone = vector3( -1905.0, 2048.0, 140.0) },
    mushroom_pack = { label = 'Champignons', min = 2, max = 4, wait = 15000, cooldown = 55000, priceMin = 100, priceMax = 170, zone = vector3( -1550.0, 4430.0, 7.0) },
    pill_pack = { label = 'Médicaments détournés', min = 1, max = 3, wait = 16000, cooldown = 60000, priceMin = 160, priceMax = 250, zone = vector3( 356.0, -590.0, 28.8) }
}

Config.SellNPC = {
    coords = vector3( -46.5, -1757.8, 29.4 ),
    heading = 50.0,
    model = 'g_m_y_mexgoon_02',
    radius = 4.0
}

Config.Robbery = {
    cooldown = 90000,
    minMoney = 15,
    maxMoney = 450,
    successChance = 72,
    alertChance = 68,
    maxDistance = 2.8
}

Config.Dispatch = {
    expireSeconds = 180,
    blipSprite = 161,
    blipColour = 1,
    blipScale = 1.15
}
