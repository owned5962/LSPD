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
            -- Aggressive anti black-screen: force immediate then animated fade-in.
            if IsScreenFadedOut() or IsScreenFadingOut() then
                DoScreenFadeIn(0)
            end
            DoScreenFadeIn(500)
        end)

        -- Second recovery pass after a short delay (handles late fade-out from other resources).
        CreateThread(function()
            for attempt = 1, 5 do
                Wait(400)
                if IsScreenFadedOut() or IsScreenFadingOut() then
                    DoScreenFadeIn(0)
                    DoScreenFadeIn(300)
                end
                SetNuiFocus(false, false)
                DisplayRadar(true)
                SetPlayerControl(PlayerId(), true, 0)
                local p = PlayerPedId()
                if p and p ~= 0 and DoesEntityExist(p) then
                    SetEntityVisible(p, true, false)
                    ResetEntityAlpha(p)
                    FreezeEntityPosition(p, false)
                end
                if not IsScreenFadedOut() and not IsScreenFadingOut() then
                    break
                end
            end
        end)

        Wait(1200)
        if not pipelineOk then
            print(('[rp_characters] Spawn pipeline recovered after an error: %s'):format(tostring(pipelineError)))
            TriggerEvent('chat:addMessage', {
