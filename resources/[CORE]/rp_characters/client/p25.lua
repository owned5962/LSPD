                SetEntityCollision(ped, true, true)
                FreezeEntityPosition(ped, false)
            end)
        end
        recover('camera', function()
            if charCamera then
                RenderScriptCams(false, false, 0, true, true)
                DestroyCam(charCamera, false)
                charCamera = nil
            end
            RenderScriptCams(false, false, 0, true, true)
        end)
        recover('focus', ClearFocus)
        recover('nui-focus', function() SetNuiFocus(false, false) end)
        recover('player-control', function() SetPlayerControl(PlayerId(), true, 0) end)
        recover('radar', function() DisplayRadar(true) end)
        recover('loading-screen', function()
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
        end)
        recover('screen-fade', function()
            if IsScreenFadedOut() or IsScreenFadingOut() then
                DoScreenFadeIn(0)
            end
            DoScreenFadeIn(500)
        end)

        -- Keep fighting black screen for several seconds (other resources may fade out late).
        CreateThread(function()
            for attempt = 1, 12 do
                Wait(350)
                SetNuiFocus(false, false)
                DisplayRadar(true)
                SetPlayerControl(PlayerId(), true, 0)
                if IsScreenFadedOut() or IsScreenFadingOut() then
                    DoScreenFadeIn(0)
                    DoScreenFadeIn(250)
                end
                local p = PlayerPedId()
                if p and p ~= 0 and DoesEntityExist(p) then
                    SetEntityVisible(p, true, false)
                    ResetEntityAlpha(p)
                    FreezeEntityPosition(p, false)
                    SetEntityCollision(p, true, true)
                end
                if not IsScreenFadedOut() and not IsScreenFadingOut() and characterSessionReady then
                    -- still continue a few more passes in case something fades again
                    if attempt >= 6 then break end
                end
            end
        end)

        Wait(900)
        if not pipelineOk then
            print(('[rp_characters] Spawn pipeline recovered after an error: %s'):format(tostring(pipelineError)))
            TriggerEvent('chat:addMessage', {
