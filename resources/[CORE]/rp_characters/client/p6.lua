        print('[rp_characters] Requested freemode model is invalid; using the male fallback model.')
        model = fallbackModel
    end
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print('[rp_characters] No valid freemode model is available; character appearance cannot be applied.')
        return false
    end

    if GetEntityModel(PlayerPedId()) ~= model then
        local previousPed = PlayerPedId()
        local previousCoords = GetEntityCoords(previousPed)
        local previousHeading = GetEntityHeading(previousPed)
        local wasFrozen = IsEntityPositionFrozen(previousPed)

        RequestModel(model)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
        if not HasModelLoaded(model) then
            print('[rp_characters] Freemode model loading timed out.')
            return false
        end

        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)

        local pedDeadline = GetGameTimer() + 5000
        while GetEntityModel(PlayerPedId()) ~= model and GetGameTimer() < pedDeadline do
            Wait(0)
        end
