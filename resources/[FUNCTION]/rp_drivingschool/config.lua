Config = {}

Config.InteractionDistance = 2.0
Config.ServerDistance = 5.0
Config.PassMark = 4
Config.TheoryCooldown = 5000
Config.ExamTimeout = 15 * 60
Config.CheckpointRadius = 18.0
Config.School = {
    coords = vector3(239.0, -1379.0, 33.7),
    blip = { sprite = 498, colour = 3, scale = 0.8, label = 'Auto-école' }
}

-- Les points pratiques et véhicules sont modifiables ici.
Config.Categories = {
    moto = {
        label = 'Permis moto', price = 1200, model = 'bati',
        spawn = vector4(252.0, -1372.0, 30.5, 140.0),
        checkpoints = {
            vector3(280.0, -1280.0, 29.5), vector3(410.0, -1100.0, 29.4),
            vector3(620.0, -950.0, 22.0), vector3(239.0, -1379.0, 33.7)
        },
        questions = {
            { q = 'À un feu rouge, que devez-vous faire ?', a = {'Accélérer', 'Vous arrêter', 'Klaxonner'}, correct = 2 },
            { q = 'Avant de changer de voie, vous devez :', a = {'Contrôler les angles morts', 'Freiner brusquement', 'Accélérer'}, correct = 1 },
            { q = 'Sur chaussée mouillée, la distance de freinage :', a = {'Diminue', 'Ne change pas', 'Augmente'}, correct = 3 },
            { q = 'Le casque homologué est-il obligatoire ?', a = {'Oui', 'Non', 'Seulement la nuit'}, correct = 1 },
            { q = 'À l’approche d’un passage piéton occupé :', a = {'Vous passez', 'Vous cédez le passage', 'Vous klaxonnez'}, correct = 2 }
        }
    },
    voiture = {
        label = 'Permis voiture', price = 1500, model = 'blista',
        spawn = vector4(252.0, -1372.0, 30.5, 140.0),
        checkpoints = {
            vector3(280.0, -1280.0, 29.5), vector3(410.0, -1100.0, 29.4),
            vector3(620.0, -950.0, 22.0), vector3(239.0, -1379.0, 33.7)
        },
        questions = {
            { q = 'À un feu rouge, que devez-vous faire ?', a = {'Accélérer', 'Vous arrêter', 'Klaxonner'}, correct = 2 },
            { q = 'Avant de dépasser, vous devez :', a = {'Vérifier que la manœuvre est sûre', 'Coller le véhicule', 'Accélérer sans regarder'}, correct = 1 },
            { q = 'La ceinture de sécurité est-elle obligatoire ?', a = {'Oui', 'Non', 'Seulement sur autoroute'}, correct = 1 },
            { q = 'À un stop, vous devez :', a = {'Ralentir seulement', 'Marquer un arrêt complet', 'Passer si personne ne klaxonne'}, correct = 2 },
            { q = 'En agglomération, vous devez adapter votre vitesse :', a = {'Aux conditions et limitations', 'Uniquement à votre véhicule', 'Jamais'}, correct = 1 }
        }
    },
    avion = {
        label = 'Permis avion', price = 8500, model = 'dodo',
        spawn = vector4(-1272.0, -3380.0, 13.9, 329.0),
        checkpoints = {
            vector3(-1180.0, -3100.0, 80.0), vector3(-800.0, -2500.0, 180.0),
            vector3(-400.0, -1800.0, 220.0), vector3(-1272.0, -3380.0, 13.9)
        },
        questions = {
            { q = 'Avant le décollage, vous devez :', a = {'Vérifier l’appareil', 'Couper le moteur', 'Ignorer la piste'}, correct = 1 },
            { q = 'En vol, une montée excessive peut :', a = {'Faire décrocher l’appareil', 'Augmenter toujours la vitesse', 'Arrêter le vent'}, correct = 1 },
            { q = 'À l’atterrissage, l’approche doit être :', a = {'Contrôlée et stabilisée', 'La plus rapide possible', 'Sans alignement'}, correct = 1 },
            { q = 'La priorité en zone aéroportuaire est :', a = {'La sécurité des mouvements', 'La vitesse', 'Le confort'}, correct = 1 },
            { q = 'En cas de mauvaise visibilité, vous devez :', a = {'Poursuivre à tout prix', 'Adapter ou interrompre le vol', 'Voler plus bas en ville'}, correct = 2 }
        }
    },
    bateau = {
        label = 'Permis bateau', price = 4000, model = 'seashark',
        spawn = vector4(-802.0, -1503.0, 0.2, 110.0),
        checkpoints = {
            vector3(-650.0, -1700.0, 0.0), vector3(-350.0, -1900.0, 0.0),
            vector3(-100.0, -1650.0, 0.0), vector3(-802.0, -1503.0, 0.2)
        },
        questions = {
            { q = 'À proximité des baigneurs, vous devez :', a = {'Réduire l’allure', 'Accélérer', 'Passer au plus près'}, correct = 1 },
            { q = 'La vitesse doit être adaptée :', a = {'Aux conditions et à la zone', 'Uniquement au moteur', 'Jamais'}, correct = 1 },
            { q = 'Un gilet de sauvetage sert à :', a = {'Assurer la flottabilité', 'Augmenter la vitesse', 'Freiner le bateau'}, correct = 1 },
            { q = 'En cas de croisement, vous devez :', a = {'Respecter les règles de priorité', 'Fermer les yeux', 'Accélérer systématiquement'}, correct = 1 },
            { q = 'Avant le départ, vérifiez :', a = {'Sécurité et équipement', 'Uniquement la radio', 'Rien'}, correct = 1 }
        }
    },
    helicoptere = {
        label = 'Permis hélicoptère', price = 10000, model = 'maverick',
        spawn = vector4(-1272.0, -3380.0, 13.9, 329.0),
        checkpoints = {
            vector3(-1180.0, -3100.0, 100.0), vector3(-800.0, -2500.0, 180.0),
            vector3(-400.0, -1800.0, 140.0), vector3(-1272.0, -3380.0, 13.9)
        },
        questions = {
            { q = 'Avant le décollage, vérifiez :', a = {'Rotor et environnement', 'Uniquement la radio', 'Rien'}, correct = 1 },
            { q = 'Le stationnaire demande :', a = {'Des corrections fines', 'Une accélération maximale', 'De couper le moteur'}, correct = 1 },
            { q = 'En cas de vent fort, vous devez :', a = {'Adapter ou reporter le vol', 'Ignorer les rafales', 'Voler très bas'}, correct = 1 },
            { q = 'À l’approche d’une zone d’atterrissage :', a = {'Vérifier qu’elle est dégagée', 'Descendre sans regarder', 'Couper le rotor'}, correct = 1 },
            { q = 'La sécurité des personnes au sol est :', a = {'Prioritaire', 'Secondaire', 'Facultative'}, correct = 1 }
        }
    }
}
