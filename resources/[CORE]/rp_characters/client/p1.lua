local isCreating = false
local charCamera = nil
local characterBootPending = false
local characterSessionReady = false
local creationSubmissionPending = false
local selectWatchdogToken = 0

local function ForceScreenVisible()
    pcall(ShutdownLoadingScreen)
    pcall(ShutdownLoadingScreenNui)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCharacterSelection' })
    SendNUIMessage({ action = 'closeRegistration' })
    if charCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    ClearFocus()
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end
    DoScreenFadeIn(400)
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
    end
    DisplayRadar(true)
end

local function FinishCharacterBoot()
    characterBootPending = false
    ForceScreenVisible()
end

local function ShowCharacterBootError(message)
    characterBootPending = false
    characterSessionReady = false
    ForceScreenVisible()
    -- Leave the player controllable so they are not stuck on a black frame.
    SetPlayerControl(PlayerId(), true, 0)
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
    end
    TriggerEvent('chat:addMessage', {
        color = { 255, 90, 90 },
        multiline = true,
        args = { 'LOS SANTOS RP', message or 'Le chargement du personnage a échoué. Consultez la console serveur (F8) et reconnectez-vous.' }
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
