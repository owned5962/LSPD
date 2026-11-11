from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FUEL = ROOT / "resources/[FUNCTION]/rp_fuel"


def test_fuel_resource_loads_shared_station_configuration():
    manifest = (FUEL / "fxmanifest.lua").read_text(encoding="utf-8")
    config = (FUEL / "shared/config.lua").read_text(encoding="utf-8")
    assert "shared/config.lua" in manifest
    assert "PricePerLitre = 6" in config
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
    assert "nearestPump(coords)" in client
    assert "pumpDistance <= 2.0" in client
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
