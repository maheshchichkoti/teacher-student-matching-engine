"""
Tulkka — Rule-Based Teacher-Student Matching Engine v1.1.0
-----------------------------------------------------------
Spec: Teacher-Student Matching Engine Feature Specification v1.0 (March 2026)

=== v1.1.0 Bug Fixes ===
FIX #1: Subscription mode no longer returns 0 teachers.
         Uses recurring availability instead of trial slots.
FIX #2: Native language hard filter uses `languages_spoken`, not `teaching_languages`.
FIX #3: Retention rate added to performance score (conv 40% + retention 30% + quality 30%).
FIX #4: Day-of-week convention unified: 0=Sunday in BOTH matching_engine & availability_service.
FIX #5: `recurring_slots` added to every TeacherResult in the API response.

DAY-OF-WEEK CONVENTION (canonical):
    0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
    Source: clean.teacher_availability.day_of_week
    Both this file and availability_service.py use this mapping.

Endpoint: POST /match
Run:  uvicorn matching_engine:app --reload --port 5000
Docs: http://localhost:5000/docs
"""

import os
import re
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Any
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from availability_service import AvailabilityService
from csv_repository import CsvRepository
from pathlib import Path

load_dotenv()

app = FastAPI(
    title="Tulkka Matching Engine",
    description="Rule-based teacher-student matching API (Spec v1.0)",
    version="1.1.0",
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_SOURCE = (
    os.getenv("DATA_SOURCE", "csv").strip().lower()
)  # "csv" | "db" — CSV is primary/only source
CSV_DATA_DIR = os.path.join(BASE_DIR, "data")
CSV_REPO: Optional[CsvRepository] = None
if DATA_SOURCE == "csv":
    CSV_REPO = CsvRepository(Path(CSV_DATA_DIR))

# ─────────────────────────────────────────────────────────────
# DB CONFIG
# ─────────────────────────────────────────────────────────────

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "3.124.111.213"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "user": os.getenv("DB_USER", "admin"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "tulkka_live"),
}

# ─────────────────────────────────────────────────────────────
# DAY-OF-WEEK MAPPING  ── canonical, shared by all functions
# FIX #4: 0=Sunday (matches clean.teacher_availability.day_of_week)
# ─────────────────────────────────────────────────────────────
DAY_NAMES = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]  # index 0=Sunday

DAY_MAP = {
    "sunday": "sun",
    "sun": "sun",
    "monday": "mon",
    "mon": "mon",
    "tuesday": "tue",
    "tue": "tue",
    "wednesday": "wed",
    "wed": "wed",
    "thursday": "thu",
    "thu": "thu",
    "friday": "fri",
    "fri": "fri",
    "saturday": "sat",
    "sat": "sat",
}

# Python weekday():  0=Mon … 6=Sun  →  we need our convention
_PY_WEEKDAY_TO_OUR = {0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 0}

MAX_CAPACITY = 20  # fallback when teacher.max_students_capacity is NULL

# Language code normalization (ISO 639-1 codes → full names)
LANGUAGE_CODE_MAP = {
    "HE": "Hebrew",
    "AR": "Arabic",
    "EN": "English",
    "ES": "Spanish",
    "FR": "French",
    "DE": "German",
    "RU": "Russian",
    "PT": "Portuguese",
    "IT": "Italian",
    "ZH": "Chinese",
    "JA": "Japanese",
    "KO": "Korean",
}


def normalize_language(lang: str) -> str:
    """Convert language code to full name, or return as-is if already full name."""
    if not lang:
        return lang
    upper_lang = lang.upper()
    return LANGUAGE_CODE_MAP.get(upper_lang, lang)


# ─────────────────────────────────────────────────────────────
# PYDANTIC MODELS
# ─────────────────────────────────────────────────────────────


class MatchRequest(BaseModel):
    student_id: Optional[int] = None
    questionnaire_id: Optional[int] = Field(
        default=None,
        description="Questionnaire response id (clean.questionnaire_responses.response_id) for analytics logging",
    )
    student_age: Optional[int] = Field(
        default=None, description="Student age for age-range filter"
    )
    english_level: Optional[str] = Field(
        default=None, description="Student CEFR level (A1–C2)"
    )
    target_language: str = Field(
        default="English", description="Language the student wants to learn"
    )
    native_language: Optional[str] = Field(
        default=None, description="Student's mother tongue"
    )
    requires_native_language_teacher: bool = Field(
        default=False,
        description="Hard filter: teacher must speak native language (uses languages_spoken)",
    )
    preferred_days: List[str] = Field(
        ..., description="Preferred lesson days, e.g. ['Sunday','Tuesday']"
    )
    preferred_time_from: str = Field(
        default="16:00", description="Earliest slot time HH:MM"
    )
    preferred_time_to: str = Field(
        default="21:00", description="Latest slot time HH:MM"
    )
    sessions_per_week: int = Field(default=1, description="How many sessions per week")
    mode: str = Field(default="trial", description="'trial' or 'subscription'")
    student_tags: List[str] = Field(default_factory=list)
    student_goals: List[str] = Field(default_factory=list)
    search_option: Optional[str] = Field(
        default=None, description="'earliest_available' or null"
    )
    allow_flexibility_suggestions: bool = Field(default=False)
    # Demo-only: allow adding dummy entities while in CSV mode
    dummy_teacher: Optional[dict[str, Any]] = None
    dummy_student: Optional[dict[str, Any]] = None


class TeacherResult(BaseModel):
    teacher_id: int
    name: str
    teaching_language: str
    languages_spoken: List[str]
    match_score: float
    trial_conversion_rate: float
    retention_rate: float  # FIX #3 — now surfaced in response
    lesson_quality_score: float
    available_slots: List[str]  # trial slots (mode=trial) or empty (mode=subscription)
    recurring_slots: List[str]  # FIX #5 — recurring options always present
    score_breakdown: dict
    explainability: str
    current_students: int
    free_capacity: int
    teacher_tags: List[str]


class MatchResponse(BaseModel):
    student_id: Optional[int]
    student_name: Optional[str]
    student_native_language: Optional[str]
    student_age: Optional[int]
    english_level: Optional[str]
    student_tags: List[str]
    student_goals: List[str]
    mode: str
    preferred_days: List[str]
    preferred_time: str
    sessions_per_week: int
    teachers_found: int
    results: List[TeacherResult]
    flexibility_suggestions: List[str] = Field(default_factory=list)


class TrialFeedbackRequest(BaseModel):
    class_id: int
    student_id: int
    teacher_id: int
    trial_success: Optional[bool] = None
    teacher_match_quality: Optional[int] = Field(default=None, ge=1, le=5)
    student_feedback: Optional[str] = None


class TrialFeedbackResponse(BaseModel):
    feedback_id: int
    status: str


class HealthResponse(BaseModel):
    status: str


# ─────────────────────────────────────────────────────────────
# DB HELPERS
# ─────────────────────────────────────────────────────────────


def get_db():
    """Open and return a new database connection."""
    return psycopg2.connect(**DB_CONFIG)


def q(conn, sql, params=None):
    """Execute SQL and return (columns, [[row], ...])."""
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(sql, params or ())
    rows = cur.fetchall()
    cols = list(rows[0].keys()) if rows else []
    cur.close()
    return cols, [list(row.values()) for row in rows]


def q_execute(conn, sql, params=None):
    cur = conn.cursor()
    cur.execute(sql, params or ())
    conn.commit()
    row = cur.fetchone()
    cur.close()
    return row


def table_has_column(conn, schema: str, table: str, column: str) -> bool:
    _, rows = q(
        conn,
        """
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = %s
          AND table_name = %s
          AND column_name = %s
        LIMIT 1
    """,
        (schema, table, column),
    )
    return bool(rows)


