    AddTextComponentSubstringPlayerName(value)
    EndTextCommandDisplayText(x, y)
end

local function FinishTutorial()
    tutorialActive = false
    TriggerServerEvent('rp_characters:server:completeTutorial')
end

RegisterNetEvent('rp_characters:client:startTutorial', function()
    if tutorialActive then return end
    tutorialStep = 1
    tutorialActive = true

    CreateThread(function()
        while tutorialActive and IsPauseMenuActive() do Wait(250) end
        while tutorialActive do
            Wait(0)
            local page = tutorialPages[tutorialStep]
            if not page then
                FinishTutorial()
                break
            end

            DrawRect(0.5, 0.815, 0.68, 0.265, 8, 12, 20, 235)
            DrawRect(0.5, 0.69, 0.68, 0.012, 35, 145, 210, 255)
            DrawTutorialText('LOS SANTOS ROLEPLAY  •  GUIDE DU NOUVEAU', 0.5, 0.705, 0.30, 95, 185, 235, true)
            DrawTutorialText(page.title, 0.5, 0.745, 0.43, 255, 255, 255, true)

            for index, line in ipairs(page.lines) do
                DrawTutorialText(line, 0.19, 0.79 + ((index - 1) * 0.027), 0.30, 225, 230, 238, false)
            end

