from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ECONOMY = ROOT / "resources/[FUNCTION]/rp_economy"


def read(path):
    return (ECONOMY / path).read_text(encoding="utf-8")


def test_atm_and_bank_access_uses_registered_world_locations():
    server = read("server/main.lua")
    client = read("client/main.lua")
    assert "GetLocationsByType(locationType)" in server
    assert "getLocationsByType('bank')" in server
    assert "getLocationsByType('atm')" in server
    assert "rp_businesses:server:requestLocations" in client
    assert "GetNearbyATM(2.0)" in client
    assert "GetNearbyBank(3.0)" in client
    assert "OpenBankUI(false)" in client
    assert "OpenBankUI(true)" in client


def test_server_requires_character_bound_fingerprint_session():
    server = read("server/main.lua")
    assert "RegisterNetEvent('rp_economy:server:authenticate'" in server
    assert "authenticatedSessions[src]" in server
    assert "session.charId ~= player.charId" in server
    assert "GetGameTimer() > session.expiresAt" in server
    assert "requireAuthenticatedSession(src, true)" in server
    assert "requireAuthenticatedSession(src, false)" in server
    assert "RegisterNetEvent('rp_economy:server:logout'" in server


def test_deposit_updates_live_balances_before_releasing_core_lock():
    server = read("server/main.lua")
    start = server.index("RegisterNetEvent('rp_economy:server:deposit'")
    end = server.index("RegisterNetEvent('rp_economy:server:withdraw'", start)
    handler = server[start:end]
    assert "UPDATE characters SET cash = cash - ?, bank = bank + ?" in handler
    assert handler.index("player.cash, player.bank =") < handler.index("ReleaseCharacterLock")
    assert "Dépôt réussi" in handler


def test_withdraw_updates_live_balances_before_releasing_core_lock():
    server = read("server/main.lua")
    start = server.index("RegisterNetEvent('rp_economy:server:withdraw'")
    end = server.index("RegisterNetEvent('rp_economy:server:transfer'", start)
    handler = server[start:end]
    assert "UPDATE characters SET bank = bank - ?, cash = cash + ?" in handler
    assert handler.index("player.bank, player.cash =") < handler.index("ReleaseCharacterLock")
    assert "Retrait réussi" in handler


def test_transfer_updates_both_live_balances_before_releasing_core_lock():
    server = read("server/main.lua")
    start = server.index("RegisterNetEvent('rp_economy:server:transfer'")
    end = server.index("AddEventHandler('playerDropped'", start)
    handler = server[start:end]
    assert "UPDATE characters AS sender JOIN characters AS recipient" in handler
    assert handler.index("player.bank, target.bank =") < handler.index("ReleaseCharacterLock")
    assert "Virement de " in handler


def test_nui_has_biometric_gate_close_button_and_transaction_callbacks():
    client = read("client/main.lua")
    ui = read("html/js/app.js")
    html = read("html/index.html")
    assert "RegisterNUICallback('authenticate'" in client
    assert "TriggerServerEvent('rp_economy:server:authenticate')" in client
    assert "RegisterNUICallback('deposit'" in client
    assert "RegisterNUICallback('withdraw'" in client
    assert "post('authenticate')" in ui
    assert "runTransaction('deposit'" in ui
    assert "runTransaction('withdraw'" in ui
    assert 'id="fingerprint-btn"' in html
    assert 'id="close-bank"' in html
    assert "Escape" in ui
    assert "TriggerServerEvent('rp_economy:server:logout')" in client
    assert "Aucune réponse du lecteur" in ui
    assert "pendingInputs.set(name, inputs)" in ui
    assert "pendingInputs.get(name)" in ui


if __name__ == "__main__":
    checks = [
        test_atm_and_bank_access_uses_registered_world_locations,
        test_server_requires_character_bound_fingerprint_session,
        test_deposit_updates_live_balances_before_releasing_core_lock,
        test_withdraw_updates_live_balances_before_releasing_core_lock,
        test_transfer_updates_both_live_balances_before_releasing_core_lock,
        test_nui_has_biometric_gate_close_button_and_transaction_callbacks,
    ]
    for check in checks:
        check()
    print(f"Banking regression checks passed ({len(checks)}).")


def test_fingerprint_validates_location_before_rate_limit_and_prevents_duplicate_scans():
    server = read("server/main.lua")
    client = read("client/main.lua")
    start = server.index("RegisterNetEvent('rp_economy:server:authenticate'")
    end = server.index("RegisterNetEvent('rp_economy:server:logout'", start)
    handler = server[start:end]
    assert handler.index("IsNearBankOrATM(src, true)") < handler.index("CanPerformAction")
    assert "Patientez une seconde avant de réessayer." in handler
    assert "Lecteur temporairement indisponible" not in handler
    assert "local isAuthenticating = false" in client
    assert "if not isBankOpen or isAuthenticated or isAuthenticating then" in client
    assert "Le lecteur ne répond pas. Vérifiez votre position et réessayez." in client


def test_server_uses_real_terminal_proximity_and_atm_requires_registered_location():
    server = read("server/main.lua")
    assert "getLocationsByType('bank')" in server
    assert "getLocationsByType('atm')" in server
    assert "vector3(x, y, z)) <= 4.0" in server
    assert "vector3(x, y, z)) <= 4.0" in server


if __name__ == "__main__":
    test_fingerprint_validates_location_before_rate_limit_and_prevents_duplicate_scans()
    test_server_uses_real_terminal_proximity_and_atm_requires_registered_location()
    print("Fingerprint and terminal regression checks passed.")
