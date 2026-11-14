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
            if IsScreenFadedOut() or not IsScreenFadingIn() then
                DoScreenFadeIn(1000)
            end
        end)

        Wait(1200)
        if not pipelineOk then
            print(('[rp_characters] Spawn pipeline recovered after an error: %s'):format(tostring(pipelineError)))
            TriggerEvent('chat:addMessage', {
