from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FUEL = ROOT / "resources/[FUNCTION]/rp_fuel"


def test_fuel_resource_loads_shared_station_configuration():
    manifest = (FUEL / "fxmanifest.lua").read_text(encoding="utf-8")
    config = (FUEL / "shared/config.lua").read_text(encoding="utf-8")
    assert "shared/config.lua" in manifest
    assert "PricePerLitre = 6" in config
    assert "ConsumptionMultiplier = 3.5" in config
    assert "rp_businesses" in manifest
    assert config.count("{ x = ") == 16


def test_fuel_purchase_is_server_authoritative_and_time_based():
    server = (FUEL / "server/main.lua").read_text(encoding="utf-8")
    client = (FUEL / "client/main.lua").read_text(encoding="utf-8")
    assert "rp_fuel:server:purchase" in server
    assert "AcquireCharacterLock" in server
    assert "UPDATE characters SET %s = %s - ?" in server
    assert "SetTimeout(durationMs" in server
    assert "fuelingStarted" in server and "fuelingStarted" in client
    assert "VehicleMovementTolerance" in server
    assert "refundPayment" in server
    assert "fuel_refund" in server
    assert "getFuelPrice()" in server
    assert "getFuelConsumptionMultiplier()" in server
    assert "rp_fuel:server:requestSettings" in server
    creator_server = (ROOT / "resources/[FUNCTION]/rp_tablet_creator/server/main.lua").read_text(encoding="utf-8")
    creator_client = (ROOT / "resources/[FUNCTION]/rp_tablet_creator/client/main.lua").read_text(encoding="utf-8")
    creator_html = (ROOT / "resources/[FUNCTION]/rp_tablet_creator/html/index.html").read_text(encoding="utf-8")
    creator_ui = (ROOT / "resources/[FUNCTION]/rp_tablet_creator/html/app.js").read_text(encoding="utf-8")
    assert "rp_tablet_creator:server:setFuelSettings" in creator_server
    assert "'fuel_price_per_litre'" in creator_server
    assert "'fuel_consumption_multiplier'" in creator_server
    assert "SetConvar('rp_fuel_price_per_litre'" in creator_server
    assert "RegisterNUICallback('setFuelSettings'" in creator_client
    assert 'id="creator-fuel-price"' in creator_html
    assert 'id="creator-fuel-consumption"' in creator_html
    assert "data-tab-panel" in creator_html and "creator-tab" in creator_html
    assert "activateCreatorTab('world')" in creator_ui
    assert "renderCreatorAdminData" in creator_ui


def test_fuel_tablet_displays_price_estimate_and_live_progress():
    html = (FUEL / "html/index.html").read_text(encoding="utf-8")
    js = (FUEL / "html/js/app.js").read_text(encoding="utf-8")
    css = (FUEL / "html/css/style.css").read_text(encoding="utf-8")
    assert 'id="unit-price"' in html
    assert 'id="total-price"' in html
    assert 'id="estimated-time"' in html
    assert 'id="progress-bar"' in html
    assert "requestAnimationFrame" in js
    assert "fuelingCancelled" in js
    assert ".progress-track" in css



def test_fuel_interaction_targets_individual_gas_pumps_with_e():
    client = (FUEL / "client/main.lua").read_text(encoding="utf-8")
    assert "GetClosestObjectOfType" in client
    assert "prop_gas_pump_1a" in client
    assert "prop_gas_pump_1d" in client
    assert "prop_vintage_pump" in client
    assert "nearestPump(playerCoords, 1.0)" in client
    assert "nearestPump(vehicleCoords, 1.0)" in client
    assert "currentPumpCoords = GetEntityCoords(pump)" in client
    assert "GetEntityCoords(vehicle) - currentPumpCoords) > 1.0" in client
    assert "Tablette fermée : vous avez quitté la pompe." in client
    assert "vehicleNearPump" in client
    assert "prop_gas_pump_old4" in client
    assert "IsControlJustReleased(0, 38)" in client
    assert "Ouvrir la tablette de la station" not in client
    assert "'[E] Faire le plein · '" in client

def test_fuel_refunds_are_supported_by_economy_transaction_log():
    economy = (ROOT / "resources/[FUNCTION]/rp_economy/server/main.lua").read_text(encoding="utf-8")
    assert "fuel_refund = true" in economy


if __name__ == "__main__":
    test_fuel_resource_loads_shared_station_configuration()
    test_fuel_purchase_is_server_authoritative_and_time_based()
    test_fuel_tablet_displays_price_estimate_and_live_progress()
    test_fuel_interaction_targets_individual_gas_pumps_with_e()
    test_fuel_refunds_are_supported_by_economy_transaction_log()
    print("Fuel system checks passed.")


def test_fuel_rejections_always_release_the_tablet_and_station_checks_have_a_fallback():
    server = (FUEL / "server/main.lua").read_text(encoding="utf-8")
    client = (FUEL / "client/main.lua").read_text(encoding="utf-8")
    config = (FUEL / "shared/config.lua").read_text(encoding="utf-8")

    assert "sendPurchaseFailure(src" in server
    purchase_block = server.split("RegisterNetEvent('rp_fuel:server:purchase'", 1)[1].split("CreateThread(function()", 1)[0]
    assert "notify(src," not in purchase_block
    assert "FuelConfig.Stations or {}" in server
    assert "GetLocationsByType('gas_station')" in server
    assert "nearestPump(playerCoords, 1.0)" in client
    assert "nearestPump(vehicleCoords, 1.0)" in client
    assert "RegisterNetEvent('rp_fuel:client:purchaseResult'" in client
    assert "isPurchasePending = false" in client
    assert config.count("{ x = ") == 16


if __name__ == "__main__":
    test_fuel_rejections_always_release_the_tablet_and_station_checks_have_a_fallback()
    print("Fuel failure recovery checks passed.")
