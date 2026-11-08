#!/usr/bin/env python3
"""
Comprehensive verification test for the FiveM RP server.
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
    assert "ensure rp_anticheat" in content
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
    jobs_dir = os.path.join(BASE_DIR, 'resources', '[JOB]')
    assert os.path.exists(jobs_dir), "resources/[JOB] directory missing!"
    job_folders = sorted(d for d in os.listdir(jobs_dir) if d.startswith('job_'))
    assert len(job_folders) == 50, f"Expected 50 jobs, found {len(job_folders)}"
    for job in job_folders:
        job_dir = os.path.join(jobs_dir, job)
        for relative in ('fxmanifest.lua', 'config.lua', 'client/main.lua', 'server/main.lua'):
            assert os.path.isfile(os.path.join(job_dir, relative)), f"{job} missing {relative}"
        with open(os.path.join(job_dir, 'config.lua'), encoding='utf-8') as config_file:
            config = config_file.read()
        assert f"Config.Job = '{job[4:]}'" in config, f"{job} Config.Job mismatch"
    print(f"✓ All {len(job_folders)} job resources have manifests, config, client and server files.")

def test_core_resources():
    roleplay_dir = os.path.join(BASE_DIR, 'resources', '[CORE]')
    function_dir = os.path.join(BASE_DIR, 'resources', '[FUNCTION]')
    expected_resources = [
        'rp_core',
        'rp_characters'
    ]
    for res in expected_resources:
        res_dir = os.path.join(roleplay_dir, res)
        assert os.path.exists(res_dir), f"Missing core resource {res}"
        assert os.path.exists(os.path.join(res_dir, 'fxmanifest.lua')), f"Missing manifest for {res}"
    expected_functions = ['rp_ui', 'rp_inventory', 'rp_interactions', 'rp_clothing', 'rp_economy', 'rp_jobs', 'rp_loadscreen', 'rp_tablet_admin', 'rp_anticheat']
    for res in expected_functions:
        res_dir = os.path.join(function_dir, res)
        assert os.path.exists(res_dir), f"Missing function resource {res}"
        assert os.path.exists(os.path.join(res_dir, 'fxmanifest.lua')), f"Missing manifest for {res}"
    print(f"✓ All {len(expected_resources) + len(expected_functions)} core/function resources verified successfully.")

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
