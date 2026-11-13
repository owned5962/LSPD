from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_job_accounts_are_persistent_and_seeded_from_the_job_catalog():
    service = read("resources/[FUNCTION]/rp_economy/server/jobbank.lua")
    assert "CREATE TABLE IF NOT EXISTS rp_job_bank_accounts" in service
    assert "CREATE TABLE IF NOT EXISTS rp_job_bank_transactions" in service
    assert "exports['rp_jobs']:GetAllJobs()" in service
    assert "INSERT IGNORE INTO rp_job_bank_accounts" in service
    assert "ORDER BY id DESC LIMIT 12" in service


def test_job_transactions_require_a_live_bank_session_and_server_permissions():
    service = read("resources/[FUNCTION]/rp_economy/server/jobbank.lua")
    economy = read("resources/[FUNCTION]/rp_economy/server/main.lua")
    assert "exports('IsBankSessionAuthenticated'" in economy
    assert "IsBankSessionAuthenticated(src) ~= true" in service
    assert "CanPerformAction(src, actionName, 1500)" in service
    assert "'economy:jobbank:' .. kind" in service
    assert "'jobtablet:jobbank:' .. kind" in service
    assert "account.allow_deposit" in service
    assert "account.allow_withdraw" in service
    assert "a.allow_deposit = 1" in service
    assert "a.allow_withdraw = 1" in service
    assert "AcquireCharacterLock" in service
    assert "ReleaseCharacterLock" in service


def test_job_transactions_move_cash_and_shared_balance_and_write_history():
    service = read("resources/[FUNCTION]/rp_economy/server/jobbank.lua")
    assert "SET c.cash = c.cash - ?, a.balance = a.balance + ?" in service
    assert "SET c.cash = c.cash + ?, a.balance = a.balance - ?" in service
    assert "c.cash >= ?" in service
    assert "a.balance >= ?" in service
    assert "INSERT INTO rp_job_bank_transactions" in service
    assert "balance_after" in service
    assert "rp_jobbank:server:deposit" in service
    assert "rp_jobbank:server:withdraw" in service


def test_creator_can_configure_each_job_and_review_auditable_history():
    server = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    assert "requestJobBankData" in server
    assert "saveJobBankPermissions" in server
    assert "creator:job_bank_permissions" in server
    assert "type(data.allowDeposit) ~= 'boolean'" in server
    assert "type(data.allowWithdraw) ~= 'boolean'" in server
    assert "UPDATE rp_job_bank_accounts SET allow_deposit = ?, allow_withdraw = ?" in server
    assert 'data-tab="bank"' in html and "Banque Job" in html
    assert 'id="creator-bank-allow-deposit"' in html
    assert 'id="creator-bank-allow-withdraw"' in html
    assert 'id="creator-bank-history"' in html
    assert "post('saveJobBankPermissions'" in ui
    assert "renderCreatorJobBank" in ui
    assert "RegisterNUICallback('saveJobBankPermissions'" in client


def test_fleeca_terminal_exposes_job_bank_only_after_biometric_authentication_at_a_branch():
    client = read("resources/[FUNCTION]/rp_economy/client/main.lua")
    html = read("resources/[FUNCTION]/rp_economy/html/index.html")
    ui = read("resources/[FUNCTION]/rp_economy/html/js/app.js")
    manifest = read("resources/[FUNCTION]/rp_economy/fxmanifest.lua")
    assert "if not openedAsATM then TriggerServerEvent('rp_jobbank:server:request') end" in client
    assert "RegisterNUICallback('jobDeposit'" in client
    assert "RegisterNUICallback('jobWithdraw'" in client
    assert "rp_jobbank:client:update" in client
    assert 'id="job-bank-section"' in html
    assert 'id="job-bank-history"' in html
    assert "renderJobBank(data.data)" in ui
    assert "post(type === 'deposit' ? 'jobDeposit' : 'jobWithdraw'" in ui
    assert "'server/jobbank.lua'" in manifest


if __name__ == "__main__":
    checks = [
        test_job_accounts_are_persistent_and_seeded_from_the_job_catalog,
        test_job_transactions_require_a_live_bank_session_and_server_permissions,
        test_job_transactions_move_cash_and_shared_balance_and_write_history,
        test_creator_can_configure_each_job_and_review_auditable_history,
        test_fleeca_terminal_exposes_job_bank_only_after_biometric_authentication_at_a_branch,
    ]
    for check in checks:
        check()
    print(f"Job bank regression checks passed ({len(checks)}).")
