from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "resources/[FUNCTION]/rp_vehicle_rental"


def test_rental_clerks_are_configured_outside_and_in_front_of_the_buildings():
    config = (RESOURCE / "config.lua").read_text(encoding="utf-8")
    client = (RESOURCE / "client/main.lua").read_text(encoding="utf-8")

    assert "Config.InteractionDistance = 1.0" in config
    for coordinate in (
        "vector4(-1035.45, -2741.10, 20.1, 330.0)",
        "vector4(435.09, -630.25, 28.5, 220.0)",
        "vector4(294.27, -582.96, 43.2, 70.0)",
        "vector4(-266.40, -960.88, 31.2, 205.0)",
    ):
        assert coordinate in config
    assert "GetGroundZFor_3dCoord(p.x, p.y, p.z + 3.0, false)" in client
    assert "CreatePed(4, hash, p.x, p.y, spawnZ, p.w, false, true)" in client
    assert "p.z - 1.0" not in client


def test_rental_menu_open_uses_matching_client_and_server_location_checks():
    client = (RESOURCE / "client/main.lua").read_text(encoding="utf-8")
    server = (RESOURCE / "server/main.lua").read_text(encoding="utf-8")

    assert "tabletOpening = true" in client
    assert "rp_vehicle_rental:client:openDenied" in client
    assert "SetTimeout(6000" in client
    assert "TriggerServerEvent('rp_vehicle_rental:server:openTablet', nearestKey)" in client
    assert "horizontalDistance <= 1.5 and verticalDistance <= 2.0" in server
    assert "actualLocation ~= locationKey" in server
    assert "rp_vehicle_rental:client:openDenied" in server
    assert "currentTabletLocation = locationKey" in client
    assert "currentTabletRenewal" in client
    assert " > 1.0 then" in client


def test_rental_nui_callbacks_match_server_rent_and_renew_events():
    client = (RESOURCE / "client/main.lua").read_text(encoding="utf-8")
    ui = (RESOURCE / "html/js/app.js").read_text(encoding="utf-8")
    server = (RESOURCE / "server/main.lua").read_text(encoding="utf-8")

    assert "RegisterNUICallback('rent'" in client
    assert "RegisterNUICallback('renew'" in client
    assert "RegisterNetEvent('rp_vehicle_rental:server:rent'" in server
    assert "RegisterNetEvent('rp_vehicle_rental:server:renew'" in server
    assert "post('rent', { location: locationKey, model: selectedModel, minutes: minutes })" in ui
    assert "post('renew', { minutes: minutes })" in ui
    assert "RegisterNetEvent('rp_vehicle_rental:client:openTablet'" in client
    assert "data.action === 'open'" in ui


if __name__ == "__main__":
    test_rental_clerks_are_configured_outside_and_in_front_of_the_buildings()
    test_rental_menu_open_uses_matching_client_and_server_location_checks()
    test_rental_nui_callbacks_match_server_rent_and_renew_events()
    print("Rental front desk workflow checks passed.")
