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
from datetime import datetime, timedelta
from typing import List, Optional
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from availability_service import AvailabilityService

load_dotenv()

app = FastAPI(
    title="Tulkka Matching Engine",
    description="Rule-based teacher-student matching API (Spec v1.0)",
    version="1.1.0",
)

# ─────────────────────────────────────────────────────────────
# DB CONFIG
# ─────────────────────────────────────────────────────────────

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "3.124.111.213"),
    "port":     int(os.getenv("DB_PORT", "5432")),
    "user":     os.getenv("DB_USER", "admin"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "tulkka_live"),
}

# ─────────────────────────────────────────────────────────────
# DAY-OF-WEEK MAPPING  ── canonical, shared by all functions
# FIX #4: 0=Sunday (matches clean.teacher_availability.day_of_week)
# ─────────────────────────────────────────────────────────────
DAY_NAMES = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]  # index 0=Sunday

DAY_MAP = {
    "sunday": "sun", "sun": "sun",
    "monday": "mon", "mon": "mon",
    "tuesday": "tue", "tue": "tue",
    "wednesday": "wed", "wed": "wed",
    "thursday": "thu", "thu": "thu",
    "friday": "fri", "fri": "fri",
    "saturday": "sat", "sat": "sat",
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
    student_age: Optional[int] = Field(default=None, description="Student age for age-range filter")
    english_level: Optional[str] = Field(default=None, description="Student CEFR level (A1–C2)")
    target_language: str = Field(default="English", description="Language the student wants to learn")
    native_language: Optional[str] = Field(default=None, description="Student's mother tongue")
    requires_native_language_teacher: bool = Field(
        default=False,
        description="Hard filter: teacher must speak native language (uses languages_spoken)"
    )
    preferred_days: List[str] = Field(..., description="Preferred lesson days, e.g. ['Sunday','Tuesday']")
    preferred_time_from: str = Field(default="16:00", description="Earliest slot time HH:MM")
    preferred_time_to: str = Field(default="21:00", description="Latest slot time HH:MM")
    sessions_per_week: int = Field(default=1, description="How many sessions per week")
    mode: str = Field(default="trial", description="'trial' or 'subscription'")
    student_tags: List[str] = Field(default_factory=list)
    student_goals: List[str] = Field(default_factory=list)
    search_option: Optional[str] = Field(default=None, description="'earliest_available' or null")
    allow_flexibility_suggestions: bool = Field(default=False)


class TeacherResult(BaseModel):
    teacher_id: int
    name: str
    teaching_language: str
    languages_spoken: List[str]
    match_score: float
    trial_conversion_rate: float
    retention_rate: float           # FIX #3 — now surfaced in response
    lesson_quality_score: float
    available_slots: List[str]      # trial slots (mode=trial) or empty (mode=subscription)
    recurring_slots: List[str]      # FIX #5 — recurring options always present
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


class TrialFeedbackRequest:
    class_id: int
    student_id: int
    teacher_id: int
    feedback_role: str
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
    _, rows = q(conn, """
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = %s
          AND table_name = %s
          AND column_name = %s
        LIMIT 1
    """, (schema, table, column))
    return bool(rows)


def get_next_date(day_name: str) -> str:
    """Return the next calendar date (YYYY-MM-DD) for a given day name."""
    target = DAY_MAP.get(day_name.lower(), "sun")
    target_idx = DAY_NAMES.index(target)   # 0=Sun … 6=Sat
    today = datetime.utcnow().date()
    # Python weekday: 0=Mon … 6=Sun → convert to our 0=Sun convention
    today_our_idx = _PY_WEEKDAY_TO_OUR[today.weekday()]
    delta = (target_idx - today_our_idx) % 7
    if delta == 0:
        delta = 7   # always return a future date (next occurrence, not today)
    return (today + timedelta(days=delta)).strftime("%Y-%m-%d")


# ─────────────────────────────────────────────────────────────
# BATCH FETCH — all data in one pass per endpoint call
# ─────────────────────────────────────────────────────────────

def fetch_student(conn, student_id: int):
    """Fetch student row with all matching-engine fields."""
    goal_expr = "learning_goal::text" if table_has_column(conn, "clean", "students", "learning_goal") else "NULL::text"
    tags_expr = "hobbies" if table_has_column(conn, "clean", "students", "hobbies") else "NULL::jsonb"
    _, rows = q(conn, f"""
        SELECT student_id, full_name, native_language, cefr_level, student_age,
               target_language, requires_native_language_teacher, preferred_days,
               preferred_time_start, preferred_time_end, sessions_per_week,
               language_preference, temperament, corrective_tolerance, scaffolding_preference,
               {goal_expr} AS learning_goal,
               {tags_expr} AS student_tags
        FROM clean.students
        WHERE student_id = %s
    """, (student_id,))
    if not rows:
        return None
    r = rows[0]
    return {
        "id":                               r[0],
        "name":                             r[1],
        "native_language":                  r[2],
        "student_level":                    r[3],
        "english_level":                    r[3],
        "student_age":                      r[4],
        "target_language":                  r[5],
        "requires_native_language_teacher": r[6],
        "preferred_days":                   r[7],
        "preferred_time_start":             r[8],
        "preferred_time_end":               r[9],
        "sessions_per_week":                r[10],
        "language_preference":              r[11],
        "temperament":                      r[12],
        "corrective_tolerance":             r[13],
        "scaffolding_preference":           r[14],
        "student_goals":                    [r[15]] if r[15] else [],
        "student_tags":                     _as_str_list(r[16]),
    }


def fetch_all_teachers(conn):
    """
    Fetch all active teachers with matching-engine fields.
    FIX #2: `languages_spoken` added as column 10 for native language hard filter.
    NOTE: recurring_enabled removed - all teachers are full-time
    NOTE: language_support removed - redundant with languages_spoken
    Returns list of 13-tuples:
      (teacher_id, full_name, teaching_languages, trial_enabled,
       age_min, age_max, teacher_tags, max_students_capacity, trial_priority, languages_spoken,
       teaching_style, correction_style, scaffolding_style)
    """
    _, rows = q(conn, """
        SELECT t.teacher_id,
               t.full_name,
               t.teaching_languages,
               t.trial_enabled,
               t.age_min,
               t.age_max,
               t.teacher_tags,
               t.max_students_capacity,
               t.trial_priority,
               t.languages_spoken,
               t.teaching_style,
               t.correction_style,
               t.scaffolding_style
        FROM clean.teachers t
        WHERE t.status = 'active'
        ORDER BY t.teacher_id
    """)
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
    _, rows = q(conn, """
        SELECT teacher_id,
               ROUND(
                   LEAST(
                       (
                           SUM(CASE WHEN event_type = 'trial_converted' THEN 1 ELSE 0 END)::numeric
                           / NULLIF(SUM(CASE WHEN event_type = 'trial_started' THEN 1 ELSE 0 END), 0)
                       ) * 100,
                       100
                   ),
                   1
               ) AS conversion_rate
        FROM analytics.class_facts
        WHERE event_type IN ('trial_started', 'trial_converted')
        GROUP BY teacher_id
    """)
    return {r[0]: float(r[1] or 0) for r in rows}


def fetch_all_quality_scores(conn) -> dict:
    """Per-teacher average lesson quality (0–100)."""
    _, rows = q(conn, """
        SELECT teacher_id,
               ROUND(AVG((grammar_score + vocabulary_score + fluency_score) / 3.0), 1) AS quality_score
        FROM analytics.class_facts
        WHERE grammar_score IS NOT NULL
        GROUP BY teacher_id
    """)
    return {r[0]: float(r[1] or 0) for r in rows}


def fetch_teacher_performance_snapshots(conn) -> dict:
    _, rows = q(conn, """
        SELECT t.teacher_id,
               COALESCE(p.avg_rating * 20, t.avg_rating * 20, 0) AS avg_rating_score,
               COALESCE(p.verification_rate, t.verification_rate, 0) AS verification_rate,
               COALESCE(p.total_classes_taught, t.total_classes_taught, 0) AS total_classes_taught,
               COALESCE(p.student_retention_rate, 0) AS student_retention_rate
        FROM clean.teachers t
        LEFT JOIN serve.teacher_performance_profile p
          ON p.teacher_id = t.teacher_id
        WHERE t.status = 'active'
    """)
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
    _, rows = q(conn, """
        SELECT teacher_id, COUNT(*) AS total_trials
        FROM analytics.class_facts
        WHERE event_type = 'trial_started'
        GROUP BY teacher_id
    """)
    return {r[0]: int(r[1] or 0) for r in rows}


def fetch_all_retention_rates(conn) -> dict:
    """
    FIX #3: Per-teacher 90-day retention rate.
    Retention = students still active (subscription_active event) 90 days after first trial.
    Returns ratio 0.0–100.0 per teacher_id.
    """
    _, rows = q(conn, """
        WITH trials AS (
            SELECT DISTINCT ON (teacher_id, student_id)
                teacher_id,
                student_id,
                occurred_at AS trial_date
            FROM analytics.class_facts
            WHERE event_type = 'trial_started'
        ),
        retained AS (
            SELECT t.teacher_id,
                   COUNT(DISTINCT t.student_id) AS retained_count,
                   COUNT(DISTINCT t.student_id) AS trial_count
            FROM trials t
            WHERE EXISTS (
                SELECT 1
                FROM analytics.class_facts cf
                WHERE cf.teacher_id = t.teacher_id
                  AND cf.student_id = t.student_id
                  AND cf.event_type = 'subscription_active'
                  AND cf.occurred_at BETWEEN t.trial_date
                                         AND t.trial_date + INTERVAL '90 days'
            )
            GROUP BY t.teacher_id
        ),
        all_trials AS (
            SELECT teacher_id, COUNT(DISTINCT student_id) AS total
            FROM trials
            GROUP BY teacher_id
        )
        SELECT a.teacher_id,
               ROUND(
                   COALESCE(
                       p.student_retention_rate,
                       COALESCE(r.retained_count, 0)::numeric / NULLIF(a.total, 0) * 100
                   ),
                   1
               )
        FROM all_trials a
        LEFT JOIN retained r ON a.teacher_id = r.teacher_id
        LEFT JOIN serve.teacher_performance_profile p ON p.teacher_id = a.teacher_id
    """)
    return {r[0]: float(r[1] or 0) for r in rows}


def fetch_all_student_counts(conn) -> dict:
    """Per-teacher active student count."""
    _, rows = q(conn, """
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
    """)
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
    _, rows = q(conn, f"""
        SELECT teacher_id, day_of_week, start_time, end_time
        FROM clean.teacher_availability
        WHERE teacher_id IN ({placeholders}) AND is_active = true
        ORDER BY teacher_id, day_of_week, start_time
    """, tuple(teacher_ids))

    result: dict = {}
    for row in rows:
        uid, day_idx, start_time, end_time = row[0], row[1], row[2], row[3]

        # FIX #4: Use canonical DAY_NAMES (0=Sun)
        if day_idx is None or day_idx >= len(DAY_NAMES):
            continue
        day_key = DAY_NAMES[day_idx]

        start_str = start_time.strftime("%H:%M") if hasattr(start_time, "strftime") else str(start_time)[:5]
        end_str   = end_time.strftime("%H:%M")   if hasattr(end_time,   "strftime") else str(end_time)[:5]

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


def get_matching_slots(availability: dict, preferred_days: list, time_from: str, time_to: str) -> list:
    """Return list of 'Day HH:MM' strings within the preferred window."""
    from_min = _to_minutes(time_from)
    to_min   = _to_minutes(time_to)
    slots = []
    for day in preferred_days:
        key = DAY_MAP.get(day.lower())
        if not key:
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


def _build_flexibility_suggestions(results: list[dict], preferred_days: list[str], time_from: str, time_to: str) -> list[str]:
    suggestions = []
    current_count = len(results)
    if current_count:
        return suggestions
    from_min = _to_minutes(time_from)
    to_min = _to_minutes(time_to)
    if to_min - from_min >= 60:
        suggestions.append("Try extending the preferred time range by 1 hour later to widen the teacher pool.")
    if len(preferred_days) < 3:
        suggestions.append("Add one more preferred day to increase matching coverage.")
    if not suggestions:
        suggestions.append("Relax one hard preference to surface more eligible teachers.")
    return suggestions


def _pref_match(student_val, teacher_val, match_map=None) -> float:
    """
    Compare one student preference against a teacher value.
    Returns:
      1.0 — match
      0.3 — mismatch
      0.5 — neutral (data not yet collected)
    """
    if not student_val or not teacher_val:
        return 0.5
    if match_map:
        return 1.0 if match_map.get(student_val) == teacher_val else 0.3
    return 1.0 if student_val == teacher_val else 0.3


def compute_student_fit(student_prefs: dict, teacher_profile: dict) -> float:
    """
    Student Fit (30%): matches 4 preference dimensions.
    Defaults to 0.5 per dimension when data is absent.
    """
    # NOTE: language_support removed - using languages_spoken for native language matching instead
    teacher_tags = set(teacher_profile.get("teacher_tags") or [])
    student_tags = {str(tag).lower() for tag in (student_prefs.get("student_tags") or [])}
    student_goals = {str(goal).lower() for goal in (student_prefs.get("student_goals") or [])}
    age = student_prefs.get("student_age")
    english_level = (student_prefs.get("english_level") or "").upper()
    age_fit = 0.5
    if age is not None:
        if age <= 12 and "kids_friendly" in teacher_tags:
            age_fit = 1.0
        elif age >= 16 and "business_english" in teacher_tags:
            age_fit = 1.0
        elif age <= 14 and "kids_friendly" not in teacher_tags and "business_english" in teacher_tags:
            age_fit = 0.3
    level_fit = 0.5
    if english_level:
        if english_level in {"A1", "A2"} and "beginner_friendly" in teacher_tags:
            level_fit = 1.0
        elif english_level in {"B2", "C1", "C2"} and "exam_prep" in teacher_tags:
            level_fit = 1.0
        elif english_level in {"A1", "A2"} and "exam_prep" in teacher_tags:
            level_fit = 0.3
    tag_fit = 0.5
    if student_tags:
        teacher_tags_lower = {tag.lower() for tag in teacher_tags}
        overlap = len(student_tags & teacher_tags_lower)
        tag_fit = min(overlap / max(len(student_tags), 1), 1.0) if overlap else 0.3
    goal_fit = 0.5
    if student_goals:
        teacher_tags_lower = {tag.lower() for tag in teacher_tags}
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
    scores = [
        0.5,  # Placeholder for language preference match (handled by hard filter)
        _pref_match(
            student_prefs.get("temperament"),
            teacher_profile.get("teaching_style"),
            match_map={"energetic": "perky", "calm": "business_like"},
        ),
        _pref_match(student_prefs.get("corrective_tolerance"), teacher_profile.get("correction_style")),
        _pref_match(student_prefs.get("scaffolding_preference"), teacher_profile.get("scaffolding_style")),
        age_fit,
        level_fit,
        tag_fit,
        goal_fit,
    ]
    return sum(scores) / len(scores)


def compute_score(
    student_prefs: dict,
    teacher_profile: dict,
    slots: list,
    conv_rate: float,
    retention_rate: float,       # FIX #3 — now a real parameter
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
      30% Student Fit       — preference matching (language, temperament, correction, scaffolding)
      25% Availability Fit  — trial slots within preferred window
      20% Performance       — conv_rate(40%) + retention(30%) + lesson_quality(30%)
      15% Recurring Compat  — preferred days covered by availability
      10% Capacity          — free slots vs max_students
    """
    student_fit = compute_student_fit(student_prefs, teacher_profile)
    avail_fit   = min(len(slots) / 5.0, 1.0)

    # FIX #3: Blend conversion, retention, and quality into performance
    performance = (
        (conv_rate    / 100.0) * 0.40 +
        (retention_rate / 100.0) * 0.30 +
        (quality_score / 100.0) * 0.30
    )

    days_covered = len({s.split(" ")[0] for s in slots})
    recurring    = min(days_covered / max(len(preferred_days), 1), 1.0)

    max_cap  = teacher_profile.get("max_students") or MAX_CAPACITY
    capacity = min(max(max_cap - current_students, 0) / max_cap, 1.0)
    evidence_strength = min(max(trial_count, total_classes_taught / 5.0, 0) / 12.0, 1.0)
    rating_component = min(avg_rating_score / 100.0, 1.0)
    verification_component = min(verification_rate / 100.0, 1.0)
    quality_component = min(quality_score / 100.0, 1.0)
    retention_component = min(retention_rate / 100.0, 1.0)
    reliability_bonus = (
        rating_component * 0.03 +
        verification_component * 0.03 +
        quality_component * 0.04 +
        retention_component * 0.05
    ) * evidence_strength
    sparse_data_penalty = 0.03 if evidence_strength < 0.15 else 0.0
    slot_breadth_bonus = min(len(slots), 8) / 8.0 * 0.04

    total = (
        student_fit * 0.30 +
        avail_fit   * 0.25 +
        performance * 0.20 +
        recurring   * 0.15 +
        capacity    * 0.10
    )
    final_score = total + reliability_bonus + slot_breadth_bonus - sparse_data_penalty
    return round(min(max(final_score, 0.0), 1.0) * 100, 1)


def compute_load_balancing_adjustment(current_students: int, max_students: int, trial_count: int) -> float:
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


def compute_personalization_adjustment(student_prefs: dict, teacher_profile: dict) -> float:
    teacher_tags = {str(tag).lower() for tag in (teacher_profile.get("teacher_tags") or [])}
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
            if "business_english" in teacher_tags or "exam_prep" in teacher_tags or "professional" in teacher_tags:
                adjustment += 4.0
            if "kids_friendly" in teacher_tags and "business_english" not in teacher_tags:
                adjustment -= 3.0

    if english_level in {"A1", "A2"}:
        if "beginner_friendly" in teacher_tags or "kids_friendly" in teacher_tags:
            adjustment += 3.0
        if "exam_prep" in teacher_tags and "beginner_friendly" not in teacher_tags:
            adjustment -= 2.0
    elif english_level in {"B1", "B2", "C1", "C2"}:
        if "exam_prep" in teacher_tags or "business_english" in teacher_tags or "professional" in teacher_tags:
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
        raise HTTPException(status_code=400, detail="mode must be 'trial' or 'subscription'")
    normalized_days = _normalize_preferred_days(request.preferred_days)
    if not normalized_days:
        raise HTTPException(status_code=400, detail="preferred_days must contain valid day values")
    request.preferred_days = normalized_days

    conn = get_db()
    try:
        avail_service = AvailabilityService(conn)

        # Resolve student data
        student = fetch_student(conn, request.student_id) if request.student_id else None
        student_age     = request.student_age     or (student.get("student_age") if student else None)
        english_level   = request.english_level   or (student.get("english_level") if student else None)
        native_language_raw = request.native_language or (student.get("native_language") if student else None)
        native_language = normalize_language(native_language_raw) if native_language_raw else None
        requires_native = request.requires_native_language_teacher or (
            student.get("requires_native_language_teacher") if student else False
        )
        student_tags = request.student_tags or (student.get("student_tags") if student else []) or []
        student_goals = request.student_goals or (student.get("student_goals") if student else []) or []

        student_prefs = {
            "language_preference": student.get("language_preference") if student else None,
            "temperament": student.get("temperament") if student else None,
            "corrective_tolerance": student.get("corrective_tolerance") if student else None,
            "scaffolding_preference": student.get("scaffolding_preference") if student else None,
            "student_age": student_age,
            "english_level": english_level,
            "student_tags": student_tags,
            "student_goals": student_goals,
        }

        # ── Step 1: Hard Filters ──────────────────────────────────
        all_teachers = fetch_all_teachers(conn)
        eligible = []

        for row in all_teachers:
            (tid, name, teaching_langs, trial_enabled,
             age_min, age_max, tags, capacity, priority, languages_spoken,
             teaching_style, correction_style, scaffolding_style) = row

            teaching_langs_list   = _as_str_list(teaching_langs)
            languages_spoken_list = _as_str_list(languages_spoken)
            tags_list             = _as_str_list(tags)

            # Mode filter
            if request.mode == "trial"        and not trial_enabled:
                continue
            # NOTE: recurring_enabled removed - all teachers are full-time, always available for subscription

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

            eligible.append((tid, name, teaching_langs_list, languages_spoken_list,
                             tags_list, capacity, priority))

        if not eligible:
            return _empty_response(request, student, student_age, english_level, native_language)

        teacher_ids = [t[0] for t in eligible]

        # Batch fetch performance data
        conv_map      = fetch_all_conversion_rates(conn)
        retention_map = fetch_all_retention_rates(conn)   # FIX #3
        qual_map      = fetch_all_quality_scores(conn)
        perf_map      = fetch_teacher_performance_snapshots(conn)
        trial_map     = fetch_all_trial_counts(conn)
        stud_map      = fetch_all_student_counts(conn)
        avail_map     = fetch_all_availability(conn, teacher_ids)

        # ── Steps 2 + 3: Availability + Scoring ──────────────────
        results = []

        for (tid, name, teaching_langs_list, languages_spoken_list, tags_list, capacity, priority) in eligible:

            availability = avail_map.get(tid, {})

            # --- Trial slots (used for mode=trial AND as supplementary for score) ---
            trial_slots: list[str] = []
            if request.mode == "trial":
                for day in request.preferred_days:
                    try:
                        date   = get_next_date(day)
                        raw    = avail_service.get_trial_availability(tid, date, "UTC")
                        for s in raw:
                            if not s["is_available"]:
                                continue
                            try:
                                slot_time = s["start"][11:16]
                                if request.preferred_time_from <= slot_time <= request.preferred_time_to:
                                    trial_slots.append(f"{day.capitalize()} {slot_time}")
                            except Exception:
                                pass
                    except Exception as exc:
                        print(f"[WARN] Trial availability error teacher={tid}: {exc}")

                if not trial_slots:
                    continue   # FIX #1 note: only skip for trial mode

            # --- Recurring slots — always computed (FIX #1 + FIX #5) ---
            recurring_slots: list[str] = []
            for day in request.preferred_days:
                day_key = DAY_MAP.get(day.lower())
                if not day_key:
                    continue
                # Use the first matching slot time in the window, or default 18:00
                candidate_time = "18:00"
                for t_str in sorted(availability.get(day_key, {}).keys()):
                    if request.preferred_time_from <= t_str <= request.preferred_time_to:
                        candidate_time = t_str
                        break
                try:
                    recurring_raw = avail_service.get_recurring_availability(
                        tid, day, candidate_time, weeks=4
                    )
                    ok_weeks = [r for r in recurring_raw if r["available"]]
                    if ok_weeks:
                        recurring_slots.append(f"{day.capitalize()} {candidate_time}")
                except Exception as exc:
                    print(f"[WARN] Recurring availability error teacher={tid}: {exc}")

            # FIX #1: For subscription mode, require at least one recurring slot
            if request.mode == "subscription" and not recurring_slots:
                continue

            # Slots used for scoring depend on mode
            score_slots = trial_slots if request.mode == "trial" else recurring_slots

            conv_rate      = conv_map.get(tid, 0.0)
            retention_rate = retention_map.get(tid, 0.0)
            quality_score  = qual_map.get(tid, 0.0)
            perf_snapshot  = perf_map.get(tid, {})
            avg_rating_score = perf_snapshot.get("avg_rating_score", 0.0)
            verification_rate = perf_snapshot.get("verification_rate", 0.0)
            total_classes_taught = perf_snapshot.get("total_classes_taught", 0)
            trial_count = trial_map.get(tid, 0)
            current_stud   = stud_map.get(tid, 0)
            max_cap        = capacity or MAX_CAPACITY

            # FIX #3: retention_rate now passed into compute_score
            # Build teacher profile with style fields (FIX #1 - using unpacked values)
            teacher_profile = {
                "max_students": max_cap,
                "teaching_style": teaching_style,
                "correction_style": correction_style,
                "scaffolding_style": scaffolding_style,
                "teacher_tags": tags_list,
            }

            score = compute_score(
                student_prefs  = student_prefs,  # FIX #1: Use actual preferences
                teacher_profile= teacher_profile,  # FIX #1: Use teacher profile
                slots          = score_slots,
                conv_rate      = conv_rate,
                retention_rate = retention_rate,
                quality_score  = quality_score,
                current_students = current_stud,
                preferred_days = request.preferred_days,
                trial_count    = trial_count,
                avg_rating_score = avg_rating_score,
                verification_rate = verification_rate,
                total_classes_taught = total_classes_taught,
            )

            load_balancing_adjustment = compute_load_balancing_adjustment(
                current_students=current_stud,
                max_students=max_cap,
                trial_count=trial_count,
            )
            priority_adjustment = compute_priority_adjustment(priority)
            personalization_adjustment = compute_personalization_adjustment(student_prefs, teacher_profile)
            score = max(
                min(
                    score + load_balancing_adjustment + priority_adjustment + personalization_adjustment,
                    100.0,
                ),
                0.0,
            )

            results.append({
                "teacher_id":           tid,
                "name":                 name,
                "teaching_language":    teaching_langs_list[0] if teaching_langs_list else "English",
                "languages_spoken":     languages_spoken_list,
                "match_score":          score,
                "trial_conversion_rate": conv_rate,
                "retention_rate":       retention_rate,
                "lesson_quality_score": quality_score,
                "available_slots":      trial_slots[:5],       # trial slots (empty for subscription)
                "recurring_slots":      recurring_slots,       # FIX #5
                "current_students":     current_stud,
                "free_capacity":        max(max_cap - current_stud, 0),
                "teacher_tags":         tags_list,
                "load_balancing_adjustment": load_balancing_adjustment,
                "priority_adjustment":  priority_adjustment,
                "personalization_adjustment": personalization_adjustment,
            })

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
        top = results[:5]
        flexibility_suggestions = _build_flexibility_suggestions(
            top,
            request.preferred_days,
            request.preferred_time_from,
            request.preferred_time_to,
        ) if request.allow_flexibility_suggestions else []

        return {
            "student_id":             request.student_id,
            "student_name":           student["name"] if student else None,
            "student_native_language": native_language,
            "student_age":            student_age,
            "english_level":          english_level,
            "student_tags":           student_tags,
            "student_goals":          student_goals,
            "mode":                   request.mode,
            "preferred_days":         request.preferred_days,
            "preferred_time":         f"{request.preferred_time_from} - {request.preferred_time_to}",
            "sessions_per_week":      request.sessions_per_week,
            "teachers_found":         len(top),
            "results":                top,
            "flexibility_suggestions": flexibility_suggestions,
        }
    finally:
        conn.close()


def _empty_response(request, student, student_age, english_level, native_language):
    """Return a valid empty MatchResponse."""
    return {
        "student_id":             request.student_id,
        "student_name":           student["name"] if student else None,
        "student_native_language": native_language,
        "student_age":            student_age,
        "english_level":          english_level,
        "student_tags":           request.student_tags,
        "student_goals":          request.student_goals,
        "mode":                   request.mode,
        "preferred_days":         request.preferred_days,
        "preferred_time":         f"{request.preferred_time_from} - {request.preferred_time_to}",
        "sessions_per_week":      request.sessions_per_week,
        "teachers_found":         0,
        "results":                [],
        "flexibility_suggestions": _build_flexibility_suggestions(
            [],
            request.preferred_days,
            request.preferred_time_from,
            request.preferred_time_to,
        ) if request.allow_flexibility_suggestions else [],
    }


def ensure_trial_feedback_table(conn):
    cur = conn.cursor()
    cur.execute("""
        CREATE SCHEMA IF NOT EXISTS analytics;
        CREATE TABLE IF NOT EXISTS analytics.trial_class_feedback (
            feedback_id BIGSERIAL PRIMARY KEY,
            class_id INT NOT NULL,
            student_id INT NOT NULL,
            teacher_id INT NOT NULL,
            feedback_role TEXT NOT NULL CHECK (feedback_role IN ('student', 'teacher')),
            trial_success BOOLEAN,
            teacher_match_quality INT CHECK (teacher_match_quality BETWEEN 1 AND 5),
            student_feedback TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )
    """)
    conn.commit()
    cur.close()


@app.post("/trial-feedback", response_model=TrialFeedbackResponse)
async def submit_trial_feedback(request: TrialFeedbackRequest):
    if request.feedback_role not in ("student", "teacher"):
        raise HTTPException(status_code=400, detail="feedback_role must be 'student' or 'teacher'")
    conn = get_db()
    try:
        ensure_trial_feedback_table(conn)
        _, class_rows = q(conn, """
            SELECT 1
            FROM clean.classes
            WHERE class_id = %s
            LIMIT 1
        """, (request.class_id,))
        if not class_rows:
            raise HTTPException(status_code=400, detail="class_id not found in clean.classes")

        _, student_rows = q(conn, """
            SELECT 1
            FROM clean.students
            WHERE student_id = %s
            LIMIT 1
        """, (request.student_id,))
        if not student_rows:
            raise HTTPException(status_code=400, detail="student_id not found in clean.students")

        _, teacher_rows = q(conn, """
            SELECT 1
            FROM clean.teachers
            WHERE teacher_id = %s
            LIMIT 1
        """, (request.teacher_id,))
        if not teacher_rows:
            raise HTTPException(status_code=400, detail="teacher_id not found in clean.teachers")

        row = q_execute(conn, """
            INSERT INTO analytics.trial_class_feedback (
                class_id,
                student_id,
                teacher_id,
                feedback_role,
                trial_success,
                teacher_match_quality,
                student_feedback
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING feedback_id
        """, (
            request.class_id,
            request.student_id,
            request.teacher_id,
            request.feedback_role,
            request.trial_success,
            request.teacher_match_quality,
            request.student_feedback,
        ))
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


@app.get("/")
async def root():
    return {
        "message": "Tulkka Matching Engine API v1.1.0",
        "spec":    "Teacher-Student Matching Engine v1.0 (March 2026)",
        "changes": [
            "FIX #1: Subscription mode now returns teachers (recurring availability)",
            "FIX #2: Native language filter uses languages_spoken",
            "FIX #3: Retention rate included in performance score",
            "FIX #4: Day-of-week convention unified (0=Sunday)",
            "FIX #5: recurring_slots field in every teacher result",
        ],
        "endpoints": {
            "POST /match":  "Match teachers to a student",
            "POST /trial-feedback": "Store post-trial feedback",
            "GET /health":  "Health check",
            "GET /docs":    "Swagger UI",
            "GET /redoc":   "ReDoc",
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
