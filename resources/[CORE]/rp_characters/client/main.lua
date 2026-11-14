local isCreating = false
local charCamera = nil
local characterBootPending = false
local characterSessionReady = false
local creationSubmissionPending = false

local function FinishCharacterBoot()
    characterBootPending = false
    -- Force the loadscreen NUI and native loading screen off, then ensure
    -- the game camera is not left in a fully faded-out state.
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    -- Second pass: some clients keep the NUI overlay until the next frame.
    CreateThread(function()
        Wait(0)
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
        if IsScreenFadedOut() or IsScreenFadingOut() then
            DoScreenFadeIn(400)
        end
    end)
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(500)
    end
end
