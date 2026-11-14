local isCreating = false
local charCamera = nil
local characterBootPending = false
local characterSessionReady = false
local creationSubmissionPending = false

local function FinishCharacterBoot()
    characterBootPending = false
    pcall(ShutdownLoadingScreen)
    pcall(ShutdownLoadingScreenNui)
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end
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