def get_trial_filter_sql(conn, alias: str = "c") -> str:
    qualifier = f"{alias}." if alias else ""
    if table_has_column(conn, "clean", "classes", "is_trial"):
        return (
            f"COALESCE(LOWER(({qualifier}is_trial)::text), '0') IN ('1', 't', 'true')"
        )
    return f"{qualifier}subscription_id IS NULL"


def get_next_date(day_name: str) -> str:
    """Return the next calendar date (YYYY-MM-DD) for a given day name."""
    raw = (day_name or "").strip().lower()
    target = DAY_MAP.get(raw) or (raw[:3] if raw else "sun")
    if target not in DAY_NAMES:
        target = "sun"
    target_idx = DAY_NAMES.index(target)  # 0=Sun … 6=Sat
    today = datetime.utcnow().date()
    # Python weekday: 0=Mon … 6=Sun → convert to our 0=Sun convention
    today_our_idx = _PY_WEEKDAY_TO_OUR[today.weekday()]
    delta = (target_idx - today_our_idx) % 7
    if delta == 0:
        delta = 7  # always return a future date (next occurrence, not today)
    return (today + timedelta(days=delta)).strftime("%Y-%m-%d")


# ─────────────────────────────────────────────────────────────
# BATCH FETCH — all data in one pass per endpoint call
# ─────────────────────────────────────────────────────────────


def fetch_student(conn, student_id: int):
    """Fetch student row with matching-engine fields."""
    goal_expr = (
        "learning_goal::text"
        if table_has_column(conn, "clean", "students", "learning_goal")
        else "NULL::text"
    )
    _, rows = q(
        conn,
        f"""
        SELECT student_id, full_name, native_language, cefr_level, student_age,
               target_language, requires_native_language_teacher, preferred_days,
               preferred_time_start, preferred_time_end, sessions_per_week,
               {goal_expr} AS learning_goal
        FROM clean.students
        WHERE student_id = %s
    """,
        (student_id,),
    )
    if not rows:
        return None
    r = rows[0]
    return {
        "id": r[0],
        "name": r[1],
        "native_language": r[2],
        "student_level": r[3],
        "english_level": r[3],
        "student_age": r[4],
        "target_language": r[5],
        "requires_native_language_teacher": r[6],
        "preferred_days": r[7],
        "preferred_time_start": r[8],
        "preferred_time_end": r[9],
        "sessions_per_week": r[10],
        "student_goals": [r[11]] if r[11] else [],
        "student_tags": [],
    }


def fetch_active_subscription_plan_name(conn, student_id: int) -> Optional[str]:
    """
    Infer recurring lesson duration from the student's active subscription plan.
    Node.js uses `subscription.lesson_min`; our schema stores only `plan_name`, so we parse it.
    """
    if not student_id:
        return None
    _, rows = q(
        conn,
        """
        SELECT plan_name
        FROM clean.subscriptions
        WHERE owner_student_id = %s
          AND status = 'active'
        ORDER BY classes_remaining DESC, updated_at DESC
        LIMIT 1
    """,
        (student_id,),
    )
    return str(rows[0][0]) if rows else None


def fetch_all_teachers(conn):
    """
    Fetch all active teachers with matching-engine fields.
    Returns list of tuples:
      (teacher_id, full_name, teaching_languages, trial_enabled,
       age_min, age_max, teacher_tags, max_students_capacity, trial_priority, languages_spoken)
    """
    _, rows = q(
        conn,
        f"""
        SELECT t.teacher_id,
               t.full_name,
               t.teaching_languages,
               t.trial_enabled,
               t.age_min,
               t.age_max,
               t.teacher_tags,
               t.max_students_capacity,
               t.trial_priority,
               t.languages_spoken
        FROM clean.teachers t
        WHERE t.status = 'active'
        ORDER BY t.teacher_id
    """,
    )
    return rows


def _as_str_list(value) -> list[str]:
    """Normalize PostgreSQL JSONB/TEXT[] values into a Python list[str]."""
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v) for v in value]
    if isinstance(value, tuple):
        return [str(v) for v in value]
    return []


def fetch_all_conversion_rates(conn) -> dict:
    """Per-teacher trial conversion rate (0–100)."""
    trial_filter = get_trial_filter_sql(conn, "c")
    _, rows = q(
        conn,
        f"""
        SELECT c.teacher_id,
               ROUND(
                   LEAST(
                       (
                           COUNT(CASE WHEN l.funnel_stage = 'converted' THEN 1 END)::numeric
                           / NULLIF(COUNT(CASE WHEN l.funnel_stage IN ('demo_done', 'converted') THEN 1 END), 0)
                       ) * 100,
                       100
                   ),
                   1
               ) AS conversion_rate
        FROM clean.classes c
        INNER JOIN analytics.leads l ON c.student_id = l.converted_student_id
        WHERE {trial_filter}
        GROUP BY c.teacher_id
    """,
    )
    return {r[0]: float(r[1] or 0) for r in rows}


def fetch_all_quality_scores(conn) -> dict:
    """Per-teacher average lesson quality (0–100)."""
    _, rows = q(
        conn,
        """
        SELECT teacher_id,
               ROUND(AVG((grammar_score + vocabulary_score + fluency_score) / 3.0), 1) AS quality_score
        FROM analytics.class_facts
        WHERE grammar_score IS NOT NULL
        GROUP BY teacher_id
    """,
    )
    return {r[0]: float(r[1] or 0) for r in rows}


def fetch_teacher_performance_snapshots(conn) -> dict:
    _, rows = q(
        conn,
        """
        SELECT t.teacher_id,
               COALESCE(p.avg_rating * 20, t.avg_rating * 20, 0) AS avg_rating_score,
               COALESCE(p.verification_rate, t.verification_rate, 0) AS verification_rate,
               COALESCE(p.total_classes_taught, t.total_classes_taught, 0) AS total_classes_taught,
               COALESCE(p.student_retention_rate, 0) AS student_retention_rate
        FROM clean.teachers t
        LEFT JOIN serve.teacher_performance_profile p
          ON p.teacher_id = t.teacher_id
        WHERE t.status = 'active'
    """,
    )
    return {
        r[0]: {
            "avg_rating_score": float(r[1] or 0),
            "verification_rate": float(r[2] or 0),
            "total_classes_taught": int(r[3] or 0),
            "student_retention_rate": float(r[4] or 0),
        }
        for r in rows
    }


def fetch_all_trial_counts(conn) -> dict:
    trial_filter = get_trial_filter_sql(conn, "")
    _, rows = q(
        conn,
        f"""
        SELECT teacher_id, COUNT(*) AS total_trials
        FROM clean.classes
        WHERE {trial_filter}
        GROUP BY teacher_id
    """,
    )
    return {r[0]: int(r[1] or 0) for r in rows}


def fetch_all_retention_rates(conn) -> dict:
    """
    Per-teacher retention rate (0–100), sourced from the performance profile
    when available.
    """
    _, rows = q(
        conn,
        """
        SELECT teacher_id,
               ROUND(COALESCE(student_retention_rate, 0), 1)
        FROM serve.teacher_performance_profile
    """,
    )
    return {r[0]: float(r[1] or 0) for r in rows}


def fetch_all_student_counts(conn) -> dict:
    """Per-teacher active student count."""
    _, rows = q(
        conn,
        """
        WITH active_subscriptions AS (
            SELECT subscription_id, owner_student_id
            FROM clean.subscriptions
            WHERE status = 'active'
        ),
        active_subscription_students AS (
            SELECT DISTINCT
                c.teacher_id,
                COALESCE(sm.student_id, s.owner_student_id, c.student_id) AS student_id
            FROM clean.classes c
            JOIN active_subscriptions s
              ON s.subscription_id = c.subscription_id
            LEFT JOIN clean.subscription_members sm
              ON sm.subscription_id = s.subscription_id
             AND sm.status = 'active'
            WHERE c.lifecycle_status IN ('confirmed', 'in_progress', 'completed_raw', 'completed_ai', 'verified')
        ),
        active_non_subscription_students AS (
            SELECT DISTINCT c.teacher_id, c.student_id
            FROM clean.classes c
            WHERE c.subscription_id IS NULL
              AND c.lifecycle_status IN ('confirmed', 'in_progress')
        ),
        active_students AS (
            SELECT teacher_id, student_id FROM active_subscription_students
            UNION
            SELECT teacher_id, student_id FROM active_non_subscription_students
        )
        SELECT teacher_id, COUNT(DISTINCT student_id) AS count
        FROM active_students
        GROUP BY teacher_id
    """,
    )
    return {r[0]: int(r[1] or 0) for r in rows}


