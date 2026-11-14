        -- the second request hit the 5s cooldown and falsely timed out after
        -- the first request had already opened the creator.
        print('[rp_characters] Requesting account initialization through rp_core...')
        TriggerServerEvent('rp_core:server:requestPlayerDataSync')

        -- Never leave the loading screen covering the UI indefinitely.
        Wait(20000)
        if characterBootPending then
            ShowCharacterBootError('Le serveur ne répond pas au chargement du compte. Vérifiez oxmysql et la console serveur, puis reconnectez-vous.')
            print('[rp_characters] Character initialization timed out waiting for server response.')
        end
    end)
end)
