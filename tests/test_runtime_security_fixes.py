from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class RuntimeSecurityFixTests(unittest.TestCase):
    def test_fuel_purchase_does_not_accept_client_fuel_fallback(self):
        server = read("resources/[FUNCTION]/rp_fuel/server/main.lua")
        client = read("resources/[FUNCTION]/rp_fuel/client/main.lua")

        self.assertIn("function(rawNetId, rawLitres, payment)", server)
        self.assertNotIn("rawCurrentFuel", server)
        self.assertIn("local currentFuel = vehicleFuel[netId]", server)
        self.assertIn("vehicleFuel[netId] = currentFuel", server)
        self.assertIn("currentFuel < 0 or currentFuel > 100", server)
        self.assertIn("GetAllVehicles()", server)
        self.assertIn("initializeVehicleFuel(vehicle, true)", server)
        self.assertIn("cancelRefuel(netId, pending, 'le véhicule a été supprimé')", server)
        self.assertNotIn("Entity(vehicle).state:set('rpFuel'", client)
        self.assertIn("TriggerServerEvent('rp_fuel:server:purchase', currentNetId, litres, payment)", client)

    def test_tire_reward_requires_a_server_timed_session_and_revalidation(self):
        server = read("resources/[FUNCTION]/rp_vehicle_loot/server/main.lua")
        client = read("resources/[FUNCTION]/rp_vehicle_loot/client/main.lua")

        self.assertIn("rp_vehicle_loot:server:startTire", server)
        self.assertIn("rp_vehicle_loot:server:completeTire", server)
        self.assertIn("rp_vehicle_loot:server:cancelTire", server)
        self.assertIn("elapsed < TIRE_ACTION_DURATION_MS", server)
        self.assertIn("elapsed > TIRE_ACTION_TIMEOUT_MS", server)
        self.assertIn("player.charId ~= pending.charId", server)
        self.assertIn("GetVehiclePedIsIn(ped, false) ~= 0", server)
        self.assertIn("GetEntitySpeed(vehicle) > 0.5", server)
        self.assertIn("pending.vehicleStartCoords", server)
        self.assertIn("GetPlayerInventory(src)", server)
        self.assertIn("item.name == 'repairkit'", server)
        self.assertEqual(server.count("if not playerHasRepairKit(src) then"), 2)
        self.assertNotIn("IsPedArmed", client)
        self.assertIn("rp_vehicle_loot:server:startTire", client)
        self.assertIn("rp_vehicle_loot:server:completeTire", client)
        self.assertIn("rp_vehicle_loot:server:cancelTire", client)

    def test_textui_is_hidden_only_by_an_explicit_hide_message(self):
        ui = read("resources/[FUNCTION]/rp_ui/html/js/app.js")

        self.assertNotIn("textUiHideTimer", ui)
        self.assertNotIn("setTimeout(hideTextUI", ui)
        self.assertIn("data.action === 'showTextUI'", ui)
        self.assertIn("data.action === 'hideTextUI'", ui)


if __name__ == "__main__":
    unittest.main(verbosity=2)