def fetch_all_availability(conn, teacher_ids: list) -> dict:
    """
    Fetch structured availability for a list of teachers.
    FIX #4: Uses DAY_NAMES[day_of_week] where index 0=Sunday (canonical).
    Returns: {teacher_id: {day_key: {time_key: True}}}
    """
    if not teacher_ids:
        return {}
    placeholders = ",".join(["%s"] * len(teacher_ids))
    _, rows = q(
        conn,
        f"""
        SELECT teacher_id, day_of_week, start_time, end_time
        FROM clean.teacher_availability
        WHERE teacher_id IN ({placeholders}) AND is_active = true
        ORDER BY teacher_id, day_of_week, start_time
    """,
        tuple(teacher_ids),
    )

    result: dict = {}
    for row in rows:
        uid, day_idx, start_time, end_time = row[0], row[1], row[2], row[3]

        # FIX #4: Use canonical DAY_NAMES (0=Sun)
        if day_idx is None or day_idx >= len(DAY_NAMES):
            continue
        day_key = DAY_NAMES[day_idx]

        start_str = (
            start_time.strftime("%H:%M")
            if hasattr(start_time, "strftime")
            else str(start_time)[:5]
        )
        end_str = (
            end_time.strftime("%H:%M")
            if hasattr(end_time, "strftime")
            else str(end_time)[:5]
        )

        if uid not in result:
            result[uid] = {}
        if day_key not in result[uid]:
            result[uid][day_key] = {}

        # Expand the time window into 30-minute slots (matches Node.js backend) (FIX #2)
        def to_min(t):
            h, m = map(int, t.split(":"))
            return h * 60 + m

        cur = to_min(start_str)
        end_m = to_min(end_str)
        while cur + 30 <= end_m:
            hh, mm = divmod(cur, 60)
            result[uid][day_key][f"{hh:02d}:{mm:02d}"] = True
            cur += 30

    return result


# ─────────────────────────────────────────────────────────────
# MATCHING / SCORING LOGIC
# ─────────────────────────────────────────────────────────────


def _to_minutes(t: str) -> int:
    h, m = t.split(":")
    return int(h) * 60 + int(m)


def _normalize_hhmm(value: Any, field_name: str) -> str:
    """
    Normalize times like "8:00" → "08:00" so string comparisons stay correct.
    Raises ValueError for invalid inputs.
    """
    if value is None:
        raise ValueError(f"{field_name} is required")
    s = str(value).strip()
    if ":" not in s:
        raise ValueError(f"{field_name} must be HH:MM")
    h_s, m_s = s.split(":", 1)
    h = int(h_s)
    m = int(m_s)
    if not (0 <= h <= 23 and 0 <= m <= 59):
        raise ValueError(f"{field_name} must be within 00:00–23:59")
    return f"{h:02d}:{m:02d}"


def _minutes_to_hhmm(minutes: int) -> str:
    hh, mm = divmod(int(minutes), 60)
    return f"{hh:02d}:{mm:02d}"


def infer_lesson_duration_minutes(
    plan_name: Optional[str], default_minutes: int = 30
) -> int:
    """
    Parse a duration in minutes from plan_name like:
      "Up to 4 lessons per month / 25-minute lesson"
      "45-min course" (best-effort)
    """
    if not plan_name:
        return int(default_minutes)
    s = str(plan_name).lower()
    m = re.search(r"(\d+)\s*[-]?\s*minute", s)
    if not m:
        m = re.search(r"(\d+)\s*min\b", s)
    if not m:
        return int(default_minutes)
    try:
        minutes = int(m.group(1))
    except Exception:
        return int(default_minutes)
    # Keep it sane (prevents weird parsing from producing huge durations).
    if minutes <= 0 or minutes > 180:
        return int(default_minutes)
    return minutes


def get_matching_slots(
    availability: dict, preferred_days: list, time_from: str, time_to: str
) -> list:
    """Return list of 'Day HH:MM' strings within the preferred window."""
    from_min = _to_minutes(time_from)
    to_min = _to_minutes(time_to)
    slots = []
    for day in preferred_days:
        day_l = str(day).strip().lower()
        key = DAY_MAP.get(day_l) or (day_l[:3] if day_l else "")
        if key not in DAY_NAMES:
            continue
        for time_str, available in availability.get(key, {}).items():
            if available and from_min <= _to_minutes(time_str) <= to_min:
                slots.append(f"{day.capitalize()} {time_str}")
    return slots


def _normalize_preferred_days(preferred_days: list[str]) -> list[str]:
    normalized = []
    for day in preferred_days or []:
        for part in str(day).split(","):
            cleaned = part.strip().lower()
            mapped = DAY_MAP.get(cleaned, cleaned[:3] if cleaned else "")
            if mapped and mapped in DAY_NAMES and mapped not in normalized:
                normalized.append(mapped)
    return normalized


def _build_flexibility_suggestions(
    results: list[dict], preferred_days: list[str], time_from: str, time_to: str
) -> list[str]:
    suggestions = []
    current_count = len(results)
    if current_count:
        return suggestions
    from_min = _to_minutes(time_from)
    to_min = _to_minutes(time_to)
    if to_min - from_min >= 60:
        suggestions.append(
            "Try extending the preferred time range by 1 hour later to widen the teacher pool."
        )
    if len(preferred_days) < 3:
        suggestions.append("Add one more preferred day to increase matching coverage.")
    if not suggestions:
        suggestions.append(
            "Relax one hard preference to surface more eligible teachers."
        )
    return suggestions


def compute_student_fit(student_prefs: dict, teacher_profile: dict) -> float:
    """
    Student Fit (30%): age/level/tag/goal alignment using tag-based logic only.
    """
    # Normalize tag casing once; CSV/ETL may introduce inconsistent capitalization.
    teacher_tags_lower = {
        str(tag).lower() for tag in (teacher_profile.get("teacher_tags") or [])
    }
    student_tags = {
        str(tag).lower() for tag in (student_prefs.get("student_tags") or [])
    }
    student_goals = {
        str(goal).lower() for goal in (student_prefs.get("student_goals") or [])
    }
    age = student_prefs.get("student_age")
    english_level = (student_prefs.get("english_level") or "").upper()

    age_fit = 0.5
    if age is not None:
        if age <= 12 and "kids_friendly" in teacher_tags_lower:
            age_fit = 1.0
        elif age >= 16 and "business_english" in teacher_tags_lower:
            age_fit = 1.0
        elif (
            age <= 14
            and "kids_friendly" not in teacher_tags_lower
            and "business_english" in teacher_tags_lower
        ):
            age_fit = 0.3

    level_fit = 0.5
    if english_level:
        if english_level in {"A1", "A2"} and "beginner_friendly" in teacher_tags_lower:
            level_fit = 1.0
        elif english_level in {"B2", "C1", "C2"} and "exam_prep" in teacher_tags_lower:
            level_fit = 1.0
        elif english_level in {"A1", "A2"} and "exam_prep" in teacher_tags_lower:
            level_fit = 0.3

    tag_fit = 0.5
    if student_tags:
        overlap = len(student_tags & teacher_tags_lower)
        tag_fit = min(overlap / max(len(student_tags), 1), 1.0) if overlap else 0.3

    goal_fit = 0.5
    if student_goals:
        goal_map = {
            "business": {"business_english", "professional", "exam_prep"},
            "travel": {"conversation", "conversation_teacher", "energetic"},
            "academic": {"grammar_specialist", "exam_prep", "beginner_friendly"},
            "conversation": {"conversation", "conversation_teacher", "energetic"},
            "exam": {"exam_prep", "grammar_specialist"},
        }
        matched = 0
        for goal in student_goals:
            for keyword, mapped_tags in goal_map.items():
                if keyword in goal and teacher_tags_lower.intersection(mapped_tags):
                    matched += 1
                    break
        goal_fit = min(matched / max(len(student_goals), 1), 1.0) if matched else 0.3

    return (age_fit + level_fit + tag_fit + goal_fit) / 4.0


