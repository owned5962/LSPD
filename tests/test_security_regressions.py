#!/usr/bin/env python3
"""
Static security regression checks for the FiveM RP server.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_admin_tablet_has_no_source_one_bypass():
    source = (ROOT / "resources/[roleplay]/rp_tablet_admin/server/main.lua").read_text()
    assert "if source == 1 then" not in source
    assert 'IsPlayerAceAllowed(source, "rp_admin")' in source
    assert "GetOnlineTargetId" in source
    assert "amount > 1000000" in source
    assert "selectedJob.grades[grade]" in source


def test_character_creation_requires_license_and_validated_data():
    source = (ROOT / "resources/[roleplay]/rp_characters/server/main.lua").read_text()
    assert "return nil" in source
    assert "if not identifier then" in source
    assert "if type(data) ~= 'table' then" in source
    assert "if InMemoryCharacters[identifier] then" in source
    assert "if not IsValidDate(data.dateofbirth) then" in source
    assert "local allowedSpawns" in source
    assert "or ('steam:' .. tostring(source))" not in source


if __name__ == "__main__":
    test_admin_tablet_has_no_source_one_bypass()
    test_character_creation_requires_license_and_validated_data()
    print("Security regression checks passed.")
