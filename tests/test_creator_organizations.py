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
    assert "max_employees INT UNSIGNED NOT NULL DEFAULT 0" in jobs
    assert "SELECT COUNT(*) FROM characters WHERE job = ?" in jobs
    assert "Ce métier a atteint sa capacité maximale." in jobs
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
    assert 'id="new-job-capacity"' in html
    assert "post(action, data)" in ui
    assert "maxEmployees: Number(document.getElementById('new-job-capacity').value)" in ui


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



def test_creator_can_edit_and_delete_persisted_gangs():
    gangs = read("resources/[FUNCTION]/rp_gangs/server/main.lua")
    creator = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    assert "exports('UpdateGang', UpdateGang)" in gangs
    assert "exports('DeleteGang', DeleteGang)" in gangs
    assert "UPDATE rp_gangs SET label = ?, description = ?, color = ? WHERE name = ?" in gangs
    assert "DELETE FROM rp_gangs WHERE name = ?" in gangs
    assert "creator:update_gang" in creator and "creator:delete_gang" in creator
    assert "RegisterNUICallback('updateGang'" in client and "RegisterNUICallback('deleteGang'" in client
    assert "id=\"cancel-gang-edit\"" in html
    assert "const action = editingGangName ? 'updateGang' : 'createGang'" in ui and "post(action, data)" in ui
    assert "post('deleteGang', { name: gang.name })" in ui
    assert "window.confirm" in ui


def test_creator_can_edit_and_safely_delete_custom_jobs():
    jobs = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    server = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    assert "exports('UpdateCustomJob', UpdateCustomJob)" in jobs
    assert "exports('DeleteCustomJob', DeleteCustomJob)" in jobs
    assert "SELECT COUNT(*) FROM characters WHERE job = ?" in jobs
    assert "SELECT COUNT(*) FROM rp_job_bank_transactions WHERE job = ?" in jobs
    assert "bank > 0 or history > 0" in jobs
    assert "rp_jobs:client:removeCustomJob" in jobs
    assert "creator:update_job" in server and "creator:delete_job" in server
    assert "exports['rp_jobs']:UpdateCustomJob" in server
    assert "exports['rp_jobs']:DeleteCustomJob" in server
    assert "RegisterNUICallback('updateJob'" in client
    assert "RegisterNUICallback('deleteJob'" in client
    assert 'id="creator-job-list"' in html and 'id="cancel-job-edit"' in html
    assert "post(action, data)" in ui and "post('deleteJob', { name: job.name })" in ui
    assert "customJobsData" in client and "renderCreatorJobs" in ui


def test_creator_job_garages_are_persisted_and_validated():
    server = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    assert "CREATE TABLE IF NOT EXISTS rp_creator_job_garages" in server
    assert "creator:save_job_garage" in server and "creator:delete_job_garage" in server
    assert "exports['rp_jobs']:GetJob(jobName)" in server
    assert "or #data.vehicles > 20" in server
    assert "model:find" in server
    assert "minGrade < 0 or minGrade > 4" in server
    assert "local spawnX = coords.x - math.sin(radians) * 4.0" in server
    assert "RegisterNUICallback('saveJobGarage'" in client
    assert "RegisterNUICallback('deleteJobGarage'" in client
    assert 'id="job-garage-job"' in html and 'id="job-garage-add-vehicle"' in html
    assert 'id="job-garage-save"' in html and 'id="job-garage-delete"' in html
    assert "post('saveJobGarage', { job, vehicles: editingJobGarageVehicles })" in ui
    assert "post('deleteJobGarage', { job })" in ui
    assert "renderJobGarages(d.jobGarages || [])" in ui



