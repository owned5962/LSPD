from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_staff_tablets_have_distinct_color_themes_and_local_illustrations():
    themes = {
        "F9": ("resources/[FUNCTION]/rp_anticheat/html/css/style.css",
               "resources/[FUNCTION]/rp_anticheat/html/images/anticheat-hero.svg", "#f59e0b"),
        "F10": ("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css",
                "resources/[FUNCTION]/rp_tablet_admin/html/images/admin-hero.svg", "#ef4444"),
        "F11": ("resources/[FUNCTION]/rp_tablet_creator/html/style.css",
                "resources/[FUNCTION]/rp_tablet_creator/html/images/creator-hero.svg", "#a78bfa"),
        "F12": ("resources/[FUNCTION]/rp_ui/html/css/style.css",
                "resources/[FUNCTION]/rp_ui/html/images/diagnostics-hero.svg", "#38bdf8"),
    }
    for menu, (css_path, image_path, color) in themes.items():
        css = read(css_path)
        image = read(image_path)
        assert color in css, f"{menu} theme color is missing"
        assert "<svg" in image and "</svg>" in image, f"{menu} illustration is invalid"


def test_f9_statistics_are_rendered_as_data_driven_charts():
    html = read("resources/[FUNCTION]/rp_anticheat/html/index.html")
    ui = read("resources/[FUNCTION]/rp_anticheat/html/js/app.js")
    assert 'id="stats-category-chart"' in html
    assert 'id="stats-timeline-chart"' in html
    assert "function drawStatisticsChart" in ui
    assert "drawStatisticsChart('stats-category-chart', categories, 'bar')" in ui
    assert "drawStatisticsChart('stats-timeline-chart', timeline, 'line')" in ui
    assert "state.statistics.rows" in ui


def test_f10_live_overview_graph_uses_online_player_data():
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert 'id="admin-job-chart"' in html
    assert 'id="admin-live-players"' in html
    assert "function renderAdminOverview" in ui
    assert "drawAdminJobChart" in ui
    assert "renderAdminOverview();" in ui
    assert "onlinePlayers.forEach" in ui


def test_f11_statistics_page_uses_creator_players_modules_gangs_and_bank_data():
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    for chart in ("creator-job-chart", "creator-module-chart", "creator-bank-chart"):
        assert f'id="{chart}"' in html
    assert 'data-tab="statistics"' in html
    assert "function renderCreatorStatistics" in ui
    for source in ("creatorPlayers", "creatorModules", "creatorGangs", "creatorJobBankData"):
        assert source in ui
    assert "requestAnimationFrame(renderCreatorStatistics)" in ui


def test_f12_diagnostics_statistics_remain_graphical_and_document_real_limits():
    html = read("resources/[FUNCTION]/rp_ui/html/index.html")
    ui = read("resources/[FUNCTION]/rp_ui/html/js/app.js")
    assert 'id="diag-registration-chart"' in html
    assert 'id="diag-frame-chart"' in html
    assert 'id="diag-jobs-chart"' in html
    assert "drawLineChart('diag-registration-chart'" in ui
    assert "drawLineChart('diag-frame-chart'" in ui
    assert "renderServerDiagnostics" in ui
    assert "GetFrameTime()" in read("resources/[FUNCTION]/rp_ui/client/main.lua")


def test_f10_inline_buttons_reference_existing_functions():
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    handlers = set(re.findall(r'onclick="([A-Za-z_$][\\w$]*)\\s*\\(', html))
    for handler in handlers:
        assert re.search(r"(?:function\\s+" + re.escape(handler) + r"\\s*\\(|(?:const|let|var)\\s+" + re.escape(handler) + r"\\s*=)", ui), handler


def test_f11_statistics_tab_does_not_replace_existing_creator_controls():
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    for control in ("creator-save-server", "creator-save-fuel", "creator-save-identity",
                    "creator-save-balances", "creator-save-job", "creator-save-access",
                    "creator-bank-save", "creator-weapon-save", "create-job", "create-gang"):
        assert f'id="{control}"' in html
        assert control in ui
