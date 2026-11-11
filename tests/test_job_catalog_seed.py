import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_all_declared_jobs_have_five_runtime_grades():
    source = (ROOT / "resources/[FUNCTION]/rp_jobs/shared/jobs_list.lua").read_text(encoding="utf-8")
    catalog = source.split("-- Sans-emploi", 1)[0]
    jobs = re.findall(r'name = "([^"]+)"[\s\S]*?grades = \{([\s\S]*?)\n        \}', catalog)

    assert len(jobs) == 50
    for job_name, grade_block in jobs:
        grades = re.findall(r'\[(\d+)\] = \{ label = "([^"]+)", salary = (\d+) \}', grade_block)
        assert [int(grade) for grade, _, _ in grades] == [0, 1, 2, 3, 4], job_name
        assert all(int(salary) > 0 for _, _, salary in grades), job_name


def test_job_database_migration_seeds_every_job_and_five_grades_without_overwriting():
    migration = (ROOT / "migrations/005_seed_jobs_and_grades.sql").read_text(encoding="utf-8")
    source = (ROOT / "resources/[FUNCTION]/rp_jobs/shared/jobs_list.lua").read_text(encoding="utf-8")
    catalog = source.split("-- Sans-emploi", 1)[0]
    job_names = re.findall(r'name = "([^"]+)"', catalog)

    assert migration.count("INSERT IGNORE INTO " + chr(96) + "jobs" + chr(96)) == 1
    assert migration.count("INSERT IGNORE INTO " + chr(96) + "job_grades" + chr(96)) == 1
    assert "START TRANSACTION;" in migration and "COMMIT;" in migration
    grade_rows = re.findall(
        r"\('((?:''|[^'])*)',\s*(\d+),\s*'grade_\d+',\s*'((?:''|[^'])*)',\s*(\d+)\)",
        migration,
    )
    by_job = {}
    for name, grade, label, salary in grade_rows:
        by_job.setdefault(name.replace("''", "'"), []).append((int(grade), int(salary)))

    assert set(job_names).issubset(by_job)
    for job_name in job_names:
        grades = sorted(grade for grade, _ in by_job[job_name])
        assert grades == [0, 1, 2, 3, 4], job_name
        assert all(salary > 0 for _, salary in by_job[job_name])
    assert by_job["unemployed"] == [(0, 150)]
