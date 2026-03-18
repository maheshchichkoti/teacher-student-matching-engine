import argparse
import json
import os
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from typing import Any, Iterable

import mysql.connector
import psycopg2
from dotenv import load_dotenv

load_dotenv()

PG_CONFIG = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "Password@123"),
    "dbname": os.getenv("DB_NAME", "tulkka_subset"),
}

MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "3.124.111.213"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "admin"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "tulkka_live"),
}

DAY_NAME_TO_INDEX = {
    "sun": 0,
    "mon": 1,
    "tue": 2,
    "wed": 3,
    "thu": 4,
    "fri": 5,
    "sat": 6,
}

PG_LEAD_SOURCES = {"whatsapp_campaign", "google_ad", "referral", "organic", "agent_manual"}
PG_FUNNEL_STAGES = {"new", "contacted", "demo_scheduled", "demo_done", "converted", "lost"}
PG_SUBSCRIPTION_STATUSES = {"pending", "active", "paused", "expired", "cancelled"}


def pg_conn():
    return psycopg2.connect(**PG_CONFIG)



def mysql_conn():
    return mysql.connector.connect(**MYSQL_CONFIG)



def ensure_is_trial_column(conn) -> None:
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE clean.classes ADD COLUMN IF NOT EXISTS is_trial BOOLEAN")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_classes_is_trial ON clean.classes(is_trial)")
    conn.commit()



def fetch_mysql_rows(query: str, params: tuple[Any, ...] | None = None) -> list[dict[str, Any]]:
    conn = mysql_conn()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(query, params or ())
        rows = cur.fetchall()
        cur.close()
        return rows
    finally:
        conn.close()


def build_student_lookup(conn) -> tuple[dict[str, int], dict[str, int]]:
    email_map: dict[str, int] = {}
    phone_map: dict[str, int] = {}
    with conn.cursor() as cur:
        cur.execute("SELECT student_id, email FROM clean.students WHERE email IS NOT NULL")
        for student_id, email in cur.fetchall():
            email_map[str(email).strip().lower()] = student_id
    return email_map, phone_map


def build_teacher_id_set(conn) -> set[int]:
    with conn.cursor() as cur:
        cur.execute("SELECT teacher_id FROM clean.teachers")
        return {row[0] for row in cur.fetchall()}


def backfill_is_trial(conn) -> int:
    mysql_rows = fetch_mysql_rows("SELECT id, is_trial FROM classes WHERE is_trial IS NOT NULL")
    if not mysql_rows:
        return 0
    with conn.cursor() as cur:
        cur.executemany(
            "UPDATE clean.classes SET is_trial = %s WHERE class_id = %s",
            [(bool(row["is_trial"]), row["id"]) for row in mysql_rows],
        )
        cur.execute(
            "UPDATE clean.classes SET is_trial = FALSE WHERE is_trial IS NULL AND subscription_id IS NOT NULL"
        )
        cur.execute(
            "UPDATE clean.classes SET is_trial = TRUE WHERE is_trial IS NULL AND subscription_id IS NULL"
        )
    conn.commit()
    return len(mysql_rows)


def normalize_lead_source(_row: dict[str, Any]) -> str:
    return "agent_manual"


def normalize_funnel_stage(row: dict[str, Any], converted_student_id: int | None) -> str:
    if converted_student_id or row.get("is_registered"):
        return "converted"
    return "new"