def test_job_garage_runtime_enforces_server_job_grade_and_vehicle_ownership():
    server = read("resources/[FUNCTION]/rp_garages/server/job_garage.lua")
    client = read("resources/[FUNCTION]/rp_garages/client/job_garage.lua")
    manifest = read("resources/[FUNCTION]/rp_garages/fxmanifest.lua")
    creator = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    assert "GetPlayerFromId(src)" in server
    assert "player.jobGrade" in server
    assert "entry.minGrade" in server
    assert "CanPerformAction(src, 'garages:spawn_job_vehicle'" in server
    assert "CreateVehicleServerSetter" in server
    assert "activeVehicles[src]" in server
    assert "GetPedInVehicleSeat(vehicle, -1) ~= ped" in server
    assert "NetworkGetNetworkIdFromEntity(vehicle) ~= active.netId" in server
    assert "DeleteEntity(vehicle)" in server
    assert "requestJobGarageMarker" in client
    assert "spawnJobVehicle" in client and "storeJobVehicle" in client
    assert "server/job_garage.lua" in manifest and "client/job_garage.lua" in manifest
    assert "rp_garages:server:reloadJobGarages" in creator



def test_creator_job_armory_and_shared_locker_are_persisted_and_grade_restricted():
    creator = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    creator_client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    creator_html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    creator_ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    inventory = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    inventory_client = read("resources/[FUNCTION]/rp_inventory/client/job_storage.lua")
    inventory_manifest = read("resources/[FUNCTION]/rp_inventory/fxmanifest.lua")
    catalog = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    sql = read("database.sql")

    assert "CREATE TABLE IF NOT EXISTS rp_creator_job_storage" in creator
    assert "creator:save_job_storage" in creator and "creator:delete_job_storage" in creator
    assert "exports['rp_inventory']:GetItemCatalog()" in creator
    assert "itemDef.type ~= 'weapon'" in creator
    assert "grade < 0 or grade > 4" in creator
    assert "RegisterNUICallback('saveJobStorage'" in creator_client
    assert "RegisterNUICallback('deleteJobStorage'" in creator_client
    assert 'id="job-storage-job"' in creator_html
    assert 'id="job-storage-weapon-list"' in creator_html
    assert "renderJobStorages(d.jobStorages || [], d.storageCatalog || [])" in creator_ui
    assert "type = definition.type or 'item'" in catalog

    assert "GetPlayerFromId(src)" in inventory
    assert "player.job" in inventory and "player.jobGrade" in inventory
    assert "GetEntityCoords(ped) - config.coords" in inventory
    assert "config.armoryItems[itemName]" in inventory
    assert "IsWeaponAllowed(definition.weapon)" in inventory
    assert "AcquireCharacterLock({ player.charId })" in inventory
    assert "MySQL.transaction.await(queries)" in inventory
    transfer = inventory[inventory.index("RegisterNetEvent('rp_inventory:server:transferJobStorage'"):]
    assert transfer.index("AcquireCharacterLock({ player.charId })") < transfer.index("local storageRow = MySQL.single.await")
    assert "jobStorageLocks[lockedJob] = src" in transfer
    assert "rp_job_storage_logs" in inventory
    assert "rp_inventory:server:transferJobStorage" in inventory
    assert "rp_inventory:client:jobStorageData" in inventory
    assert "rp_inventory:server:openJobStorage" in inventory
    assert "server/job_storage.lua" not in inventory_manifest
    assert "client/job_storage.lua" in inventory_manifest
    assert "transferJobStorage" in inventory_client
    assert "rp_job_storage_items" in sql and "rp_job_storage_logs" in sql


if __name__ == "__main__":
    test_custom_jobs_are_persisted_validated_and_loaded_with_numeric_grades()
    test_creator_job_creation_is_permission_gated_and_updates_job_selectors()
    test_gang_registry_persists_validated_names_and_creator_lists_gangs()
    test_creator_can_edit_and_delete_persisted_gangs()
    test_creator_can_edit_and_safely_delete_custom_jobs()
    test_creator_job_garages_are_persisted_and_validated()
    test_job_garage_runtime_enforces_server_job_grade_and_vehicle_ownership()
    test_creator_job_armory_and_shared_locker_are_persisted_and_grade_restricted()
    print("Creator organization regression checks passed.")
