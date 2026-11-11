from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ECONOMY = ROOT / "resources/[FUNCTION]/rp_economy"


def read(path):
    return (ECONOMY / path).read_text(encoding="utf-8")


def test_atm_and_bank_access_uses_registered_world_locations():
    server = read("server/main.lua")
    client = read("client/main.lua")
    assert "GetLocationsByType('bank')" in server
    assert "GetLocationsByType('atm')" in server
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
    assert "requireAuthenticatedSession(src, 'deposit', true)" in server
    assert "requireAuthenticatedSession(src, 'withdraw', true)" in server
    assert "requireAuthenticatedSession(src, 'transfer', false)" in server
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
    assert "https://rp_economy/authenticate" in ui
    assert "https://rp_economy/deposit" in ui
    assert "https://rp_economy/withdraw" in ui
    assert 'id="fingerprint-btn"' in html
    assert 'id="close-bank"' in html
    assert "Escape" in ui


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
