        print('[rp_characters] Default preview appearance failed; keeping the visible GTA ped.')
    end
    isCreating = true
    SetupCreatorCamera()
    if IsScreenFadedOut() then DoScreenFadeIn(500) end
    SendNUIMessage({ action = 'openRegistration', maxCharacters = maxCharacters or 3 })
end

local function UpdateCreatorCamera()
    if not charCamera then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    -- Keep the camera in front of the ped, centered on the face and upper body.
    local cameraCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.25, 0.9)
    SetCamCoord(charCamera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    PointCamAtEntity(charCamera, ped, 0.0, 0.0, 0.9, true)
end

function SetupCreatorCamera()
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, -1042.0, -2745.0, 21.3, false, false, false)
    SetEntityHeading(ped, 330.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)

    -- Load the preview location before creating the scripted camera.
