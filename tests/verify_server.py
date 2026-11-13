#!/usr/bin/env python3
"""
Comprehensive verification test for the FiveM RP server.
"""
import os
import sys
import re

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

    tables = ['users', 'characters', 'bank_transactions', 'jobs', 'job_grades', 'admin_logs', 'items', 'billing', 'user_outfits', 'rp_driving_licenses']
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
        with open(os.path.join(job_dir, 'fxmanifest.lua'), encoding='utf-8') as manifest_file:
            manifest = manifest_file.read()
        assert "'rp_core'" in manifest, f"{job} does not declare rp_core dependency"
        assert "'rp_ui'" in manifest, f"{job} does not declare rp_ui dependency"
        with open(os.path.join(job_dir, 'config.lua'), encoding='utf-8') as config_file:
            config = config_file.read()
        assert f"Config.Job = '{job[4:]}'" in config, f"{job} Config.Job mismatch"

        with open(os.path.join(job_dir, 'server/main.lua'), encoding='utf-8') as server_file:
            server = server_file.read()
        assert "CanPerformAction(src," in server, f"{job} has no server-side action cooldown"
        assert f"player.job ~= '{job[4:]}'" in server, f"{job} does not validate the player's job"
        assert "type(status) ~= 'boolean'" in server, f"{job} does not validate duty state type"
        assert "isAt(Config.DutyCoords, src, 5.0)" in server, f"{job} does not validate duty location"
        assert "SetPlayerDuty(src, status, Config.Job)" in server, f"{job} does not sync duty to rp_core"
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
    function_resources = sorted(
        name for name in os.listdir(function_dir)
        if os.path.isdir(os.path.join(function_dir, name))
    )
    assert len(function_resources) == 23, (
        f"Expected 23 function resources, found {len(function_resources)}"
    )
    for res in function_resources:
        res_dir = os.path.join(function_dir, res)
        assert os.path.isfile(os.path.join(res_dir, 'fxmanifest.lua')), f"Missing manifest for {res}"
    print(f"✓ All {len(expected_resources) + len(function_resources)} core/function resources verified successfully.")


def test_all_resources_are_started_by_resource_name():
    resources_dir = os.path.join(BASE_DIR, 'resources')
    with open(os.path.join(BASE_DIR, 'server.cfg'), encoding='utf-8') as cfg_file:
        cfg = cfg_file.read()
    started_resources = set(re.findall(r'^\s*ensure\s+([^\s#]+)', cfg, re.MULTILINE))
    manifests = []
    expected_counts = {'[CORE]': 2, '[JOB]': 50, '[FUNCTION]': 23}
    for category, expected_count in expected_counts.items():
        category_dir = os.path.join(resources_dir, category)
        assert os.path.isdir(category_dir), f"Missing category {category}"
        resource_names = sorted(
            name for name in os.listdir(category_dir)
            if os.path.isdir(os.path.join(category_dir, name))
        )
        assert len(resource_names) == expected_count, (
            f"Expected {expected_count} resources in {category}, found {len(resource_names)}"
        )
        for name in resource_names:
            resource_dir = os.path.join(category_dir, name)
            manifest_path = os.path.join(resource_dir, 'fxmanifest.lua')
            assert os.path.isfile(manifest_path), f"{category}/{name} missing fxmanifest.lua"
            assert name in started_resources, f"{name} is not started by server.cfg"
            manifests.append(name)
    print(f"✓ All {len(manifests)} categorized resources have manifests and are started by server.cfg.")

if __name__ == '__main__':
    print("========================================")
    print("Running Full FiveM RP Verification Test")
    print("========================================")
    test_server_cfg()
    test_database_schema()
    test_dedicated_jobs()
    test_core_resources()
    test_all_resources_are_started_by_resource_name()
    print("========================================")
    print("ALL VERIFICATION CHECKS PASSED (100%)")
    print("========================================")
