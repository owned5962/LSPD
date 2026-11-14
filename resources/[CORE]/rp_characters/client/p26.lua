                color = { 255, 170, 60 },
                multiline = true,
                args = { 'LOS SANTOS RP', 'Le chargement a rencontré une erreur. Votre affichage a été rétabli ; consultez la console F8.' }
            })
            return
        end

        print(('[rp_characters] Spawn pipeline completed; collisionLoaded=%s position=%.2f,%.2f,%.2f.')
            :format(tostring(collisionLoaded), spawnX, spawnY, spawnZ))
        TriggerServerEvent('rp_characters:server:requestTutorial')
    end)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- Mark the initialization pending before waiting for the network session so an
    -- early rp_core response cannot be overwritten by a later timeout thread.
    characterBootPending = true
    characterSessionReady = false
    SetPlayerControl(PlayerId(), false, 0)
    CreateThread(function()
        -- Re-assert the lock if spawnmanager or a reconnect flow restores player control.
        while not characterSessionReady do
            SetPlayerControl(PlayerId(), false, 0)
            local ped = PlayerPedId()
