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
    ['scrap_metal'] = { label = 'Ferraille', weight = 0.8, type = 'item', icon = 'fas fa-recycle' },
    ['rubber'] = { label = 'Caoutchouc usagé', weight = 0.5, type = 'item', icon = 'fas fa-circle' },
    ['copper_wire'] = { label = 'Fil de cuivre', weight = 0.3, type = 'item', icon = 'fas fa-bolt' },
    ['electronic_parts'] = { label = 'Composants électroniques', weight = 0.4, type = 'item', icon = 'fas fa-microchip' },
    ['car_battery'] = { label = 'Batterie automobile', weight = 4.0, type = 'item', icon = 'fas fa-car-battery' },

    -- Armes de corps à corps : objets d'inventaire distincts des armes à feu.
    ['weapon_pistol'] = { label = 'Pistolet standard', weight = 1.2, type = 'weapon', weapon = 'WEAPON_PISTOL', icon = 'fas fa-gun' },
    ['weapon_knife'] = { label = 'Couteau', weight = 0.4, type = 'weapon', weapon = 'WEAPON_KNIFE', icon = 'fas fa-knife' },
    ['weapon_nightstick'] = { label = 'Matraque', weight = 0.8, type = 'weapon', weapon = 'WEAPON_NIGHTSTICK', icon = 'fas fa-baton' },
    ['weapon_bat'] = { label = 'Batte de baseball', weight = 1.2, type = 'weapon', weapon = 'WEAPON_BAT', icon = 'fas fa-baseball-bat-ball' },
    ['weapon_crowbar'] = { label = 'Pied-de-biche', weight = 1.5, type = 'weapon', weapon = 'WEAPON_CROWBAR', icon = 'fas fa-toolbox' },
    ['weapon_hammer'] = { label = 'Marteau', weight = 1.0, type = 'weapon', weapon = 'WEAPON_HAMMER', icon = 'fas fa-hammer' },
    ['weapon_golfclub'] = { label = 'Club de golf', weight = 1.3, type = 'weapon', weapon = 'WEAPON_GOLFCLUB', icon = 'fas fa-golf-ball-tee' },
    ['weapon_knuckle'] = { label = 'Poing américain', weight = 0.3, type = 'weapon', weapon = 'WEAPON_KNUCKLE', icon = 'fas fa-hand-fist' },
    ['weapon_machete'] = { label = 'Machette', weight = 1.1, type = 'weapon', weapon = 'WEAPON_MACHETE', icon = 'fas fa-khanda' },
    ['weapon_flashlight'] = { label = 'Lampe torche', weight = 0.5, type = 'weapon', weapon = 'WEAPON_FLASHLIGHT', icon = 'fas fa-flashlight' },
    ['weapon_bottle'] = { label = 'Bouteille cassée', weight = 0.4, type = 'weapon', weapon = 'WEAPON_BOTTLE', icon = 'fas fa-wine-bottle' },
    ['weapon_dagger'] = { label = 'Dague antique', weight = 0.5, type = 'weapon', weapon = 'WEAPON_DAGGER', icon = 'fas fa-khanda' },
    ['weapon_hatchet'] = { label = 'Hachette', weight = 1.0, type = 'weapon', weapon = 'WEAPON_HATCHET', icon = 'fas fa-axe' },
    ['weapon_switchblade'] = { label = 'Couteau à cran d’arrêt', weight = 0.4, type = 'weapon', weapon = 'WEAPON_SWITCHBLADE', icon = 'fas fa-knife' },
    ['weapon_poolcue'] = { label = 'Queue de billard', weight = 1.2, type = 'weapon', weapon = 'WEAPON_POOLCUE', icon = 'fas fa-bowling-ball' },
    ['weapon_wrench'] = { label = 'Clé à molette', weight = 1.0, type = 'weapon', weapon = 'WEAPON_WRENCH', icon = 'fas fa-wrench' },
    ['weapon_battleaxe'] = { label = 'Hache de combat', weight = 1.8, type = 'weapon', weapon = 'WEAPON_BATTLEAXE', icon = 'fas fa-axe' },
    ['weapon_stone_hatchet'] = { label = 'Hachette en pierre', weight = 1.4, type = 'weapon', weapon = 'WEAPON_STONE_HATCHET', icon = 'fas fa-axe' },
    ['weapon_candycane'] = { label = 'Canne en sucre', weight = 0.4, type = 'weapon', weapon = 'WEAPON_CANDYCANE', icon = 'fas fa-candy-cane' },

    -- Arme à feu demandée pour le catalogue Ammu-Nation / inventaire.
    ['weapon_mp5'] = { label = 'MP5', weight = 3.2, type = 'weapon', weapon = 'WEAPON_SMG', icon = 'fas fa-gun' }
}
