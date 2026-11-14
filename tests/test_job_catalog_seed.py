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
    database_sql = (ROOT / "database.sql").read_text(encoding="utf-8")
    catalogue_comment = database_sql.index("-- Catalogue initial des métiers et de leurs grades.")
    seed_start = database_sql.rindex("START TRANSACTION;", 0, catalogue_comment)
    seed_end = database_sql.index("COMMIT;", catalogue_comment) + len("COMMIT;")
    seed = database_sql[seed_start:seed_end]
    source = (ROOT / "resources/[FUNCTION]/rp_jobs/shared/jobs_list.lua").read_text(encoding="utf-8")
    catalog = source.split("-- Sans-emploi", 1)[0]
    job_names = re.findall(r'name = "([^"]+)"', catalog)

    assert seed.count("INSERT IGNORE INTO " + chr(96) + "jobs" + chr(96)) == 1
    assert seed.count("INSERT IGNORE INTO " + chr(96) + "job_grades" + chr(96)) == 1
    assert "START TRANSACTION;" in seed and "COMMIT;" in seed
    assert seed.strip() in database_sql
    grade_rows = re.findall(
        r"\('((?:''|[^'])*)',\s*(\d+),\s*'grade_\d+',\s*'((?:''|[^'])*)',\s*(\d+)\)",
        seed,
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


if __name__ == "__main__":
    test_all_declared_jobs_have_five_runtime_grades()
    test_job_database_migration_seeds_every_job_and_five_grades_without_overwriting()
    print("Job catalog and database seed checks passed.")
