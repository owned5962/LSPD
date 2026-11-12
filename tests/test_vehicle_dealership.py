from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEALER = ROOT / "resources/[FUNCTION]/rp_vehicle_dealership"


def read(relative):
    return (DEALER / relative).read_text(encoding="utf-8")


def test_dealership_interaction_is_visible_and_server_reports_open_failures():
    config = read("config.lua")
    client = read("client/main.lua")
    server = read("server/main.lua")
    assert "Config.InteractionDistance = 1.0" in config
    assert "Config.ServerInteractionDistance = 1.5" in config
    assert "DrawMarker(2" in client
    assert "IsControlJustReleased(0, 38)" in client
    assert "Connexion au concessionnaire" in client
    assert "dealerOpeningId = nearest.id" in client
    assert "SetTimeout(5000" in client
    assert "rp_vehicle_dealership:client:openDenied" in client
    assert "Catalogue fermé : vous avez quitté la zone du concessionnaire." in client
    assert "Patientez avant de rouvrir le catalogue." in server
    assert "Vous devez être à moins de 1,5 mètre" in server


def test_dealership_catalogue_has_category_filters_and_vehicle_images():
    config = read("config.lua")
    html = read("html/index.html")
    ui = read("html/js/app.js")
    manifest = read("fxmanifest.lua")
    assert 'id="vehicle-categories"' in html
    assert "renderCategoryButtons" in ui
    assert "renderVehicleCards" in ui
    assert "images/' + (vehicle.image || 'compact') + '.svg'" in ui
    for image in ("compact.svg", "sedan.svg", "motorcycle.svg"):
        assert image in manifest
        assert (DEALER / "html/images" / image).is_file()
    assert "category = 'Citadine'" in config
    assert "category = 'Berline'" in config
    assert "category = 'Moto'" in config


if __name__ == "__main__":
    test_dealership_interaction_is_visible_and_server_reports_open_failures()
    test_dealership_catalogue_has_category_filters_and_vehicle_images()
    print("Vehicle dealership checks passed.")
