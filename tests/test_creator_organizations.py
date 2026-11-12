#!/usr/bin/env python3
"""Regression checks for Creator-managed custom jobs and gangs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_custom_jobs_are_persisted_validated_and_loaded_with_numeric_grades():
    jobs = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    core = read("resources/[CORE]/rp_core/server/player.lua")
    assert "CREATE TABLE IF NOT EXISTS rp_custom_jobs" in jobs
    assert "exports('CreateCustomJob', CreateCustomJob)" in jobs
    assert "name:match('^[a-z][a-z0-9_]+') ~= name" in jobs
    assert "for grade = 0, 4 do" in jobs
    assert "numericGrades[grade]" in jobs
    assert "exports['rp_jobs']:IsValidJob(jobName)" in core
    assert "TriggerClientEvent('rp_jobs:client:syncCustomJobs'" in jobs


def test_creator_job_creation_is_permission_gated_and_updates_job_selectors():
    server = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    assert "creator:create_job" in server
    assert "exports['rp_jobs']:CreateCustomJob" in server
    assert "RegisterNUICallback('createJob'" in client
    assert 'data-tab="organizations"' in html
    assert 'id="new-job-grade-4"' in html
    assert "post('createJob', data)" in ui


def test_gang_registry_persists_validated_names_and_creator_lists_gangs():
    gangs = read("resources/[FUNCTION]/rp_gangs/server/main.lua")
    creator = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    assert "CREATE TABLE IF NOT EXISTS rp_gangs" in gangs
    assert "exports('CreateGang', CreateGang)" in gangs
    assert "exports('GetAllGangs', GetAllGangs)" in gangs
    assert "creator:create_gang" in creator
    assert "exports['rp_gangs']:CreateGang" in creator
    assert "requestOrganizations" in client
    assert "organizationsData" in client


if __name__ == "__main__":
    test_custom_jobs_are_persisted_validated_and_loaded_with_numeric_grades()
    test_creator_job_creation_is_permission_gated_and_updates_job_selectors()
    test_gang_registry_persists_validated_names_and_creator_lists_gangs()
    print("Creator organization regression checks passed.")