def compute_score(
    student_prefs: dict,
    teacher_profile: dict,
    slots: list,
    conv_rate: float,
    retention_rate: float,  # FIX #3 — now a real parameter
    quality_score: float,
    current_students: int,
    preferred_days: list,
    trial_count: int = 0,
    avg_rating_score: float = 0.0,
    verification_rate: float = 0.0,
    total_classes_taught: int = 0,
) -> float:
    """
    Spec weights:
      30% Student Fit       — age, level, tag overlap, and goal alignment
      25% Availability Fit  — trial slots within preferred window
      20% Performance       — conv_rate(40%) + retention(30%) + lesson_quality(30%)
      15% Recurring Compat  — preferred days covered by availability
      10% Capacity          — free slots vs max_students
    """
    student_fit = compute_student_fit(student_prefs, teacher_profile)
    avail_fit = min(len(slots) / 5.0, 1.0)

    # FIX #3: Blend conversion, retention, and quality into performance
    performance = (
        (conv_rate / 100.0) * 0.40
        + (retention_rate / 100.0) * 0.30
        + (quality_score / 100.0) * 0.30
    )

    days_covered = len({s.split(" ")[0] for s in slots})
    recurring = min(days_covered / max(len(preferred_days), 1), 1.0)

    max_cap = teacher_profile.get("max_students") or MAX_CAPACITY
    capacity = min(max(max_cap - current_students, 0) / max_cap, 1.0)
    evidence_strength = min(max(trial_count, total_classes_taught / 5.0, 0) / 12.0, 1.0)
    rating_component = min(avg_rating_score / 100.0, 1.0)
    verification_component = min(verification_rate / 100.0, 1.0)
    quality_component = min(quality_score / 100.0, 1.0)
    retention_component = min(retention_rate / 100.0, 1.0)
    reliability_bonus = (
        rating_component * 0.03
        + verification_component * 0.03
        + quality_component * 0.04
        + retention_component * 0.05
    ) * evidence_strength
    # Top-1 calibration: if a teacher has weak evidence, dampen their score more
    # aggressively so the shortlist is still broad, but the #1 pick is less noisy.
    # evidence_strength in [0..1]; when < 0.15 apply a penalty up to ~6 points.
    sparse_threshold = 0.15
    if evidence_strength < sparse_threshold:
        sparse_data_penalty = (
            0.06 * (sparse_threshold - evidence_strength) / sparse_threshold
        )
    else:
        sparse_data_penalty = 0.0
    slot_breadth_bonus = min(len(slots), 8) / 8.0 * 0.04

    total = (
        student_fit * 0.30
        + avail_fit * 0.25
        + performance * 0.20
        + recurring * 0.15
        + capacity * 0.10
    )
    final_score = total + reliability_bonus + slot_breadth_bonus - sparse_data_penalty
    return round(min(max(final_score, 0.0), 1.0) * 100, 1)


def _slot_tokens(mode: str, teacher_result: dict[str, Any]) -> set[str]:
    """
    Convert available slot strings (e.g. 'Mon 18:00') into comparison tokens.
    Used only for diversity selection; does not affect hard eligibility.
    """
    if mode == "trial":
        raw = teacher_result.get("available_slots") or []
    else:
        raw = teacher_result.get("recurring_slots") or []
    tokens: set[str] = set()
    for s in raw:
        try:
            parts = str(s).strip().split(" ", 1)
            if len(parts) != 2:
                continue
            day, time_str = parts[0], parts[1]
            tokens.add(f"{day.lower()[:3]} {time_str}")
        except Exception:
            continue
    return tokens


def _tag_tokens(teacher_result: dict[str, Any]) -> set[str]:
    return {
        str(t).strip().lower()
        for t in (teacher_result.get("teacher_tags") or [])
        if str(t).strip()
    }


def _select_diverse_shortlist(
    results: list[dict[str, Any]],
    mode: str,
    k: int = 5,
) -> list[dict[str, Any]]:
    """
    Post-sort shortlist governance.
    Picks the highest-ranked teacher first, then iteratively chooses the next teacher
    with the best tradeoff between score and diversity (tags + slot patterns).
    """
    if not results:
        return []

    selected: list[dict[str, Any]] = []
    candidates = list(results)

    while candidates and len(selected) < k:
        if not selected:
            selected.append(candidates.pop(0))
            continue

        selected_tag_sets = [_tag_tokens(t) for t in selected]
        selected_slot_sets = [_slot_tokens(mode, t) for t in selected]

        best_idx = None
        best_adjusted = None
        for idx, cand in enumerate(candidates):
            cand_tags = _tag_tokens(cand)
            cand_slots = _slot_tokens(mode, cand)

            # Tag diversity: use Jaccard overlap vs any already selected teacher.
            tag_overlap_max = 0.0
            for tset in selected_tag_sets:
                if not cand_tags or not tset:
                    continue
                inter = len(cand_tags & tset)
                union = len(cand_tags | tset) or 1
                tag_overlap_max = max(tag_overlap_max, inter / union)

            # Slot diversity: overlap of day+time tokens.
            slot_overlap_max = 0.0
            for sset in selected_slot_sets:
                if not cand_slots or not sset:
                    continue
                inter = len(cand_slots & sset)
                denom = len(cand_slots) or 1
                slot_overlap_max = max(slot_overlap_max, inter / denom)

            # Penalize similarity, keep score as the primary driver.
            adjusted = float(cand.get("match_score") or 0.0) - (
                15.0 * tag_overlap_max + 8.0 * slot_overlap_max
            )

            if best_adjusted is None or adjusted > best_adjusted:
                best_adjusted = adjusted
                best_idx = idx

        if best_idx is None:
            break
        selected.append(candidates.pop(best_idx))

    return selected


def _log_teacher_recommendations(
    conn,
    questionnaire_id: int,
    top: list[dict[str, Any]],
) -> None:
    """
    Closed-loop analytics: store the returned shortlist per questionnaire.

    Uses existing Postgres table: `clean.teacher_recommendations`.
    We insert only teachers not already present for the questionnaire to reduce duplicates.
    """
    try:
        _, existing_rows = q(
            conn,
            """
            SELECT teacher_id
            FROM clean.teacher_recommendations
            WHERE questionnaire_id = %s
            """,
            (questionnaire_id,),
        )
        existing: set[int] = set()
        for r in existing_rows:
            if not r or r[0] is None:
                continue
            existing.add(int(r[0]))

        for idx, tr in enumerate(top, start=1):
            tid_raw = tr.get("teacher_id")
            if tid_raw is None:
                continue
            tid = int(tid_raw)
            if tid in existing:
                continue
            reasoning = str(tr.get("explainability") or "")
            match_score = float(tr.get("match_score") or 0.0)

            q_execute(
                conn,
                """
                INSERT INTO clean.teacher_recommendations (
                    questionnaire_id,
                    teacher_id,
                    match_score,
                    rank,
                    reasoning
                )
                VALUES (%s, %s, %s, %s, %s)
                """,
                (questionnaire_id, tid, round(match_score, 2), idx, reasoning),
            )
    except Exception as exc:
        # Analytics logging must never break matching responses.
        print(f"[WARN] Recommendation analytics logging failed: {exc}")


