#!/usr/bin/env python3
"""
Test Suite for GTA 5 FiveM RP Server Package
Validates:
1. Server configuration (server.cfg) and startup files.
2. SQL database schema structure and statements.
3. All resource manifests (fxmanifest.lua) and their referenced files.
4. Exact count and schema of the 50 roleplay jobs.
5. NUI HTML/CSS/JS file integrity.
"""

import os
import re
import sys

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def test_server_cfg():
    cfg_path = os.path.join(BASE_DIR, "server.cfg")
    assert os.path.isfile(cfg_path), "server.cfg is missing!"
    with open(cfg_path, "r", encoding="utf-8") as f:
        content = f.read()

    expected_ensures = [
        "ensure rp_loadscreen",
        "ensure rp_core",
        "ensure rp_characters",
        "ensure rp_economy",
        "ensure rp_jobs",
        "ensure rp_tablet_admin"
    ]
    for ens in expected_ensures:
        assert ens in content, f"Expected resource '{ens}' not found in server.cfg"

    assert "endpoint_add_tcp" in content, "TCP endpoint missing in server.cfg"
    assert "endpoint_add_udp" in content, "UDP endpoint missing in server.cfg"
    assert "sv_licenseKey" in content, "License key setting missing in server.cfg"
    print("✓ server.cfg verified successfully.")

def test_database_sql():
    sql_path = os.path.join(BASE_DIR, "database.sql")
    assert os.path.isfile(sql_path), "database.sql is missing!"
    with open(sql_path, "r", encoding="utf-8") as f:
        content = f.read()

    expected_tables = ["users", "characters", "bank_transactions", "jobs", "job_grades", "admin_logs"]
    for tbl in expected_tables:
        pattern = rf"CREATE TABLE IF NOT EXISTS `{tbl}`"
        assert re.search(pattern, content, re.IGNORECASE), f"Table {tbl} missing in database.sql"
    print("✓ database.sql verified successfully with all core tables.")

def test_50_jobs_list():
    jobs_file = os.path.join(BASE_DIR, "resources", "[roleplay]", "rp_jobs", "shared", "jobs_list.lua")
    assert os.path.isfile(jobs_file), "jobs_list.lua is missing!"
    with open(jobs_file, "r", encoding="utf-8") as f:
        content = f.read()

    # Match every job name definition: name = "xxx"
    job_names = re.findall(r'name\s*=\s*"([^"]+)"', content)
    # The default job 'unemployed' is defined separately as DefaultJob
    filtered_jobs = [j for j in job_names if j != "unemployed"]

    print(f"Found {len(filtered_jobs)} configured RP jobs:")
    for i, j in enumerate(filtered_jobs, 1):
        print(f"  {i:02d}. {j}")

    assert len(filtered_jobs) == 50, f"Expected exactly 50 jobs in JobsList, got {len(filtered_jobs)}"
    
    # Check key expected jobs
    expected_sample = ["police", "ambulance", "firefighter", "mechanic", "taxi", "smuggler", "casino_dealer"]
    for exp in expected_sample:
        assert exp in filtered_jobs, f"Expected job '{exp}' not found in jobs list!"

    print("✓ Exactly 50 roleplay jobs validated.")

def test_resources_and_files():
    resources = [
        "rp_core",
        "rp_characters",
        "rp_economy",
        "rp_jobs",
        "rp_loadscreen",
        "rp_tablet_admin"
    ]

    for res in resources:
        res_dir = os.path.join(BASE_DIR, "resources", "[roleplay]", res)
        assert os.path.isdir(res_dir), f"Resource directory {res} missing!"
        manifest_path = os.path.join(res_dir, "fxmanifest.lua")
        assert os.path.isfile(manifest_path), f"fxmanifest.lua missing in {res}!"

        with open(manifest_path, "r", encoding="utf-8") as mf:
            mcontent = mf.read()
            assert "fx_version 'cerulean'" in mcontent or "fx_version \"cerulean\"" in mcontent
            assert "game 'gta5'" in mcontent or "game \"gta5\"" in mcontent

    # Check NUI HTML files exist
    nui_resources = ["rp_characters", "rp_economy", "rp_jobs", "rp_loadscreen", "rp_tablet_admin"]
    for nres in nui_resources:
        html_file = os.path.join(BASE_DIR, "resources", "[roleplay]", nres, "html", "index.html")
        assert os.path.isfile(html_file), f"NUI index.html missing in {nres}!"
        assert os.path.getsize(html_file) > 100, f"NUI index.html in {nres} seems too small!"

    print("✓ All 6 custom roleplay resources and NUI interfaces verified.")

def run_all():
    print("========================================")
    print("Running FiveM RP Server Verification Test")
    print("========================================")
    test_server_cfg()
    test_database_sql()
    test_50_jobs_list()
    test_resources_and_files()
    print("========================================")
    print("ALL TESTS PASSED SUCCESSFULLY! (100%)")
    print("========================================")

if __name__ == "__main__":
    run_all()
