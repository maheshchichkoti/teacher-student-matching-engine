import csv
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv
from psycopg2.extras import RealDictCursor

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "Password@123"),
    "database": os.getenv("DB_NAME", "tulkka_subset"),
}

EXPORT_LIMIT = int(os.getenv("EXPORT_LIMIT", "1000000"))

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)


def get_conn():
    return psycopg2.connect(**DB_CONFIG)


def export_query(conn, filename, query):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        columns = [desc[0] for desc in (cur.description or [])]
        rows = cur.fetchall()

    path = DATA_DIR / filename
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        if columns:
            writer.writeheader()
        if rows:
            writer.writerows(rows)
    return path, len(rows)


EXPORTS = {
    "teachers.csv": f"""
        SELECT
            teacher_id,
            full_name,
            email,
            timezone,
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
        LIMIT {EXPORT_LIMIT}
    """,
    "students.csv": f"""
        SELECT
            student_id,
            full_name,
            email,
            timezone,
            native_language,
            cefr_level,
            student_age,
            target_language,
            requires_native_language_teacher,
            preferred_days,
            preferred_time_start,
            preferred_time_end,
            sessions_per_week,
            learning_goal
        FROM clean.students
        ORDER BY student_id
        LIMIT {EXPORT_LIMIT}
    """,
    "classes.csv": f"""
        SELECT
            class_id,
            student_id,
            teacher_id,
            is_trial,
            subscription_id,
            meeting_start,
            meeting_end,
            lifecycle_status,
            created_at,
            updated_at
        FROM clean.classes
        ORDER BY class_id
        LIMIT {EXPORT_LIMIT}
    """,
    "teacher_availability.csv": f"""
        SELECT
            availability_id,
            teacher_id,
            day_of_week,
            start_time,
            end_time,
            is_active
        FROM clean.teacher_availability
        ORDER BY teacher_id, day_of_week, start_time
        LIMIT {EXPORT_LIMIT}
    """,
    "teacher_holidays.csv": f"""
        SELECT
            holiday_id,
            teacher_id,
            holiday_date,
            full_day,
            start_time,
            end_time,
            reason,
            created_at
        FROM clean.teacher_holidays
        ORDER BY teacher_id, holiday_date
        LIMIT {EXPORT_LIMIT}
    """,
    "subscriptions.csv": f"""
        SELECT
            subscription_id,
            idempotency_key,
            owner_student_id,
            plan_type,
            plan_name,
            classes_per_month,
            classes_remaining,
            amount_ils,
            billing_frequency,
            status,
            created_at,
            updated_at
        FROM clean.subscriptions
        ORDER BY subscription_id
        LIMIT {EXPORT_LIMIT}
    """,
    "subscription_members.csv": f"""
        SELECT
            subscription_id,
            student_id,
            family_id,
            role,
            status,
            joined_at,
            updated_at
        FROM clean.subscription_members
        ORDER BY subscription_id, student_id
        LIMIT {EXPORT_LIMIT}
    """,
    "leads.csv": f"""
        SELECT
            lead_id,
            phone,
            email,
            name,
            source,
            converted_student_id,
            funnel_stage,
            first_contact_at,
            converted_at,
            created_at
        FROM analytics.leads
        ORDER BY lead_id
        LIMIT {EXPORT_LIMIT}
    """,
    "teacher_performance_profile.csv": f"""
        SELECT
            teacher_id,
            avg_rating,
            total_classes_taught,
            verification_rate,
            avg_topics_per_class,
            student_retention_rate,
            total_earnings_ils,
            _etl_updated_at
        FROM serve.teacher_performance_profile
        ORDER BY teacher_id
        LIMIT {EXPORT_LIMIT}
    """,
    "trial_class_feedback.csv": f"""
        SELECT
            feedback_id,
            class_id,
            student_id,
            teacher_id,
            feedback_role,
            trial_success,
            teacher_match_quality,
            student_feedback,
            created_at
        FROM analytics.trial_class_feedback
        ORDER BY feedback_id
        LIMIT {EXPORT_LIMIT}
    """,
}


def main():
    conn = get_conn()
    try:
        for filename, query in EXPORTS.items():
            path, count = export_query(conn, filename, query)
            print(f"Exported {count} rows -> {path}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
