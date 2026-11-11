local DISABLE_POLICE = true

-- Densités GTA : 0.0 = aucun spawn ambiant, 1.0 = densité normale.
-- Réduction marquée des PNJ et de la circulation sans vider totalement la ville.
local PED_DENSITY = 0.35
local SCENARIO_PED_DENSITY = 0.35
local VEHICLE_DENSITY = 0.25
local PARKED_VEHICLE_DENSITY = 0.40

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

        -- Ces natives doivent être réappliquées chaque frame.
        SetPedDensityMultiplierThisFrame(PED_DENSITY)
        SetScenarioPedDensityMultiplierThisFrame(SCENARIO_PED_DENSITY, SCENARIO_PED_DENSITY)
        SetVehicleDensityMultiplierThisFrame(VEHICLE_DENSITY)
        SetRandomVehicleDensityMultiplierThisFrame(VEHICLE_DENSITY)
        SetParkedVehicleDensityMultiplierThisFrame(PARKED_VEHICLE_DENSITY)
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
