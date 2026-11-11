from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "resources" / "[FUNCTION]" / "rp_auto_rescue"


def test_auto_rescue_resource_is_registered_and_configured():
    manifest = (RESOURCE / "fxmanifest.lua").read_text(encoding="utf-8")
    config = (RESOURCE / "config.lua").read_text(encoding="utf-8")
    server_cfg = (ROOT / "server.cfg").read_text(encoding="utf-8")
    assert "'client/main.lua'" in manifest and "'server/main.lua'" in manifest
    assert "'rp_core'" in manifest
    assert "RecoveryDelay = 60" in config
    assert "Config.Hospital" in config
    assert "ensure rp_auto_rescue" in server_cfg


def test_auto_rescue_requires_server_verified_death_and_prevents_duplicate_runs():
    server = (RESOURCE / "server" / "main.lua").read_text(encoding="utf-8")
    assert "IsEntityDead(ped)" in server
    assert "activeRescues[src]" in server
    assert "CanPerformAction(src, 'auto_rescue:request'" in server
    assert "AddEventHandler('playerDropped'" in server


def test_auto_rescue_client_runs_ambulance_stretcher_hospital_and_revive_sequence():
    client = (RESOURCE / "client" / "main.lua").read_text(encoding="utf-8")
    for required in (
        "CreateVehicle(vehicleHash", "CreatePed(26", "TaskVehicleDriveToCoordLongrange",
        "CreateObject(stretcherModel", "AttachEntityToEntity(patient, bed",
        "AttachEntityToEntity(bed, ambulance", "Config.Hospital.coords",
        "Wait(1000)", "NetworkResurrectLocalPlayer", "SetEntityHealth(ped, 200)"
    ):
        assert required in client
    assert "rescueRevived" in client
    assert "nextRescueRequestAt" in client
    assert "onResourceStop" in client


if __name__ == "__main__":
    for test_fn in (
        test_auto_rescue_resource_is_registered_and_configured,
        test_auto_rescue_requires_server_verified_death_and_prevents_duplicate_runs,
        test_auto_rescue_client_runs_ambulance_stretcher_hospital_and_revive_sequence,
    ):
        test_fn()
    print("All 3 automatic rescue regression checks passed.")
