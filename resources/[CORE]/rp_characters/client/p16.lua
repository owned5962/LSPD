    RequestCollisionAtCoord(-1042.0, -2745.0, 21.3)
    local collisionDeadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionDeadline do
        RequestCollisionAtCoord(-1042.0, -2745.0, 21.3)
        Wait(50)
        ped = PlayerPedId()
    end

    if charCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    charCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not charCamera or charCamera == 0 then
        print('[rp_characters] Creator camera creation failed; falling back to gameplay camera.')
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        return
    end
    UpdateCreatorCamera()
    SetCamFov(charCamera, 38.0)
    SetCamActive(charCamera, true)
    RenderScriptCams(true, true, 500, true, true)
    print(('[rp_characters] Creator preview ready; ped=%s model=%s camera=%s')
        :format(tostring(ped), tostring(GetEntityModel(ped)), tostring(charCamera)))
end

local function CloseCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRegistration' })
