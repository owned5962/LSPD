from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ECONOMY = ROOT / "resources/[FUNCTION]/rp_economy"


def test_atm_server_validation_uses_fixed_map_locations():
    server = (ECONOMY / "server/main.lua").read_text(encoding="utf-8")
    assert "local ATM_POSITIONS = {" in server
    assert "pcall(GetAllObjects)" not in server
    assert "for _, atmCoords in ipairs(ATM_POSITIONS)" in server
    assert "if #(coords - atmCoords) <= 4.0 then return true end" in server


def test_deposit_updates_live_balances_before_releasing_core_lock():
    server = (ECONOMY / "server/main.lua").read_text(encoding="utf-8")
    start = server.index("RegisterNetEvent('rp_economy:server:deposit'")
    end = server.index("RegisterNetEvent('rp_economy:server:withdraw'", start)
    handler = server[start:end]
    assert "UPDATE characters SET cash = cash - ?, bank = bank + ?" in handler
    assert handler.index("player.cash, player.bank =") < handler.index("ReleaseCharacterLock")
    assert "Dépôt réussi" in handler


def test_withdraw_updates_live_balances_before_releasing_core_lock():
    server = (ECONOMY / "server/main.lua").read_text(encoding="utf-8")
    start = server.index("RegisterNetEvent('rp_economy:server:withdraw'")
    end = server.index("RegisterNetEvent('rp_economy:server:transfer'", start)
    handler = server[start:end]
    assert "UPDATE characters SET bank = bank - ?, cash = cash + ?" in handler
    assert handler.index("player.bank, player.cash =") < handler.index("ReleaseCharacterLock")
    assert "Retrait réussi" in handler



def test_transfer_updates_both_live_balances_before_releasing_core_lock():
    server = (ECONOMY / "server/main.lua").read_text(encoding="utf-8")
    start = server.index("RegisterNetEvent('rp_economy:server:transfer'")
    end = server.index("CreateThread(function()", start)
    handler = server[start:end]
    assert "UPDATE characters AS sender JOIN characters AS recipient" in handler
    assert handler.index("player.bank, target.bank =") < handler.index("ReleaseCharacterLock")
    assert "Virement de " in handler


def test_bank_nui_callbacks_reach_server_transactions():
    client = (ECONOMY / "client/main.lua").read_text(encoding="utf-8")
    ui = (ECONOMY / "html/js/app.js").read_text(encoding="utf-8")
    assert "RegisterNUICallback('deposit'" in client
    assert "TriggerServerEvent('rp_economy:server:deposit'" in client
    assert "RegisterNUICallback('withdraw'" in client
    assert "TriggerServerEvent('rp_economy:server:withdraw'" in client
    assert "https://rp_economy/deposit" in ui
    assert "https://rp_economy/withdraw" in ui


if __name__ == "__main__":
    checks = [
        test_atm_server_validation_uses_fixed_map_locations,
        test_deposit_updates_live_balances_before_releasing_core_lock,
        test_withdraw_updates_live_balances_before_releasing_core_lock,
        test_transfer_updates_both_live_balances_before_releasing_core_lock,
        test_bank_nui_callbacks_reach_server_transactions,
    ]
    for check in checks:
        check()
    print(f"Banking regression checks passed ({len(checks)}).")
