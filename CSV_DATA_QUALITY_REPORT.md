# CSV Data Quality Report

**Generated:** 2026-03-18  
**Purpose:** Assess whether CSV can replace DB for demos when some DB tables have missing data.

---

## Summary: **CSV is Usable for Demos** ✅

With the applied fallback (empty `teaching_languages` → treated as `["English"]`), the CSV data produces **97 matchable teachers** for English-language students.

---

## Data Quality by File

| File | Rows | Quality | Notes |
|------|------|---------|-------|
| **teachers.csv** | 102 | ⚠️ Mixed | 98 teachers have empty `teaching_languages`/`languages_spoken`. Fallback applied. |
| **teacher_availability.csv** | 1,022 | ✅ OK | 122 unique teacher_ids. Day 0=Sunday. |
| **students.csv** | varies | ⚠️ Mixed | 930 has full data. Many rows have empty `preferred_days`, `preferred_time_start/end`. |
| **teacher_performance_profile.csv** | varies | ✅ OK | Has `student_retention_rate`, `avg_rating`. |
| **classes.csv**, **leads.csv** | varies | ✅ OK | Used for conversion/retention and trial detection. |

---

## Root Cause of Previous 0 Matches

- **Teachers 201–204**: Had `teaching_languages` in CSV but **no** rows in `teacher_availability.csv`.
- **Teachers 1086+**: Had availability but **empty** `teaching_languages`.
- Hard filter: `target_language in teaching_languages` → empty → filter failed.

---

## Fix Applied

In `csv_repository._load_teachers()`:

- When `teaching_languages` is empty, treat as `["English"]` for demo mode.
- When `languages_spoken` is present but `teaching_languages` is empty, use `languages_spoken` as teaching languages.
- Health report notes: *"X teacher(s) had empty teaching_languages in CSV; treated as [English] for demo matching (regenerate CSV for accurate data)"*.

---

## Current State After Fix

| Metric | Value |
|--------|-------|
| Teachers eligible for English | 102 |
| Teachers with BOTH language + availability | **97** |
| Sample matchable teacher_ids | 1086, 1090, 1131, 1302, 1336 |

---

## Long-Term Recommendations

1. **Regenerate CSV exports** so `teachers.csv` includes all teacher IDs from `teacher_availability.csv` and has valid `teaching_languages`/`languages_spoken` for active teachers.
2. **Reconcile teacher_availability** with teachers.csv — 25 teacher_ids in availability have no profile; 5 teachers have no availability.
3. **Enrich students.csv** — ensure `preferred_days`, `preferred_time_start`, `preferred_time_end` are populated for students used in demos.

---

## Usage

- **Demo mode:** `DATA_SOURCE=csv` works; matches return for real student data (e.g. student 930).
- **Dummy data:** `add_dummy_teacher()` and `add_dummy_student()` still work for isolated demos.
- **Health check:** `GET /demo/data-health` or `CsvRepository.health()` reports current state.
