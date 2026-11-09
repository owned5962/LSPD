Config = {}

Config.MaxWeight = 30.0 -- 30 kg max capacity
Config.OpenKey = 289 -- F2 key
Config.CloseKey = 27 -- ESC

Config.DefaultItems = {
    -- Nourriture (Food)
    ['bread'] = { label = 'Pain de Campagne', weight = 0.3, type = 'food', hunger = 20, icon = 'fas fa-bread-slice' },
    ['burger_bleeder'] = { label = 'Burger Bleeder (Burger Shot)', weight = 0.4, type = 'food', hunger = 40, icon = 'fas fa-hamburger' },
    ['burger_heart_stopper'] = { label = 'Heart Stopper Triple Burger', weight = 0.6, type = 'food', hunger = 70, icon = 'fas fa-hamburger' },
    ['pizza_pepperoni'] = { label = 'Part de Pizza Pepperoni', weight = 0.4, type = 'food', hunger = 35, icon = 'fas fa-pizza-slice' },
    ['sandwich_poulet'] = { label = 'Sandwich Baguette Poulet Crudités', weight = 0.3, type = 'food', hunger = 30, icon = 'fas fa-bread-slice' },
    ['tacos_viande'] = { label = 'Tacos XL 3 Viandes', weight = 0.5, type = 'food', hunger = 50, icon = 'fas fa-hotdog' },
    ['hotdog'] = { label = 'Hot-Dog Moutarde Relish', weight = 0.3, type = 'food', hunger = 25, icon = 'fas fa-hotdog' },
    ['donut'] = { label = 'Donut Glacé au Sucre', weight = 0.15, type = 'food', hunger = 15, icon = 'fas fa-cookie' },
    ['cookie_chocolat'] = { label = 'Cookie Pépites de Chocolat', weight = 0.1, type = 'food', hunger = 10, icon = 'fas fa-cookie' },
    ['pomme'] = { label = 'Pomme Rouge Fraîche', weight = 0.2, type = 'food', hunger = 15, icon = 'fas fa-apple-alt' },
    ['salade_cesar'] = { label = 'Salade César Complète', weight = 0.35, type = 'food', hunger = 30, icon = 'fas fa-bowl-rice' },
    ['steak_frites'] = { label = 'Steak Frites Grillé', weight = 0.7, type = 'food', hunger = 60, icon = 'fas fa-drumstick-bite' },

    -- Boissons (Drinks)
    ['water'] = { label = 'Bouteille d\'Eau Minérale (50cl)', weight = 0.5, type = 'drink', thirst = 35, icon = 'fas fa-tint' },
    ['soda_ecola'] = { label = 'Canette eCola', weight = 0.33, type = 'drink', thirst = 30, icon = 'fas fa-wine-bottle' },
    ['soda_sprunk'] = { label = 'Canette Sprunk Citron-Lime', weight = 0.33, type = 'drink', thirst = 30, icon = 'fas fa-wine-bottle' },
    ['energy_drink'] = { label = 'Boisson Énergisante Junk Energy', weight = 0.25, type = 'drink', thirst = 25, stamina = 50, icon = 'fas fa-bolt' },
    ['coffee'] = { label = 'Café Espresso Chaud', weight = 0.2, type = 'drink', thirst = 20, icon = 'fas fa-coffee' },
    ['the_glace'] = { label = 'Thé Glacé Pêche', weight = 0.4, type = 'drink', thirst = 35, icon = 'fas fa-glass-whiskey' },
    ['jus_orange'] = { label = 'Jus d\'Orange Pressé Pur', weight = 0.3, type = 'drink', thirst = 30, icon = 'fas fa-glass-martini' },
    ['milkshake_vanille'] = { label = 'Milkshake Crémeux Vanille', weight = 0.4, type = 'drink', thirst = 25, hunger = 15, icon = 'fas fa-ice-cream' },
    ['biere_logger'] = { label = 'Bière Logger Light', weight = 0.5, type = 'drink', thirst = 20, alcohol = 15, icon = 'fas fa-beer' },
    ['biere_piswasser'] = { label = 'Bière Pisswasser Blonde', weight = 0.5, type = 'drink', thirst = 20, alcohol = 20, icon = 'fas fa-beer' },
    ['vin_rouge'] = { label = 'Bouteille de Vin Rouge Los Santos', weight = 0.75, type = 'drink', thirst = 15, alcohol = 30, icon = 'fas fa-wine-bottle' },
    ['whisky_richman'] = { label = 'Bouteille de Whisky Richman Gold', weight = 0.7, type = 'drink', thirst = 10, alcohol = 50, icon = 'fas fa-glass-whiskey' },

    -- Soins & Utilitaires
    ['medikit'] = { label = 'Kit de secours médical', weight = 1.0, type = 'medical', heal = 100, icon = 'fas fa-first-aid' },
    ['bandage'] = { label = 'Bandage compressif', weight = 0.2, type = 'medical', heal = 25, icon = 'fas fa-band-aid' },
    ['repairkit'] = { label = 'Kit d\'outils et réparation', weight = 3.0, type = 'tool', icon = 'fas fa-wrench' },
    ['handcuffs'] = { label = 'Paire de menottes tactiques', weight = 0.8, type = 'police', icon = 'fas fa-hands' },
    ['phone'] = { label = 'Smartphone tactile', weight = 0.2, type = 'item', icon = 'fas fa-mobile-alt' },
    ['id_card'] = { label = 'Carte nationale d\'identité', weight = 0.05, type = 'document', icon = 'fas fa-id-card' },
    ['driver_license'] = { label = 'Permis de conduire San Andreas', weight = 0.05, type = 'document', icon = 'fas fa-id-badge' },
    ['radio'] = { label = 'Radio Talkie-Walkie cryptée', weight = 0.5, type = 'tool', icon = 'fas fa-walkie-talkie' },

    -- Produits fictifs de contrebande (RP uniquement)
    ['weed_bag'] = { label = 'Sachet de cannabis', weight = 0.1, type = 'item', icon = 'fas fa-leaf' },
    ['coke_bag'] = { label = 'Sachet de poudre blanche', weight = 0.1, type = 'item', icon = 'fas fa-box' },
    ['meth_bag'] = { label = 'Cristaux de méthamphétamine', weight = 0.1, type = 'item', icon = 'fas fa-gem' },
    ['heroin_bag'] = { label = 'Poudre brune conditionnée', weight = 0.1, type = 'item', icon = 'fas fa-box' },
    ['crack_rock'] = { label = 'Caillou de crack', weight = 0.1, type = 'item', icon = 'fas fa-gem' },
    ['ecstasy_pill'] = { label = 'Comprimé festif', weight = 0.05, type = 'item', icon = 'fas fa-pills' },
    ['lsd_tab'] = { label = 'Buvar psychédélique', weight = 0.01, type = 'item', icon = 'fas fa-stamp' },
    ['opium_pack'] = { label = 'Paquet d’opium', weight = 0.1, type = 'item', icon = 'fas fa-box' },
    ['mushroom_pack'] = { label = 'Champignons hallucinogènes', weight = 0.1, type = 'item', icon = 'fas fa-seedling' },
    ['pill_pack'] = { label = 'Médicaments détournés', weight = 0.1, type = 'item', icon = 'fas fa-pills' },
}
