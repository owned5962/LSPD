local DISABLE_POLICE = true

-- Densités GTA : 0.0 = aucun spawn ambiant, 1.0 = densité normale.
-- Réduction légère des PNJ ; la circulation reste proche de la densité normale.
local PED_DENSITY = 0.75
local SCENARIO_PED_DENSITY = 0.75
local VEHICLE_DENSITY = 1.0
local PARKED_VEHICLE_DENSITY = 0.85

local function ApplyPoliceSettings()
    if not DISABLE_POLICE then return end
    local player = PlayerId()
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

-- Les réglages de dispatch sont persistants : inutile de les réappliquer
-- à chaque frame. On les réinitialise au démarrage et après chaque spawn.
ApplyPoliceSettings()
AddEventHandler('playerSpawned', ApplyPoliceSettings)

CreateThread(function()
    while true do
        -- Ces natives de densité sont temporaires et doivent être réappliquées chaque frame.
        SetPedDensityMultiplierThisFrame(PED_DENSITY)
        SetScenarioPedDensityMultiplierThisFrame(SCENARIO_PED_DENSITY, SCENARIO_PED_DENSITY)
        SetVehicleDensityMultiplierThisFrame(VEHICLE_DENSITY)
        SetRandomVehicleDensityMultiplierThisFrame(VEHICLE_DENSITY)
        SetParkedVehicleDensityMultiplierThisFrame(PARKED_VEHICLE_DENSITY)
        Wait(0)
    end
end)
