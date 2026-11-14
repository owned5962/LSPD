local isCreating = false
local charCamera = nil
local characterBootPending = false
local characterSessionReady = false
local creationSubmissionPending = false

local function FinishCharacterBoot()
    characterBootPending = false
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)
end

local function ShowCharacterBootError(message)
    FinishCharacterBoot()
    TriggerEvent('chat:addMessage', {
        color = { 255, 90, 90 },
        multiline = true,
        args = { 'LOS SANTOS RP', message or 'Le chargement du personnage a échoué. Consultez la console serveur.' }
    })
end

-- First-login onboarding. Controls are intentionally simple and do not depend on
-- external UI resources: E = next, Q = previous, Backspace = finish/skip.
local tutorialActive = false
local tutorialStep = 1
local tutorialPages = {
    {
        title = 'BIENVENUE À LOS SANTOS',
        lines = {
            'Bienvenue dans la ville ! Ton personnage commence une nouvelle histoire.',
            'Prends le temps de découvrir la ville et de rencontrer les autres habitants.',
            'Le plus important : joue ton personnage et laisse vivre les scènes RP.'
        }
    },
    {
        title = 'TON INVENTAIRE',
        lines = {
            'Appuie sur F2 pour ouvrir ton inventaire.',
            'Tu peux consulter tes objets et utiliser les objets autorisés.',
            'Tu peux donner ou déposer certains objets depuis cette interface.'
        }
    },
    {
        title = 'TON ARGENT',
        lines = {
            'Tu commences avec 2 500 $ en poche et 10 000 $ en banque.',
            'Appuie sur E devant un guichet bancaire ou un distributeur pour accéder à ton compte.',
            'Les principales banques sont indiquées sur ta carte.'
        }
    },
    {
        title = 'TROUVER UN MÉTIER',
        lines = {
            'Rends-toi au Pôle Emploi ou utilise /jobcenter pour découvrir les métiers.',
