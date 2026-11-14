end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function(characters, maxCharacters)
    -- Keep the player locked, but never hide the world behind the selector.
    -- The previous implementation made the ped fully transparent and did not
    -- create a preview camera, leaving the user with a black screen.
    FinishCharacterBoot()
    characterSessionReady = false
    isCreating = false
    SetPlayerControl(PlayerId(), false, 0)

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        print('[rp_characters] Character selector could not acquire a valid player ped.')
        ShowCharacterBootError('Impossible de préparer l’aperçu du personnage. Réessayez de vous connecter.')
        return
    end

    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, true)

    -- Display a visible freemode preview while the saved-character cards are open.
    -- The real saved skin is applied by the normal server spawn pipeline on selection.
    if not LoadFreemodeModel('m') then
