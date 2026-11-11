local rescueRunning, rescueRevived = false, false
local rescueEntities, nextRescueRequestAt = {}, 0

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

local function loadModel(name)
    local hash = GetHashKey(name)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
    return HasModelLoaded(hash) and hash or nil
end

local function track(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        rescueEntities[#rescueEntities + 1] = entity
    end
    return entity
end

local function cleanup()
    local ped = PlayerPedId()
    if IsEntityAttached(ped) then DetachEntity(ped, true, true) end
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    for i = #rescueEntities, 1, -1 do
        local entity = rescueEntities[i]
        if entity and DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end
    rescueEntities = {}
    rescueRunning, rescueRevived = false, false
    TriggerServerEvent('rp_auto_rescue:server:finish')
end

local function getSpawn(origin)
    local d = Config.Pickup.spawnDistance
    for _, offset in ipairs({
        vector3(-d, -d, 0.0), vector3(d, -d, 0.0),
        vector3(-d, d, 0.0), vector3(d, d, 0.0)
    }) do
        local found, node, heading = GetClosestVehicleNodeWithHeading(
            origin.x + offset.x, origin.y + offset.y, origin.z + 20.0, 1, 3.0, 0
        )
        if found then return node, heading end
    end
    return vector3(origin.x - d, origin.y - d, origin.z), GetHeadingFromVector_2d(d, d)
end

local function createTeam(origin)
    local vehicleHash = loadModel(Config.RescueVehicle)
    local driverHash = loadModel(Config.DriverModel)
    local medicHash = loadModel(Config.MedicModel)
    local stretcherHash = loadModel(Config.StretcherModel)
    if not vehicleHash or not driverHash or not medicHash or not stretcherHash then return nil end

    local spawn, heading = getSpawn(origin)
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    local ambulance = track(CreateVehicle(vehicleHash, spawn.x, spawn.y, spawn.z, heading, true, true))
    if not ambulance or ambulance == 0 then return nil end
    SetEntityAsMissionEntity(ambulance, true, true)
    SetVehicleOnGroundProperly(ambulance)
    SetVehicleEngineOn(ambulance, true, true, false)
    SetVehicleSiren(ambulance, true)

    local driver = track(CreatePed(26, driverHash, spawn.x, spawn.y, spawn.z, heading, true, true))
    local medic = track(CreatePed(26, medicHash, spawn.x, spawn.y, spawn.z, heading, true, true))
    if not driver or driver == 0 or not medic or medic == 0 then return nil end
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetBlockingOfNonTemporaryEvents(medic, true)
    SetPedKeepTask(driver, true)
    SetPedKeepTask(medic, true)
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 0.0)
    TaskWarpPedIntoVehicle(driver, ambulance, -1)
    TaskWarpPedIntoVehicle(medic, ambulance, 0)
    SetModelAsNoLongerNeeded(vehicleHash)
    SetModelAsNoLongerNeeded(driverHash)
    SetModelAsNoLongerNeeded(medicHash)
    SetModelAsNoLongerNeeded(stretcherHash)
    return ambulance, driver, medic, stretcherHash
end

local function driveTo(driver, ambulance, destination)
    TaskVehicleDriveToCoordLongrange(driver, ambulance, destination.x, destination.y, destination.z,
        Config.Pickup.vehicleSpeed, 786603, Config.Pickup.arrivalDistance)
    local deadline = GetGameTimer() + Config.Pickup.maxTravelTime
    while GetGameTimer() < deadline do
        if not IsEntityDead(PlayerPedId()) then return false end
        if #(GetEntityCoords(ambulance) - destination) <= Config.Pickup.arrivalDistance then
            SetVehicleForwardSpeed(ambulance, 0.0)
            return true
        end
        Wait(500)
    end
    return false
end

local function createStretcher(medic, model, patient)
    local p = GetEntityCoords(patient)
    local bed = track(CreateObject(model, p.x, p.y, p.z - 1.0, true, true, false))
    if not bed or bed == 0 then return nil end
    SetEntityAsMissionEntity(bed, true, true)
    SetEntityCollision(bed, false, false)
    SetEntityHeading(bed, GetEntityHeading(patient))
    AttachEntityToEntity(patient, bed, 0, 0.0, 0.0, 0.68, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    AttachEntityToEntity(bed, medic, GetPedBoneIndex(medic, 11816),
        0.0, 0.85, -0.75, 0.0, 0.0, 90.0, false, false, false, false, 2, true)
    return bed
end

local function loadIntoAmbulance(medic, ambulance, bed)
    local rear = GetOffsetFromEntityInWorldCoords(ambulance, 0.0, -4.0, 0.0)
    SetVehicleDoorOpen(ambulance, 2, false, false)
    SetVehicleDoorOpen(ambulance, 3, false, false)
    TaskGoStraightToCoord(medic, rear.x, rear.y, rear.z, Config.Scene.medicWalkSpeed, -1,
        GetEntityHeading(ambulance), 0.2)
    local deadline = GetGameTimer() + Config.Scene.maxMedicWalkTime
    while GetGameTimer() < deadline do
        if not IsEntityDead(PlayerPedId()) then return false end
        if #(GetEntityCoords(medic) - rear) < 2.2 then break end
        Wait(250)
    end
    DetachEntity(bed, true, true)
    SetEntityCoords(bed, rear.x, rear.y, rear.z + 0.15, false, false, false, false)
    AttachEntityToEntity(bed, ambulance, 0, 0.0, -2.4, 0.25, 0.0, 0.0, 90.0,
        false, false, false, false, 2, true)
    Wait(1200)
    SetVehicleDoorShut(ambulance, 2, false)
    SetVehicleDoorShut(ambulance, 3, false)
    TaskWarpPedIntoVehicle(medic, ambulance, 0)
    return true
end

local function unloadAtHospital(medic, ambulance, bed)
    SetVehicleSiren(ambulance, false)
    SetVehicleDoorOpen(ambulance, 2, false, false)
    SetVehicleDoorOpen(ambulance, 3, false, false)
    TaskLeaveVehicle(medic, ambulance, 256)
    local deadline = GetGameTimer() + 7000
    while IsPedInAnyVehicle(medic, false) and GetGameTimer() < deadline do Wait(100) end
    if not IsEntityDead(PlayerPedId()) then return false end

    local h = Config.Hospital
    DetachEntity(bed, true, true)
    SetEntityCoords(bed, h.coords.x + 2.0, h.coords.y - 1.5, h.coords.z - 1.0, false, false, false, false)
    SetEntityHeading(bed, h.heading)
    PlaceObjectOnGroundProperly(bed)
    TaskGoToEntity(medic, bed, -1, 1.5, 1.0, 0, 0)
    Wait(2500)
    TaskStartScenarioInPlace(medic, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
    return true
end

local function revive()
    local h = Config.Hospital
    local ped = PlayerPedId()
    if IsEntityAttached(ped) then DetachEntity(ped, true, true) end
    rescueRevived = true
    NetworkResurrectLocalPlayer(h.coords.x + 2.0, h.coords.y - 1.5, h.coords.z, h.heading, true, false)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, h.coords.x + 2.0, h.coords.y - 1.5, h.coords.z, false, false, false, false)
    SetEntityHeading(ped, h.heading)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    notify('Vous avez été pris en charge. Vous pouvez reprendre votre activité.', 'success')
end

local function runRescue()
    local patient = PlayerPedId()
    local pickup = GetEntityCoords(patient)
    local ambulance, driver, medic, stretcherModel = createTeam(pickup)
    if not ambulance then
        notify('Impossible de faire venir les secours. Contactez un administrateur.', 'error')
        cleanup()
        return
    end

    notify('Les secours ont été alertés. Restez au sol, une ambulance arrive.', 'info')
    if not driveTo(driver, ambulance, pickup) then cleanup() return end

    TaskLeaveVehicle(medic, ambulance, 256)
    local deadline = GetGameTimer() + 6000
    while IsPedInAnyVehicle(medic, false) and GetGameTimer() < deadline do Wait(100) end
    if not IsEntityDead(PlayerPedId()) then cleanup() return end
    TaskGoToEntity(medic, patient, -1, 1.3, Config.Scene.medicWalkSpeed, 0, 0)
    Wait(3500)
    if not IsEntityDead(PlayerPedId()) then cleanup() return end
    TaskTurnPedToFaceEntity(medic, patient, 1000)
    Wait(700)

    local bed = createStretcher(medic, stretcherModel, patient)
    if not bed then cleanup() return end
    notify('Le secouriste vous installe sur la civière.', 'info')
    Wait(2500)
    if not loadIntoAmbulance(medic, ambulance, bed) then cleanup() return end
    notify('Vous êtes dans l’ambulance. Direction l’hôpital.', 'info')

    if not driveTo(driver, ambulance, Config.Hospital.coords) then
        if not IsEntityDead(PlayerPedId()) then cleanup() return end
        SetEntityCoords(ambulance, Config.Hospital.coords.x, Config.Hospital.coords.y,
            Config.Hospital.coords.z, false, false, false, false)
        SetEntityHeading(ambulance, Config.Hospital.heading)
    end
    if not unloadAtHospital(medic, ambulance, bed) then cleanup() return end

    notify(('Vous êtes arrivé à l’hôpital. Réanimation dans %d secondes.'):format(Config.RecoveryDelay), 'info')
    for remaining = Config.RecoveryDelay, 1, -1 do
        if not IsEntityDead(PlayerPedId()) then cleanup() return end
        Wait(1000)
        if remaining == 31 or remaining == 11 then
            notify(('Prise en charge médicale : encore %d secondes.'):format(remaining - 1), 'info')
        end
    end
    revive()
    Wait(Config.Scene.cleanupDelay)
    cleanup()
end

RegisterNetEvent('rp_auto_rescue:client:start', function()
    if rescueRunning then return end
    rescueRunning, rescueRevived = true, false
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, true, true)
    CreateThread(function()
        local ok, err = pcall(runRescue)
        if not ok then
            print(('[rp_auto_rescue] Scene error: %s'):format(tostring(err)))
            cleanup()
            notify('La scène de secours a été interrompue. Contactez un administrateur.', 'error')
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if not rescueRunning and IsEntityDead(ped) and GetGameTimer() >= nextRescueRequestAt then
            nextRescueRequestAt = GetGameTimer() + 15000
            TriggerServerEvent('rp_auto_rescue:server:request')
        elseif rescueRunning and not rescueRevived and not IsEntityDead(ped) then
            cleanup()
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    if IsEntityAttached(ped) then DetachEntity(ped, true, true) end
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityCollision(ped, true, true)
    for _, entity in ipairs(rescueEntities) do
        if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)
