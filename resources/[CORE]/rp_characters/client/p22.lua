        coords = NormalizeClientSpawn(coords)

        local spawnX, spawnY, spawnZ = coords.x, coords.y, coords.z
        local spawnHeading = coords.heading
        local ped = PlayerPedId()
        local collisionLoaded = false
        local pipelineOk, pipelineError = xpcall(function()
            pcall(SendLoadingScreenMessage, json.encode({
                eventName = 'lssStage',
                stage = 'player',
                status = 'Finalisation de votre personnage...'
            }))

            -- Release every layer belonging to the creator before fading the
            -- world. Do not rely solely on the preceding closeMenu event.
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeRegistration' })
            SendNUIMessage({ action = 'closeCharacterSelection' })
            if charCamera then
                RenderScriptCams(false, true, 0, true, true)
                DestroyCam(charCamera, false)
                charCamera = nil
            else
                RenderScriptCams(false, true, 0, true, true)
            end
            ClearFocus()

            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
