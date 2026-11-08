Config = {}

Config.JobActions = {
    ['police'] = {
        label = 'LSPD / Police',
        actions = {
            { id = 'cuff', label = 'Menotter / Démenotter', icon = 'fa-handcuffs' },
            { id = 'search', label = 'Fouiller le citoyen', icon = 'fa-person-circle-question' },
            { id = 'escort', label = 'Escorter', icon = 'fa-person-walking' },
            { id = 'put_in_vehicle', label = 'Mettre dans le véhicule', icon = 'fa-car-side' },
            { id = 'out_the_vehicle', label = 'Sortir du véhicule', icon = 'fa-door-open' },
            { id = 'fine', label = 'Mettre une amende', icon = 'fa-receipt' }
        }
    },
    ['ambulance'] = {
        label = 'SAMU / Urgences',
        actions = {
            { id = 'revive', label = 'Réanimer le blessé', icon = 'fa-heart-pulse' },
            { id = 'heal', label = 'Soigner les blessures', icon = 'fa-kit-medical' },
            { id = 'billing', label = 'Facturer les soins', icon = 'fa-file-invoice-dollar' }
        }
    },
    ['mechanic'] = {
        label = 'Benny\'s / Mécano',
        actions = {
            { id = 'repair', label = 'Réparer le véhicule', icon = 'fa-wrench' },
            { id = 'clean', label = 'Nettoyer le véhicule', icon = 'fa-soap' },
            { id = 'impound', label = 'Mettre en fourrière', icon = 'fa-truck-pickup' },
            { id = 'billing', label = 'Facturer les réparations', icon = 'fa-file-invoice-dollar' }
        }
    },
    ['taxi'] = {
        label = 'Downtown Taxi',
        actions = {
            { id = 'taximeter', label = 'Démarrer le compteur', icon = 'fa-calculator' },
            { id = 'billing', label = 'Facturer la course', icon = 'fa-receipt' }
        }
    }
}
