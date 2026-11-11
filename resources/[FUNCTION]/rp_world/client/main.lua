local DISABLE_POLICE = true
local PED_DENSITY = 0.78
local SCENARIO_PED_DENSITY = 0.78
local VEHICLE_DENSITY = 0.82

CreateThread(function()
    while true do
        local player = PlayerId()
        if DISABLE_POLICE then
            SetMaxWantedLevel(0)
            ClearPlayerWantedLevel(player)
            SetPlayerWantedLevel(player, 0, false)
            SetPlayerWantedLevelNow(player, false)
            SetPoliceIgnorePlayer(player, true)
            SetDispatchCopsForPlayer(player, false)
            SetCreateRandomCops(false)
            SetCreateRandomCopsNotOnScenarios(false)
            SetCreateRandomCopsOnScenarios(false)
            DistantCopCarSirens(false)
            CancelCurrentPoliceReport()
        end

        SetPedDensityMultiplierThisFrame(PED_DENSITY)
        SetScenarioPedDensityMultiplierThisFrame(SCENARIO_PED_DENSITY, SCENARIO_PED_DENSITY)
        SetVehicleDensityMultiplierThisFrame(VEHICLE_DENSITY)
        SetRandomVehicleDensityMultiplierThisFrame(VEHICLE_DENSITY)
        SetParkedVehicleDensityMultiplierThisFrame(VEHICLE_DENSITY)
        Wait(0)
    end
end)

AddEventHandler('playerSpawned', function()
    local player = PlayerId()
    SetMaxWantedLevel(0)
    SetPlayerWantedLevel(player, 0, false)
    SetPoliceIgnorePlayer(player, true)
    SetDispatchCopsForPlayer(player, false)
end)