def compute_load_balancing_adjustment(
    current_students: int, max_students: int, trial_count: int
) -> float:
    max_cap = max(max_students or MAX_CAPACITY, 1)
    utilization = current_students / max_cap
    adjustment = 0.0
    if utilization >= 0.90:
        adjustment -= 8.0
    elif utilization >= 0.75:
        adjustment -= 5.0
    elif utilization >= 0.60:
        adjustment -= 2.5
    elif utilization <= 0.20:
        adjustment += 3.0
    elif utilization <= 0.40:
        adjustment += 1.5
    if trial_count <= 3 and utilization <= 0.50:
        adjustment += 1.5
    return adjustment


def compute_priority_adjustment(priority: str) -> float:
    if priority == "high":
        return 4.0
    if priority == "low":
        return -4.0
    return 0.0


def compute_personalization_adjustment(
    student_prefs: dict, teacher_profile: dict
) -> float:
    teacher_tags = {
        str(tag).lower() for tag in (teacher_profile.get("teacher_tags") or [])
    }
    age = student_prefs.get("student_age")
    english_level = (student_prefs.get("english_level") or "").upper()
    adjustment = 0.0

    if age is not None:
        if age <= 12:
            if "kids_friendly" in teacher_tags:
                adjustment += 4.0
            if "business_english" in teacher_tags:
                adjustment -= 3.0
        elif age >= 15:
            if (
                "business_english" in teacher_tags
                or "exam_prep" in teacher_tags
                or "professional" in teacher_tags
            ):
                adjustment += 4.0
            if (
                "kids_friendly" in teacher_tags
                and "business_english" not in teacher_tags
            ):
                adjustment -= 3.0

    if english_level in {"A1", "A2"}:
        if "beginner_friendly" in teacher_tags or "kids_friendly" in teacher_tags:
            adjustment += 3.0
        if "exam_prep" in teacher_tags and "beginner_friendly" not in teacher_tags:
            adjustment -= 2.0
    elif english_level in {"B1", "B2", "C1", "C2"}:
        if (
            "exam_prep" in teacher_tags
            or "business_english" in teacher_tags
            or "professional" in teacher_tags
        ):
            adjustment += 3.0

    return adjustment


# ─────────────────────────────────────────────────────────────
# API ENDPOINTS
# ─────────────────────────────────────────────────────────────


@app.post("/match", response_model=MatchResponse)
async def match(request: MatchRequest):
    """
    Match teachers to a student.

    3-step pipeline (Spec §3):
      1. Hard Filters  — language, age, mode, disabled teachers
      2. Availability  — trial slots (mode=trial) OR recurring slots (mode=subscription)
      3. Scoring       — 30/25/20/15/10 weighted score

    FIX #1: Subscription mode uses recurring availability and no longer returns 0 results.
    FIX #2: Native language filter uses `languages_spoken`, not `teaching_languages`.
    FIX #5: `recurring_slots` returned for every matched teacher.
    """
    if not request.preferred_days:
        raise HTTPException(status_code=400, detail="preferred_days is required")
    if request.mode not in ("trial", "subscription"):
        raise HTTPException(
            status_code=400, detail="mode must be 'trial' or 'subscription'"
        )
    normalized_days = _normalize_preferred_days(request.preferred_days)
    if not normalized_days:
        raise HTTPException(
            status_code=400, detail="preferred_days must contain valid day values"
        )
    request.preferred_days = normalized_days

    # Normalize/validate time bounds so comparisons are correct (e.g. "8:00" vs "08:00").
    try:
        request.preferred_time_from = _normalize_hhmm(
            request.preferred_time_from, "preferred_time_from"
        )
        request.preferred_time_to = _normalize_hhmm(
            request.preferred_time_to, "preferred_time_to"
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if _to_minutes(request.preferred_time_from) > _to_minutes(
        request.preferred_time_to
    ):
        raise HTTPException(
            status_code=400, detail="preferred_time_from must be <= preferred_time_to"
        )

    # CSV mode: allow injecting dummy teacher/student for demo iteration
    if DATA_SOURCE == "csv" and CSV_REPO:
        if request.dummy_teacher:
            CSV_REPO.add_dummy_teacher(request.dummy_teacher)
        if request.dummy_student:
            CSV_REPO.add_dummy_student(request.dummy_student)

    conn = get_db() if DATA_SOURCE == "db" else None
    try:
        avail_service = AvailabilityService(conn) if conn else None

        # Resolve student data
        if DATA_SOURCE == "db":
            student = (
                fetch_student(conn, request.student_id) if request.student_id else None
            )
        else:
            student = (
                CSV_REPO.get_student(request.student_id)
                if (CSV_REPO and request.student_id)
                else None
            )
        student_age = request.student_age or (
            student.get("student_age") if student else None
        )
        english_level = (
            request.english_level
            or (student.get("english_level") if student else None)
            or (student.get("cefr_level") if student else None)
        )
        native_language_raw = request.native_language or (
            student.get("native_language") if student else None
        )
        native_language = (
            normalize_language(native_language_raw) if native_language_raw else None
        )
        requires_native = request.requires_native_language_teacher or (
            student.get("requires_native_language_teacher") if student else False
        )
        student_tags = (
            request.student_tags
            or (student.get("student_tags") if student else [])
            or []
        )
        student_goals = (
            request.student_goals
            or (student.get("student_goals") if student else [])
            or []
        )

        student_prefs = {
            "student_age": student_age,
            "english_level": english_level,
            "student_tags": student_tags,
            "student_goals": student_goals,
        }

        # Recurring lesson duration:
        # Node.js uses `subscription.lesson_min || 60`. Our schema stores only `plan_name`,
        # so we parse it (best-effort) and default to 60.
        lesson_duration_minutes = 60
        # Recurring slots are computed for both `trial` and `subscription` modes (for scoring),
        # so we must infer lesson duration whenever a `student_id` is available.
        if request.student_id:
            plan_name: Optional[str] = None
            if DATA_SOURCE == "db":
                plan_name = fetch_active_subscription_plan_name(
                    conn, request.student_id
                )
            else:
                # Optional (CSV might not include subscriptions for older dumps)
                plan_name = (
                    CSV_REPO.get_best_active_subscription_plan_name_for_owner(
                        request.student_id
                    )
                    if CSV_REPO
                    else None
                )
            lesson_duration_minutes = infer_lesson_duration_minutes(
                plan_name, default_minutes=60
            )

        # ── Step 1: Hard Filters ──────────────────────────────────
        if DATA_SOURCE == "db":
            all_teachers = fetch_all_teachers(conn)
            teacher_rows = all_teachers
        else:
            teacher_rows = []
            for t in CSV_REPO.get_teachers_active() if CSV_REPO else []:
                teacher_rows.append(
                    (
                        int(t["teacher_id"]),
                        t.get("full_name"),
                        t.get("teaching_languages"),
                        bool(t.get("trial_enabled", True)),
                        t.get("age_min"),
                        t.get("age_max"),
                        t.get("teacher_tags"),
                        t.get("max_students_capacity"),
                        t.get("trial_priority"),
                        t.get("languages_spoken"),
                    )
                )
        eligible = []

        for row in teacher_rows:
            (
                tid,
                name,
                teaching_langs,
                trial_enabled,
                age_min,
                age_max,
                tags,
                capacity,
                priority,
                languages_spoken,
            ) = row

            teaching_langs_list = _as_str_list(teaching_langs)
            languages_spoken_list = _as_str_list(languages_spoken)
            tags_list = _as_str_list(tags)

            # Mode filter
            if request.mode == "trial" and not trial_enabled:
                continue

            # Disabled teacher
            if priority == "disabled":
                continue

            # Age range filter
            if student_age:
                if age_min is not None and student_age < age_min:
                    continue
                if age_max is not None and student_age > age_max:
                    continue

            # Teacher must be able to TEACH the target language
            if request.target_language not in teaching_langs_list:
                continue

            # FIX #2: Native language check uses `languages_spoken`, not `teaching_languages`
            if requires_native and native_language:
                if native_language not in languages_spoken_list:
                    continue

            eligible.append(
                (
                    tid,
                    name,
                    teaching_langs_list,
                    languages_spoken_list,
                    tags_list,
                    capacity,
                    priority,
                )
            )

        if not eligible:
            return _empty_response(
                request, student, student_age, english_level, native_language
            )

        teacher_ids = [t[0] for t in eligible]

        if DATA_SOURCE == "db":
            conv_map = fetch_all_conversion_rates(conn)
            retention_map = fetch_all_retention_rates(conn)  # FIX #3
            qual_map = fetch_all_quality_scores(conn)
            perf_map = fetch_teacher_performance_snapshots(conn)
            trial_map = fetch_all_trial_counts(conn)
            stud_map = fetch_all_student_counts(conn)
            avail_map = fetch_all_availability(conn, teacher_ids)
        else:
            conv_map = CSV_REPO.conversion_rate_by_teacher() if CSV_REPO else {}
            retention_map = CSV_REPO.retention_rate_by_teacher() if CSV_REPO else {}
            qual_map = CSV_REPO.quality_score_by_teacher() if CSV_REPO else {}
            perf_map = {}
            trial_map = {}
            stud_map = CSV_REPO.current_students_by_teacher() if CSV_REPO else {}
            # Build availability matrix from teacher_availability.csv rows
            avail_map = {}
            if CSV_REPO:
                for tid in teacher_ids:
                    avail_map[tid] = {}
                    for r in CSV_REPO.get_teacher_availability_rows(tid):
                        day_idx = int(r.get("day_of_week") or 0)
                        if 0 <= day_idx < len(DAY_NAMES):
                            day_key = DAY_NAMES[day_idx]
                        else:
                            continue
                        start = str(r.get("start_time") or "")[:5]
                        end = str(r.get("end_time") or "")[:5]
                        if not start or not end:
                            continue

                        def to_min(t):
                            h, m = map(int, t.split(":"))
                            return h * 60 + m

                        cur = to_min(start)
                        end_m = to_min(end)
                        avail_map[tid].setdefault(day_key, {})
                        while cur + 30 <= end_m:
                            hh, mm = divmod(cur, 60)
                            avail_map[tid][day_key][f"{hh:02d}:{mm:02d}"] = True
                            cur += 30

        # ── Steps 2 + 3: Availability + Scoring ──────────────────
        results = []

        for (
            tid,
            name,
            teaching_langs_list,
            languages_spoken_list,
            tags_list,
            capacity,
            priority,
        ) in eligible:

            availability = avail_map.get(tid, {})

            # --- Trial slots (used for mode=trial AND as supplementary for score) ---
            trial_slots: list[str] = []
            if request.mode == "trial":
                for day in request.preferred_days:
                    try:
                        date = get_next_date(day)
                        if DATA_SOURCE == "db":
                            assert avail_service is not None
                            raw = avail_service.get_trial_availability(tid, date, "UTC")
                        else:
                            # CSV mode: derive trial slots from recurring availability windows, then block conflicts/holidays
                            raw = []
                            day_l = str(day).strip().lower()
                            day_key = DAY_MAP.get(day_l) or (day_l[:3] if day_l else "")
                            if day_key not in DAY_NAMES:
                                continue
                            # Build day start/end in UTC
                            utc_date = datetime.strptime(date, "%Y-%m-%d").replace(
                                tzinfo=timezone.utc
                            )
                            utc_start = utc_date.replace(
                                hour=0, minute=0, second=0, microsecond=0
                            )
                            utc_end = utc_date.replace(
                                hour=23, minute=59, second=59, microsecond=999999
                            )
                            # Prepare conflicts
                            conflicts = (
                                CSV_REPO.get_classes_for_teacher_between(
                                    tid, utc_start, utc_end
                                )
                                if CSV_REPO
                                else []
                            )
                            holidays = (
                                CSV_REPO.get_teacher_holidays_rows(tid)
                                if CSV_REPO
                                else []
                            )

                            # Build holiday intervals for this specific date (UTC).
                            # This avoids false positives by respecting `full_day`, `start_time`, and `end_time`.
                            holiday_intervals = []
                            for h in holidays:
                                h_date = str(h.get("holiday_date") or "")[:10]
                                if h_date != date:
                                    continue
                                full_day_val = h.get("full_day")
                                full_day = (
                                    isinstance(full_day_val, bool)
                                    and full_day_val
                                    or str(full_day_val).strip().lower()
                                    in {"true", "t", "1", "yes", "y"}
                                )
                                start_t = h.get("start_time")
                                end_t = h.get("end_time")

                                if full_day or not start_t or not end_t:
                                    holiday_intervals.append(
                                        (utc_date, utc_date + timedelta(days=1))
                                    )
                                    continue

                                start_s = str(start_t).strip()[:5]
                                end_s = str(end_t).strip()[:5]
                                try:
                                    hh_s, mm_s = map(int, start_s.split(":", 1))
                                    hh_e, mm_e = map(int, end_s.split(":", 1))
                                except Exception:
                                    holiday_intervals.append(
                                        (utc_date, utc_date + timedelta(days=1))
                                    )
                                    continue

                                hs = utc_date.replace(
                                    hour=hh_s, minute=mm_s, second=0, microsecond=0
                                )
                                he = utc_date.replace(
                                    hour=hh_e, minute=mm_e, second=0, microsecond=0
                                )
                                if he <= hs:
                                    he = hs + timedelta(days=1)
                                holiday_intervals.append((hs, he))

                            # Generate 25-min trial slots from the availability keys only.
                            # In CSV mode, `availability` is already expanded into 30-minute blocks,
                            # so scanning the whole day (288 iterations/teacher/day) is unnecessary
                            # and is the main performance bottleneck.
                            for time_key in sorted(availability.get(day_key, {}).keys()):
                                # time_key is 'HH:MM' and comparisons are safe after normalization
                                if not (
                                    request.preferred_time_from
                                    <= time_key
                                    <= request.preferred_time_to
                                ):
                                    continue

                                hh, mm = map(int, time_key.split(":", 1))
                                slot_start = utc_date.replace(
                                    hour=hh,
                                    minute=mm,
                                    second=0,
                                    microsecond=0,
                                )
                                slot_end = slot_start + timedelta(minutes=25)

                                # Preserve original grid constraint:
                                # only keep slots whose end lands on a 5-min boundary.
                                if slot_end.minute % 5 != 0:
                                    continue

                                # holiday block (full day if `full_day`, otherwise time-range overlap)
                                holiday_blocked = False
                                for hs, he in holiday_intervals:
                                    if slot_start < he and slot_end > hs:
                                        holiday_blocked = True
                                        break
                                if holiday_blocked:
                                    continue

                                # class conflict
                                blocked = False
                                for c in conflicts:
                                    ms = c["meeting_start"]
                                    me = c["meeting_end"]
                                    if slot_start < me and slot_end > ms:
                                        blocked = True
                                        break
                                if blocked:
                                    continue

                                trial_slots.append(f"{day.capitalize()} {time_key}")
                    except Exception as exc:
                        print(f"[WARN] Trial availability error teacher={tid}: {exc}")

                if not trial_slots:
                    continue  # FIX #1 note: only skip for trial mode

            # --- Recurring slots — always computed (FIX #1 + FIX #5) ---
            recurring_slots: list[str] = []
            for day in request.preferred_days:
                day_l = str(day).strip().lower()
                day_key = DAY_MAP.get(day_l) or (day_l[:3] if day_l else "")
                if day_key not in DAY_NAMES:
                    continue
                # Choose the first recurring slot time inside the preferred window from the recurring calendar.
                candidate_time = None
                for t_str in sorted(availability.get(day_key, {}).keys()):
                    if (
                        request.preferred_time_from
                        <= t_str
                        <= request.preferred_time_to
                    ):
                        candidate_time = t_str
                        break
                if not candidate_time:
                    continue
                try:
                    if DATA_SOURCE == "db":
                        assert avail_service is not None
                        recurring_raw = avail_service.get_recurring_availability(
                            tid,
                            day_key,
                            candidate_time,
                            weeks=4,
                            lesson_duration_minutes=lesson_duration_minutes,
                        )
                    else:
                        # CSV mode: recurring is valid if teacher has the slot and no class/holiday conflicts for next 4 occurrences
                        recurring_raw = []
                        occurrences = []
                        today = datetime.now(timezone.utc)
                        python_weekday_map = {
                            "mon": 0,
                            "tue": 1,
                            "wed": 2,
                            "thu": 3,
                            "fri": 4,
                            "sat": 5,
                            "sun": 6,
                        }
                        target_weekday = python_weekday_map[day_key]
                        days_ahead = target_weekday - today.weekday()
                        if days_ahead <= 0:
                            days_ahead += 7
                        hour, minute = map(int, candidate_time.split(":"))
                        first = (today + timedelta(days=days_ahead)).replace(
                            hour=hour, minute=minute, second=0, microsecond=0
                        )
                        for i in range(4):
                            occurrences.append(first + timedelta(weeks=i))
                        holidays = (
                            CSV_REPO.get_teacher_holidays_rows(tid) if CSV_REPO else []
                        )

                        required_slots = max(
                            1, (int(lesson_duration_minutes) + 29) // 30
                        )
                        start_minutes = _to_minutes(candidate_time)

                        # Build holiday intervals only for the 4 occurrence dates.
                        occurrence_dates = {o.strftime("%Y-%m-%d") for o in occurrences}
                        holiday_intervals = []
                        for h in holidays:
                            h_date = str(h.get("holiday_date") or "")[:10]
                            if h_date not in occurrence_dates:
                                continue
                            full_day_val = h.get("full_day")
                            full_day = (
                                isinstance(full_day_val, bool)
                                and full_day_val
                                or str(full_day_val).strip().lower()
                                in {"true", "t", "1", "yes", "y"}
                            )
                            start_t = h.get("start_time")
                            end_t = h.get("end_time")

                            base = datetime.strptime(h_date, "%Y-%m-%d").replace(
                                tzinfo=timezone.utc
                            )
                            if full_day or not start_t or not end_t:
                                holiday_intervals.append(
                                    (base, base + timedelta(days=1))
                                )
                                continue

                            start_s = str(start_t).strip()[:5]
                            end_s = str(end_t).strip()[:5]
                            try:
                                hh_s, mm_s = map(int, start_s.split(":", 1))
                                hh_e, mm_e = map(int, end_s.split(":", 1))
                            except Exception:
                                holiday_intervals.append(
                                    (base, base + timedelta(days=1))
                                )
                                continue

                            hs = base.replace(
                                hour=hh_s, minute=mm_s, second=0, microsecond=0
                            )
                            he = base.replace(
                                hour=hh_e, minute=mm_e, second=0, microsecond=0
                            )
                            if he <= hs:
                                he = hs + timedelta(days=1)
                            holiday_intervals.append((hs, he))

                        for occ in occurrences:
                            occ_end = occ + timedelta(
                                minutes=int(lesson_duration_minutes)
                            )
                            ok = True

                            # Ensure teacher is available for all consecutive 30-minute blocks.
                            for i in range(required_slots):
                                slot_time_i = _minutes_to_hhmm(start_minutes + (i * 30))
                                if not availability.get(day_key, {}).get(slot_time_i):
                                    ok = False
                                    break

                            # Holiday conflict for the whole lesson window.
                            if ok:
                                for hs, he in holiday_intervals:
                                    if occ < he and occ_end > hs:
                                        ok = False
                                        break

                            conflicts = (
                                CSV_REPO.get_classes_for_teacher_between(
                                    tid,
                                    occ - timedelta(minutes=1),
                                    occ_end + timedelta(minutes=1),
                                )
                                if CSV_REPO
                                else []
                            )
                            for c in conflicts:
                                if (
                                    occ < c["meeting_end"]
                                    and occ_end > c["meeting_start"]
                                ):
                                    ok = False
                                    break
                            recurring_raw.append({"available": ok})
                    if recurring_raw and all(r.get("available") for r in recurring_raw):
                        recurring_slots.append(
                            f"{day_key.capitalize()} {candidate_time}"
                        )
                except Exception as exc:
                    print(f"[WARN] Recurring availability error teacher={tid}: {exc}")

            # FIX #1: For subscription mode, require at least one recurring slot
            if request.mode == "subscription" and not recurring_slots:
                continue
            # Spec §2 Trial mode: must have both a trial slot AND a viable recurring option after the trial
            if request.mode == "trial" and not recurring_slots:
                continue

            # Slots used for scoring depend on mode
            score_slots = trial_slots if request.mode == "trial" else recurring_slots

            conv_rate = conv_map.get(tid, 0.0)
            retention_rate = retention_map.get(tid, 0.0)
            quality_score = qual_map.get(tid, 0.0)
            perf_snapshot = perf_map.get(tid, {})
            avg_rating_score = perf_snapshot.get("avg_rating_score", 0.0)
            verification_rate = perf_snapshot.get("verification_rate", 0.0)
            total_classes_taught = perf_snapshot.get("total_classes_taught", 0)
            trial_count = trial_map.get(tid, 0)
            current_stud = stud_map.get(tid, 0)
            max_cap = capacity or MAX_CAPACITY

            teacher_profile = {
                "max_students": max_cap,
                "teacher_tags": tags_list,
            }

            score = compute_score(
                student_prefs=student_prefs,
                teacher_profile=teacher_profile,
                slots=score_slots,
                conv_rate=conv_rate,
                retention_rate=retention_rate,
                quality_score=quality_score,
                current_students=current_stud,
                preferred_days=request.preferred_days,
                trial_count=trial_count,
                avg_rating_score=avg_rating_score,
                verification_rate=verification_rate,
                total_classes_taught=total_classes_taught,
            )

            load_balancing_adjustment = compute_load_balancing_adjustment(
                current_students=current_stud,
                max_students=max_cap,
                trial_count=trial_count,
            )
            priority_adjustment = compute_priority_adjustment(priority)
            personalization_adjustment = compute_personalization_adjustment(
                student_prefs, teacher_profile
            )
            score = max(
                min(
                    score
                    + load_balancing_adjustment
                    + priority_adjustment
                    + personalization_adjustment,
                    100.0,
                ),
                0.0,
            )

            # Explainability for assisted ops (trust)
            student_fit = compute_student_fit(student_prefs, teacher_profile)
            avail_fit = min(len(score_slots) / 5.0, 1.0)
            perf_component = (
                (conv_rate / 100.0) * 0.40
                + (retention_rate / 100.0) * 0.30
                + (quality_score / 100.0) * 0.30
            )
            days_covered = len({s.split(" ")[0].lower()[:3] for s in score_slots})
            recurring_component = min(
                days_covered / max(len(request.preferred_days), 1), 1.0
            )
            max_cap = teacher_profile.get("max_students") or MAX_CAPACITY
            capacity_component = min(max(max_cap - current_stud, 0) / max_cap, 1.0)
            breakdown = {
                "student_fit_30": round(student_fit * 30.0, 2),
                "availability_fit_25": round(avail_fit * 25.0, 2),
                "performance_20": round(perf_component * 20.0, 2),
                "recurring_compat_15": round(recurring_component * 15.0, 2),
                "capacity_10": round(capacity_component * 10.0, 2),
                "adjust_load": round(load_balancing_adjustment, 2),
                "adjust_priority": round(priority_adjustment, 2),
                "adjust_personalization": round(personalization_adjustment, 2),
            }
            explain = (
                f"Fit={breakdown['student_fit_30']}/30, "
                f"Avail={breakdown['availability_fit_25']}/25, "
                f"Perf={breakdown['performance_20']}/20, "
                f"Recurring={breakdown['recurring_compat_15']}/15, "
                f"Capacity={breakdown['capacity_10']}/10; "
                f"Adj(load={breakdown['adjust_load']}, priority={breakdown['adjust_priority']}, pers={breakdown['adjust_personalization']})."
            )

            results.append(
                {
                    "teacher_id": tid,
                    "name": name,
                    "teaching_language": (
                        teaching_langs_list[0] if teaching_langs_list else "English"
                    ),
                    "languages_spoken": languages_spoken_list,
                    "match_score": score,
                    "trial_conversion_rate": conv_rate,
                    "retention_rate": retention_rate,
                    "lesson_quality_score": quality_score,
                    "available_slots": trial_slots[
                        :5
                    ],  # trial slots (empty for subscription)
                    "recurring_slots": recurring_slots,  # FIX #5
                    "score_breakdown": breakdown,
                    "explainability": explain,
                    "current_students": current_stud,
                    "free_capacity": max(max_cap - current_stud, 0),
                    "teacher_tags": tags_list,
                    "load_balancing_adjustment": load_balancing_adjustment,
                    "priority_adjustment": priority_adjustment,
                    "personalization_adjustment": personalization_adjustment,
                }
            )

        results.sort(
            key=lambda x: (
                x["match_score"],
                x["retention_rate"],
                x["lesson_quality_score"],
                len(x["recurring_slots"]),
                len(x["available_slots"]),
                x["free_capacity"],
                x["load_balancing_adjustment"],
                x["priority_adjustment"],
                x["trial_conversion_rate"],
            ),
            reverse=True,
        )
        if request.search_option == "earliest_available":
            results.sort(
                key=lambda x: (
                    x["available_slots"][0] if x["available_slots"] else "Zzz 99:99",
                    -x["match_score"],
                )
            )
        top = _select_diverse_shortlist(results, mode=request.mode, k=5)
        flexibility_suggestions = (
            _build_flexibility_suggestions(
                top,
                request.preferred_days,
                request.preferred_time_from,
                request.preferred_time_to,
            )
            if request.allow_flexibility_suggestions
            else []
        )

        # Closed-loop analytics logging (Postgres only)
        if (
            DATA_SOURCE == "db"
            and conn
            and (request.questionnaire_id or request.student_id)
        ):
            qid = request.questionnaire_id
            if qid is None and request.student_id:
                # Best-effort fallback: link to the latest questionnaire response for this student.
                try:
                    _, rows = q(
                        conn,
                        """
                        SELECT response_id
                        FROM clean.questionnaire_responses
                        WHERE student_id = %s
                        ORDER BY created_at DESC
                        LIMIT 1
                        """,
                        (request.student_id,),
                    )
                    if rows and rows[0] and rows[0][0] is not None:
                        qid = int(rows[0][0])
                except Exception:
                    qid = None

            if qid is not None:
                _log_teacher_recommendations(conn, qid, top)

        return {
            "student_id": request.student_id,
            "student_name": student.get("name") if student else None,
            "student_native_language": native_language,
            "student_age": student_age,
            "english_level": english_level,
            "student_tags": student_tags,
            "student_goals": student_goals,
            "mode": request.mode,
            "preferred_days": request.preferred_days,
            "preferred_time": f"{request.preferred_time_from} - {request.preferred_time_to}",
            "sessions_per_week": request.sessions_per_week,
            "teachers_found": len(top),
            "results": top,
            "flexibility_suggestions": flexibility_suggestions,
        }
    finally:
        if conn:
            conn.close()


@app.get("/demo/data-health")
async def demo_data_health():
    if DATA_SOURCE != "csv" or not CSV_REPO:
        return {"data_source": DATA_SOURCE, "status": "n/a"}
    h = CSV_REPO.health()
    return {"data_source": "csv", **h.__dict__}


def _empty_response(request, student, student_age, english_level, native_language):
    """Return a valid empty MatchResponse."""
    student_name = None
    if student:
        student_name = student.get("name") or student.get("full_name")
    return {
        "student_id": request.student_id,
        "student_name": student_name,
        "student_native_language": native_language,
        "student_age": student_age,
        "english_level": english_level,
        "student_tags": request.student_tags,
        "student_goals": request.student_goals,
        "mode": request.mode,
        "preferred_days": request.preferred_days,
        "preferred_time": f"{request.preferred_time_from} - {request.preferred_time_to}",
        "sessions_per_week": request.sessions_per_week,
        "teachers_found": 0,
        "results": [],
        "flexibility_suggestions": (
            _build_flexibility_suggestions(
                [],
                request.preferred_days,
                request.preferred_time_from,
                request.preferred_time_to,
            )
            if request.allow_flexibility_suggestions
            else []
        ),
    }


@app.post("/trial-feedback", response_model=TrialFeedbackResponse)
async def submit_trial_feedback(request: TrialFeedbackRequest):
    conn = get_db()
    try:
        _, class_rows = q(
            conn,
            """
            SELECT 1
            FROM clean.classes
            WHERE class_id = %s
            LIMIT 1
        """,
            (request.class_id,),
        )
        if not class_rows:
            raise HTTPException(
                status_code=400, detail="class_id not found in clean.classes"
            )

        _, student_rows = q(
            conn,
            """
            SELECT 1
            FROM clean.students
            WHERE student_id = %s
            LIMIT 1
        """,
            (request.student_id,),
        )
        if not student_rows:
            raise HTTPException(
                status_code=400, detail="student_id not found in clean.students"
            )

        _, teacher_rows = q(
            conn,
            """
            SELECT 1
            FROM clean.teachers
            WHERE teacher_id = %s
            LIMIT 1
        """,
            (request.teacher_id,),
        )
        if not teacher_rows:
            raise HTTPException(
                status_code=400, detail="teacher_id not found in clean.teachers"
            )

        row = q_execute(
            conn,
            """
            INSERT INTO analytics.trial_class_feedback (
                class_id,
                student_id,
                teacher_id,
                trial_success,
                teacher_match_quality,
                student_feedback
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING feedback_id
        """,
            (
                request.class_id,
                request.student_id,
                request.teacher_id,
                request.trial_success,
                request.teacher_match_quality,
                request.student_feedback,
            ),
        )
        return {
            "feedback_id": int(row[0]),
            "status": "created",
        }
    finally:
        conn.close()


# ─────────────────────────────────────────────────────────────
# HEALTH + ROOT
# ─────────────────────────────────────────────────────────────


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check."""
    return {"status": "ok"}


@app.get("/demo")
async def demo_ui():
    return FileResponse(os.path.join(BASE_DIR, "demo_ui.html"))


@app.get("/matching-engine-explainer")
async def matching_engine_explainer():
    return FileResponse(os.path.join(BASE_DIR, "matching_engine_explainer.html"))


@app.get("/")
async def root():
    return {
        "message": "Tulkka Matching Engine API v1.1.0",
        "spec": "Teacher-Student Matching Engine v1.0 (March 2026)",
        "changes": [
            "FIX #1: Subscription mode now returns teachers (recurring availability)",
            "FIX #2: Native language filter uses languages_spoken",
            "FIX #3: Retention rate included in performance score",
            "FIX #4: Day-of-week convention unified (0=Sunday)",
            "FIX #5: recurring_slots field in every teacher result",
        ],
        "endpoints": {
            "POST /match": "Match teachers to a student",
            "POST /trial-feedback": "Store post-trial feedback",
            "GET /health": "Health check",
            "GET /demo": "CSV-backed demo UI",
            "GET /matching-engine-explainer": "Architecture explainer page",
            "GET /docs": "Swagger UI",
            "GET /redoc": "ReDoc",
        },
    }


# ─────────────────────────────────────────────────────────────
# ENTRYPOINT
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    print("Tulkka Matching Engine v1.1.0 — http://localhost:5000")
    print("Docs: http://localhost:5000/docs")
    uvicorn.run(app, host="127.0.0.1", port=5000)
