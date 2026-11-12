from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "resources" / "[FUNCTION]" / "rp_loadscreen"


class LoadscreenFeatureTests(unittest.TestCase):
    def read(self, relative):
        return (RESOURCE / relative).read_text(encoding="utf-8")

    def test_manifest_registers_server_feed_and_assets(self):
        manifest = self.read("fxmanifest.lua")
        self.assertIn("version '1.3.0'", manifest)
        self.assertIn("'server/main.lua'", manifest)
        self.assertIn("'html/images/los_santos_skyline.svg'", manifest)

    def test_four_life_objective_banners_are_present(self):
        html = self.read("html/index.html")
        self.assertEqual(html.count('class="objective-card '), 4)
        for phrase in (
            "Construire sa carrière",
            "Faire respecter la loi",
            "Prendre soin des autres",
            "Créer son histoire",
        ):
            self.assertIn(phrase, html)

    def test_creator_recruitment_and_versions_are_visible(self):
        html = self.read("html/index.html")
        self.assertIn('id="creator-name">GAutier', html)
        self.assertIn("RECRUTEMENT OUVERT", html)
        self.assertIn('id="current-version">1.3.0', html)
        self.assertIn('id="previous-version">1.2.0', html)

    def test_live_updates_are_received_and_rendered_safely(self):
        client = self.read("client/main.lua")
        server = self.read("server/main.lua")
        app = self.read("html/js/app.js")
        self.assertIn("rp_loadscreen:requestUpdates", client)
        self.assertIn("rp_loadscreen:receiveUpdates", client)
        self.assertIn("PerformHttpRequest", server)
        self.assertIn("nouveaut%C3%A9s.txt", server)
        self.assertIn("futur.txt", server)
        self.assertIn("ParseLines(updatesText, 6)", server)
        self.assertIn("ParseLines(futureText, 10)", server)
        self.assertIn("data.eventName === 'lssUpdates'", app)
        self.assertIn("data.future", app)
        self.assertIn("future-list", self.read("html/index.html"))
        self.assertIn("title.textContent", app)

    def test_server_feed_has_cache_and_per_player_cooldown(self):
        server = self.read("server/main.lua")
        self.assertIn("CACHE_DURATION_MS", server)
        self.assertIn("REQUEST_COOLDOWN_MS", server)
        self.assertIn("lastRequestByPlayer", server)


if __name__ == "__main__":
    unittest.main(verbosity=2)
