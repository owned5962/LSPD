#!/usr/bin/env python3
"""
Comprehensive verification test for the FiveM RP server.
Checks:
  - server.cfg validity & ensures
  - database.sql schema & items table
  - 50 dedicated job resources inside resources/[jobs]/
  - Core roleplay modules (rp_core, rp_ui, rp_inventory, rp_interactions, rp_clothing, rp_characters, rp_economy, rp_jobs, rp_loadscreen, rp_tablet_admin)
"""
import os
import sys

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

def test_server_cfg():
    cfg_path = os.path.join(BASE_DIR, 'server.cfg')
    assert os.path.exists(cfg_path), "server.cfg not found!"
    with open(cfg_path) as f:
        content = f.read()
    
    assert "sv_maxclients" in content
    assert "ensure rp_core" in content
    assert "ensure rp_ui" in content
    assert "ensure rp_inventory" in content
    assert "ensure rp_interactions" in content
    assert "ensure rp_clothing" in content
    assert "ensure rp_tablet_admin" in content
    print("✓ server.cfg verified successfully.")

def test_database_schema():
    sql_path = os.path.join(BASE_DIR, 'database.sql')
    assert os.path.exists(sql_path), "database.sql not found!"
    with open(sql_path) as f:
        sql = f.read()

    tables = ['users', 'characters', 'bank_transactions', 'jobs', 'job_grades', 'admin_logs', 'items', 'billing', 'user_outfits']
    for table in tables:
        assert f"`{table}`" in sql or f"TABLE IF NOT EXISTS `{table}`" in sql, f"Table {table} missing!"
    print(f"✓ database.sql verified successfully with all {len(tables)} tables.")

def test_dedicated_jobs():
    jobs_dir = os.path.join(BASE_DIR, 'resources', '[jobs]')
    assert os.path.exists(jobs_dir), "resources/[jobs] directory missing!"
    job_folders = [d for d in os.listdir(jobs_dir) if d.startswith('job_')]
    assert len(job_folders) == 50, f"Expected 50 jobs, found {len(job_folders)}"
    
    for jf in job_folders:
        folder = os.path.join(jobs_dir, jf)
        assert os.path.exists(os.path.join(folder, 'fxmanifest.lua')), f"Missing manifest for {jf}"
        assert os.path.exists(os.path.join(folder, 'config.lua')), f"Missing config for {jf}"
        assert os.path.exists(os.path.join(folder, 'client', 'main.lua')), f"Missing client for {jf}"
        assert os.path.exists(os.path.join(folder, 'server', 'main.lua')), f"Missing server for {jf}"
    print(f"✓ All {len(job_folders)} dedicated job resources verified successfully.")

def test_core_resources():
    roleplay_dir = os.path.join(BASE_DIR, 'resources', '[roleplay]')
    expected_resources = [
        'rp_core',
        'rp_ui',
        'rp_inventory',
        'rp_interactions',
        'rp_clothing',
        'rp_characters',
        'rp_economy',
        'rp_jobs',
        'rp_loadscreen',
        'rp_tablet_admin'
    ]
    for res in expected_resources:
        res_dir = os.path.join(roleplay_dir, res)
        assert os.path.exists(res_dir), f"Missing core resource {res}"
        assert os.path.exists(os.path.join(res_dir, 'fxmanifest.lua')), f"Missing manifest for {res}"
    print(f"✓ All {len(expected_resources)} core roleplay modules verified successfully.")

if __name__ == '__main__':
    print("========================================")
    print("Running Full FiveM RP Verification Test")
    print("========================================")
    test_server_cfg()
    test_database_schema()
    test_dedicated_jobs()
    test_core_resources()
    print("========================================")
    print("ALL VERIFICATION CHECKS PASSED (100%)")
    print("========================================")
