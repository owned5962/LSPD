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
