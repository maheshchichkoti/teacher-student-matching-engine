import csv
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv
from psycopg2.extras import RealDictCursor

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "3.124.111.213"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "user": os.getenv("DB_USER", "admin"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "tulkka_live"),
}

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)


def get_conn():
    return psycopg2.connect(**DB_CONFIG)


def export_teachers(conn):
    query = """
        SELECT
            teacher_id,
            full_name,
            status,
            teaching_languages,
            trial_enabled,
            age_min,
            age_max,
            teacher_tags,
            languages_spoken,
            max_students_capacity,
            trial_priority
        FROM clean.teachers
        WHERE status = 'active'
        ORDER BY teacher_id
        LIMIT 500
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        rows = cur.fetchall()

    path = DATA_DIR / "teachers.csv"
    with path.open("w", newline="", encoding="utf-8") as f:
        if rows:
            writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)
    return path, len(rows)


def export_students(conn):
    query = """
        SELECT
            student_id,
            full_name,
            native_language,
            cefr_level,
            student_age,
            target_language,
            requires_native_language_teacher,
            preferred_days,
            preferred_time_start,
            preferred_time_end,
            sessions_per_week
        FROM clean.students
        ORDER BY student_id
        LIMIT 500
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        rows = cur.fetchall()

    path = DATA_DIR / "students.csv"
    with path.open("w", newline="", encoding="utf-8") as f:
        if rows:
            writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)
    return path, len(rows)


def main():
    conn = get_conn()
    try:
        teacher_path, teacher_count = export_teachers(conn)
        student_path, student_count = export_students(conn)
        print(f"Exported {teacher_count} teachers -> {teacher_path}")
        print(f"Exported {student_count} students -> {student_path}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
