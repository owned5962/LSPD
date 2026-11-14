            if ped and ped ~= 0 and DoesEntityExist(ped) then
                FreezeEntityPosition(ped, true)
            end
            Wait(500)
        end
    end)
    CreateThread(function()
        -- Wait for FiveM's network session before requesting account data.
        local deadline = GetGameTimer() + 30000
        while not NetworkIsSessionStarted() and GetGameTimer() < deadline do
            Wait(250)
        end
        if not NetworkIsSessionStarted() then
            ShowCharacterBootError('La session FiveM ne répond pas. Reconnectez-vous au serveur.')
            return
        end
        -- The creator/selector may already have opened while this thread was
        -- waiting for NetworkIsSessionStarted. Never restart its boot timer.
        if not characterBootPending then return end

        pcall(SendLoadingScreenMessage, json.encode({
            eventName = 'lssStage',
            stage = 'player',
            status = 'Chargement du compte et des personnages...'
        }))
        -- rp_core owns the initialization request and already retries session sync.
        -- A second direct request here would race the core account lookup:
