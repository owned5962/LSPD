Config = {}

Config.MaxWeight = 30.0 -- 30 kg max capacity
Config.OpenKey = 289 -- F2 key
Config.CloseKey = 27 -- ESC

Config.DefaultItems = {
    ['bread'] = { label = 'Pain', weight = 0.5, type = 'food', hunger = 25 },
    ['water'] = { label = 'Bouteille d\'eau', weight = 0.5, type = 'drink', thirst = 30 },
    ['medikit'] = { label = 'Kit de secours', weight = 1.0, type = 'medical', heal = 100 },
    ['bandage'] = { label = 'Bandage', weight = 0.2, type = 'medical', heal = 25 },
    ['repairkit'] = { label = 'Kit de réparation', weight = 3.0, type = 'tool' },
    ['handcuffs'] = { label = 'Menottes de police', weight = 0.8, type = 'police' },
    ['phone'] = { label = 'Téléphone portable', weight = 0.2, type = 'item' },
    ['id_card'] = { label = 'Carte d\'identité', weight = 0.1, type = 'document' },
    ['driver_license'] = { label = 'Permis de conduire', weight = 0.1, type = 'document' },
    ['radio'] = { label = 'Talkie-walkie', weight = 0.5, type = 'tool' }
}
