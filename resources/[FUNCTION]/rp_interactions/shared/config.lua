Config = {}

-- Only expose actions that have a server-side implementation.
Config.JobActions = {
    ['police'] = {
        label = 'LSPD / Police',
        actions = {
            { id = 'cuff', label = 'Menotter / Démenotter', icon = 'fa-handcuffs' },
            { id = 'fine', label = 'Mettre une amende', icon = 'fa-receipt' },
            { id = 'impound', label = 'Mettre en fourrière', icon = 'fa-truck-ramp-box' }
        }
    },
    ['ambulance'] = {
        label = 'SAMU / Urgences',
        actions = {
            { id = 'heal', label = 'Soigner un patient', icon = 'fa-heart-pulse' },
            { id = 'revive', label = 'Réanimer un patient', icon = 'fa-kit-medical' },
            { id = 'billing', label = 'Facturer les soins', icon = 'fa-file-invoice-dollar' }
        }
    },
    ['mechanic'] = {
        label = 'Benny\'s / Mécano',
        actions = {
            { id = 'billing', label = 'Facturer les réparations', icon = 'fa-file-invoice-dollar' },
            { id = 'repair', label = 'Réparer le véhicule', icon = 'fa-wrench' },
            { id = 'clean', label = 'Nettoyer le véhicule', icon = 'fa-spray-can-sparkles' }
        }
    },
    ['towtruck'] = {
        label = 'Dépannage / Fourrière',
        actions = {
            { id = 'impound', label = 'Remorquer / mettre en fourrière', icon = 'fa-truck-ramp-box' }
        }
    },
    ['taxi'] = {
        label = 'Downtown Taxi',
        actions = {
            { id = 'billing', label = 'Facturer la course', icon = 'fa-receipt' }
        }
    }
}