def backfill_leads(conn) -> int:
    rows = fetch_mysql_rows("SELECT id, firstname, lastname, email, phone, is_registered, created_at, updated_at FROM leads")
    email_map, _ = build_student_lookup(conn)
    payload = []
    for row in rows:
        first = (row.get("firstname") or "").strip()
        last = (row.get("lastname") or "").strip()
        name = (f"{first} {last}".strip() or row.get("email") or row.get("phone") or f"lead_{row['id']}")
        email = (row.get("email") or "").strip().lower() or None
        converted_student_id = email_map.get(email) if email else None
        source = normalize_lead_source(row)
        funnel_stage = normalize_funnel_stage(row, converted_student_id)
        payload.append(
            (
                row["id"],
                row.get("phone"),
                row.get("email"),
                name,
                source if source in PG_LEAD_SOURCES else "agent_manual",
                None,
                None,
                funnel_stage if funnel_stage in PG_FUNNEL_STAGES else "new",
                converted_student_id,
                None,
                row.get("updated_at") or row.get("created_at"),
                row.get("updated_at") if converted_student_id else None,
                row.get("created_at") or datetime.utcnow(),
            )
        )
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE analytics.leads RESTART IDENTITY")
        if payload:
            cur.executemany(
                """
                INSERT INTO analytics.leads (
                    lead_id, phone, email, name, source, campaign_id, assigned_agent_id,
                    funnel_stage, converted_student_id, lost_reason, first_contact_at,
                    converted_at, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                payload,
            )
    conn.commit()
    return len(payload)


def parse_day_slots(raw_value: Any) -> list[tuple[time, time]]:
    if not raw_value:
        return []
    if isinstance(raw_value, (bytes, bytearray)):
        raw_value = raw_value.decode("utf-8")
    if isinstance(raw_value, str):
        try:
            parsed = json.loads(raw_value)
        except json.JSONDecodeError:
            return []
    elif isinstance(raw_value, dict):
        parsed = raw_value
    elif isinstance(raw_value, list):
        parsed = raw_value
    else:
        return []
    if isinstance(parsed, dict):
        active_times = sorted(k for k, v in parsed.items() if v)
    elif isinstance(parsed, list):
        active_times = sorted(
            str(item)
            for item in parsed
            if isinstance(item, str) and ":" in item
        )
    else:
        return []
    if not active_times:
        return []
    minutes = []
    for value in active_times:
        hh, mm = map(int, value.split(":"))
        minutes.append(hh * 60 + mm)
    ranges = []
    start = minutes[0]
    prev = minutes[0]
    for current in minutes[1:]:
        if current != prev + 30:
            ranges.append((start, prev + 30))
            start = current
        prev = current
    ranges.append((start, prev + 30))
    result = []
    for start_min, end_min in ranges:
        if end_min >= 24 * 60:
            end_min = (24 * 60) - 1
        if end_min <= start_min:
            continue
        result.append(
            (
                time(hour=start_min // 60, minute=start_min % 60),
                time(hour=end_min // 60, minute=end_min % 60),
            )
        )
    return result


def backfill_teacher_availability(conn) -> int:
    rows = fetch_mysql_rows("SELECT user_id, mon, tue, wed, thu, fri, sat, sun FROM teacher_availability WHERE user_id IS NOT NULL")
    valid_teacher_ids = build_teacher_id_set(conn)
    dedup_map: dict[tuple[int, int, time], tuple[int, int, time, time, str, bool]] = {}
    for row in rows:
        teacher_id = row["user_id"]
        if teacher_id not in valid_teacher_ids:
            continue
        for day_name, day_index in DAY_NAME_TO_INDEX.items():
            for start_time, end_time in parse_day_slots(row.get(day_name)):
                key = (teacher_id, day_index, start_time)
                existing = dedup_map.get(key)
                if existing is None or end_time > existing[3]:
                    dedup_map[key] = (teacher_id, day_index, start_time, end_time, "UTC", True)
    deduped_payload = list(dedup_map.values())
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE clean.teacher_availability RESTART IDENTITY")
        if deduped_payload:
            cur.executemany(
                """
                INSERT INTO clean.teacher_availability (
                    teacher_id, day_of_week, start_time, end_time, timezone, is_active
                ) VALUES (%s, %s, %s, %s, %s, %s)
                """,
                deduped_payload,
            )
    conn.commit()
    return len(deduped_payload)


def daterange(start_date: date, end_date: date) -> Iterable[date]:
    current = start_date
    while current <= end_date:
        yield current
        current += timedelta(days=1)


def backfill_teacher_holidays(conn) -> int:
    holiday_rows = fetch_mysql_rows(
        "SELECT user_id, reason, form_date, to_date, status FROM teacher_holiday WHERE user_id IS NOT NULL AND status = 'approved'"
    )
    disabled_rows = fetch_mysql_rows(
        "SELECT teacher_id, date_start, date_end, time_start, time_end, is_every FROM teachers_disabled_dates WHERE teacher_id IS NOT NULL"
    )
    valid_teacher_ids = build_teacher_id_set(conn)
    payload: list[tuple[Any, ...]] = []
    for row in holiday_rows:
        if row["user_id"] not in valid_teacher_ids:
            continue
        start_dt = row.get("form_date")
        end_dt = row.get("to_date") or start_dt
        if not start_dt:
            continue
        start_date = start_dt.date()
        end_date = end_dt.date() if isinstance(end_dt, datetime) else start_date
        for day in daterange(start_date, end_date):
            payload.append((row["user_id"], day, True, None, None, row.get("reason"), start_dt))
    for row in disabled_rows:
        if row["teacher_id"] not in valid_teacher_ids:
            continue
        start_date = row.get("date_start")
        end_date = row.get("date_end") or start_date
        if not start_date:
            continue
        for day in daterange(start_date, end_date):
            full_day = bool(row.get("is_every")) or row.get("time_start") == row.get("time_end")
            payload.append(
                (
                    row["teacher_id"],
                    day,
                    full_day,
                    None if full_day else row.get("time_start"),
                    None if full_day else row.get("time_end"),
                    "legacy_disabled_date",
                    datetime.utcnow(),
                )
            )
    deduped = list({(p[0], p[1], p[2], p[3], p[4], p[5]): p for p in payload}.values())
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE clean.teacher_holidays RESTART IDENTITY")
        if deduped:
            cur.executemany(
                """
                INSERT INTO clean.teacher_holidays (
                    teacher_id, holiday_date, full_day, start_time, end_time, reason, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                deduped,
            )
    conn.commit()
    return len(deduped)



def map_subscription_status(value: Any) -> str:
    normalized = str(value or "pending").strip().lower()
    if normalized in PG_SUBSCRIPTION_STATUSES:
        return normalized
    if normalized in {"inactive", "stopped"}:
        return "cancelled"
    return "pending"



def backfill_subscription_members(conn) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO clean.subscription_members (
                subscription_id, student_id, family_id, role, status, joined_at, updated_at
            )
            SELECT
                subscription_id,
                owner_student_id,
                NULL,
                'owner'::clean.member_role,
                CASE
                    WHEN status::text IN ('pending', 'active', 'paused', 'expired', 'cancelled')
                    THEN status
                    ELSE 'active'::clean.subscription_status
                END,
                created_at,
                updated_at
            FROM clean.subscriptions
            ON CONFLICT (subscription_id, student_id) DO UPDATE
            SET
                role = EXCLUDED.role,
                status = EXCLUDED.status,
                updated_at = EXCLUDED.updated_at
            """
        )
        cur.execute("SELECT COUNT(*) FROM clean.subscription_members")
        count = cur.fetchone()[0]
    conn.commit()
    return count



def backfill_teacher_performance_profile(conn) -> int:
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE serve.teacher_performance_profile")
        cur.execute(
            """
            WITH class_counts AS (
                SELECT
                    teacher_id,
                    COUNT(*) FILTER (
                        WHERE lifecycle_status IN ('completed_raw', 'completed_ai', 'verified')
                    ) AS total_classes_taught,
                    COUNT(*) FILTER (WHERE lifecycle_status = 'verified') AS verified_classes,
                    COUNT(DISTINCT student_id) FILTER (
                        WHERE lifecycle_status IN ('completed_raw', 'completed_ai', 'verified')
                    ) AS active_students,
                    COUNT(DISTINCT student_id) FILTER (
                        WHERE lifecycle_status IN ('completed_raw', 'completed_ai', 'verified')
                          AND student_id IN (
                              SELECT student_id
                              FROM clean.classes c2
                              WHERE c2.teacher_id = clean.classes.teacher_id
                                AND c2.lifecycle_status IN ('completed_raw', 'completed_ai', 'verified')
                              GROUP BY student_id
                              HAVING COUNT(*) > 1
                          )
                    ) AS retained_students
                FROM clean.classes
                GROUP BY teacher_id
            ),
            class_fact_metrics AS (
                SELECT
                    teacher_id,
                    AVG(COALESCE(topics_verified, 0))::numeric(5,2) AS avg_topics_per_class
                FROM analytics.class_facts
                GROUP BY teacher_id
            ),
            earnings AS (
                SELECT teacher_id, COALESCE(SUM(amount_ils), 0)::numeric(12,2) AS total_earnings_ils
                FROM clean.teacher_earning_analytics
                GROUP BY teacher_id
            )
            INSERT INTO serve.teacher_performance_profile (
                teacher_id,
                avg_rating,
                total_classes_taught,
                verification_rate,
                avg_topics_per_class,
                student_retention_rate,
                total_earnings_ils,
                _etl_updated_at
            )
            SELECT
                t.teacher_id,
                COALESCE(t.avg_rating, 0),
                COALESCE(cc.total_classes_taught, t.total_classes_taught, 0),
                CASE
                    WHEN COALESCE(cc.total_classes_taught, t.total_classes_taught, 0) = 0 THEN COALESCE(t.verification_rate, 0)
                    ELSE ROUND((COALESCE(cc.verified_classes, 0)::numeric / NULLIF(COALESCE(cc.total_classes_taught, 0), 0)) * 100, 2)
                END,
                COALESCE(cf.avg_topics_per_class, 0),
                CASE
                    WHEN COALESCE(cc.active_students, 0) = 0 THEN 0
                    ELSE ROUND((COALESCE(cc.retained_students, 0)::numeric / NULLIF(cc.active_students, 0)) * 100, 2)
                END,
                COALESCE(e.total_earnings_ils, 0),
                NOW()
            FROM clean.teachers t
            LEFT JOIN class_counts cc ON cc.teacher_id = t.teacher_id
            LEFT JOIN class_fact_metrics cf ON cf.teacher_id = t.teacher_id
            LEFT JOIN earnings e ON e.teacher_id = t.teacher_id
            WHERE t.status = 'active'
            """
        )
        cur.execute("SELECT COUNT(*) FROM serve.teacher_performance_profile")
        count = cur.fetchone()[0]
    conn.commit()
    return count



def main() -> None:
    parser = argparse.ArgumentParser(description="Backfill matcher tables from live MySQL into PostgreSQL")
    parser.add_argument("--skip-leads", action="store_true")
    parser.add_argument("--skip-availability", action="store_true")
    parser.add_argument("--skip-holidays", action="store_true")
    parser.add_argument("--skip-subscription-members", action="store_true")
    parser.add_argument("--skip-performance", action="store_true")
    parser.add_argument("--skip-is-trial", action="store_true")
    args = parser.parse_args()

    conn = pg_conn()
    try:
        ensure_is_trial_column(conn)
        results: dict[str, int] = {}
        if not args.skip_is_trial:
            results["is_trial_updates"] = backfill_is_trial(conn)
        if not args.skip_leads:
            results["leads"] = backfill_leads(conn)
        if not args.skip_availability:
            results["teacher_availability"] = backfill_teacher_availability(conn)
        if not args.skip_holidays:
            results["teacher_holidays"] = backfill_teacher_holidays(conn)
        if not args.skip_subscription_members:
            results["subscription_members"] = backfill_subscription_members(conn)
        if not args.skip_performance:
            results["teacher_performance_profile"] = backfill_teacher_performance_profile(conn)
        for key, value in results.items():
            print(f"{key}: {value}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
