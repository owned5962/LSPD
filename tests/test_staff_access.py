from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CREATOR = ROOT / "resources" / "[FUNCTION]" / "rp_tablet_creator"
UI = ROOT / "resources" / "[FUNCTION]" / "rp_ui"


class StaffAccessRegressionTests(unittest.TestCase):
    def read(self, base, relative):
        return (base / relative).read_text(encoding="utf-8")

    def test_creator_keeps_server_side_founder_and_creator_checks(self):
        server = self.read(CREATOR, "server/main.lua")
        client = self.read(CREATOR, "client/main.lua")
        self.assertIn("IsPlayerAceAllowed(src, 'rp_founder')", server)
        self.assertIn("player.group == 'fondateur'", server)
        self.assertIn("creatorAccessAllowed(src)", server)
        self.assertIn("RegisterCommand('creator', requestOpen, false)", client)
        self.assertIn("'F11'", client)
        self.assertIn("RegisterCommand('f11', requestOpen, false)", client)

    def test_accesscheck_reports_live_permission_state_and_identifiers_server_side(self):
        server = self.read(CREATOR, "server/main.lua")
        client = self.read(CREATOR, "client/main.lua")
        self.assertIn("rp_tablet_creator:server:requestAccessStatus", server)
        self.assertIn("GetPlayerIdentifiers(src)", server)
        self.assertIn("ace_rp_founder=", server)
        self.assertIn("RegisterCommand('accesscheck'", client)

    def test_f12_accepts_either_founder_ace_or_core_founder_group(self):
        server = self.read(UI, "server/main.lua")
        client = self.read(UI, "client/main.lua")
        self.assertIn("local function IsFounder(src)", server)
        self.assertIn("IsPlayerAceAllowed(src, 'rp_founder')", server)
        self.assertIn("player.group == 'fondateur'", server)
        self.assertIn("if not IsFounder(src) then", server)
        self.assertIn("RegisterKeyMapping('clientdiagnostics'", client)
        self.assertIn("RegisterCommand('diagnostics', ToggleDiagnostics, false)", client)
        self.assertIn("RegisterCommand('f12', ToggleDiagnostics, false)", client)

    def test_founder_code_is_server_verified_limited_and_session_scoped(self):
        server = self.read(CREATOR, "server/main.lua")
        client = self.read(CREATOR, "client/main.lua")
        self.assertIn("rp_tablet_creator:server:authenticateFounderCode", server)
        self.assertIn("GetConvar('rp_founder_access_code', '')", server)
        self.assertIn("attempts.count >= 5", server)
        self.assertIn("now + 600", server)
        self.assertIn("FounderCodeSessions[src] = true", server)
        self.assertIn("FounderCodeSessions[src] = nil", server)
        self.assertIn("exports('HasFounderCodeAccess'", server)
        self.assertIn("RegisterCommand('fondateur'", client)
        self.assertIn("TriggerServerEvent('rp_tablet_creator:server:authenticateFounderCode', code)", client)

    def test_f12_accepts_temporary_founder_code_session(self):
        server = self.read(UI, "server/main.lua")
        self.assertIn("exports['rp_tablet_creator']:HasFounderCodeAccess(src)", server)

    def test_f12_server_stats_remain_founder_only(self):
        server = self.read(UI, "server/main.lua")
        self.assertGreaterEqual(server.count("if not IsFounder(src) then return end"), 1)
        self.assertIn("rp_ui:client:diagnosticsStats", server)


if __name__ == "__main__":
    unittest.main(verbosity=2)
