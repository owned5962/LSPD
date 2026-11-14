    {
        title = 'TROUVER UN MÉTIER',
        lines = {
            'Rends-toi au Pôle Emploi ou utilise /jobcenter pour découvrir les métiers.',
            'Le serveur propose de nombreux métiers civils et services publics.',
            'Une fois ton métier choisi, rends-toi sur son lieu de travail pour découvrir les interactions disponibles.'
        }
    },
    {
        title = 'INTERAGIR AVEC LES AUTRES',
        lines = {
            'Approche-toi des autres citoyens pour échanger et créer des scènes RP.',
            'Certaines actions nécessitent d’être proche de la personne concernée.',
            'Respecte les scènes en cours et privilégie toujours le dialogue.'
        }
    },
    {
        title = 'LES RÈGLES ESSENTIELLES',
        lines = {
            'Pas de méta-gaming : ne te sers pas d’informations obtenues hors RP.',
            'Pas de power-gaming : laisse aux autres la possibilité de réagir.',
            'Pas de free-kill : toute action doit avoir un contexte RP cohérent.'
        }
    },
    {
        title = 'TU ES PRÊT !',
        lines = {
            'Tu connais maintenant les premières bases pour commencer ton aventure.',
            'Explore la ville, trouve ton activité et construis ton histoire.',
            'Bon jeu et bienvenue sur Los Santos Roleplay !'
        }
    }
}

local function DrawTutorialText(value, x, y, scale, r, g, b, centered)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 245, g or 247, b or 250, 255)
    SetTextCentre(centered == true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(value)
    EndTextCommandDisplayText(x, y)
end

local function FinishTutorial()
    tutorialActive = false
