"""
Tulkka — Rule-Based Teacher-Student Matching Engine (FastAPI Version)
----------------------------------------------------
Endpoint: POST /match
Input : student_id + preferred_days + preferred_time (days/time hardcoded for demo — only missing data per Mahesh)
Output: top 3 teachers ranked by match score + available slots

Run:  uvicorn matching_engine_fastapi:app --reload --port 5000
Test: curl -X POST http://localhost:5000/match -H "Content-Type: application/json"
      -d '{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}'
"""

import json
import os
from typing import List, Optional
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(
    title="Tulkka Matching Engine",
    description="Rule-based teacher-student matching API",
    version="1.0.0"
)

DB_CONFIG = {
    "host":                os.getenv("DB_HOST", "3.124.111.213"),
    "port":                int(os.getenv("DB_PORT", 3306)),
    "user":                os.getenv("DB_USER", "admin"),
    "password":            os.getenv("DB_PASSWORD"),
    "database":            os.getenv("DB_NAME", "tulkka_live"),
    "connection_timeout":  10,
    "ssl_disabled":        False,
    "ssl_verify_cert":     False,
    "ssl_verify_identity": False,
}

DAY_MAP = {
    "sunday": "sun", "monday": "mon", "tuesday": "tue",
    "wednesday": "wed", "thursday": "thu", "friday": "fri", "saturday": "sat",
}

MAX_CAPACITY = 20


# Pydantic Models for Request/Response
class MatchRequest(BaseModel):
    student_id: Optional[int] = None
    preferred_days: List[str] = Field(..., description="List of preferred days")
    preferred_time_from: str = Field(default="16:00", description="Preferred start time (HH:MM)")
    preferred_time_to: str = Field(default="21:00", description="Preferred end time (HH:MM)")
    mode: str = Field(default="trial", description="Mode: trial or subscription")


class TeacherResult(BaseModel):
    teacher_id: int
    name: str
    teaching_language: str
    match_score: float
    trial_conversion_rate: float
    lesson_quality_score: float
    available_slots: List[str]
    current_students: int
    free_capacity: int


class MatchResponse(BaseModel):
    student_id: Optional[int]
    student_name: Optional[str]
    student_native_language: Optional[str]
    student_learning_goal: Optional[str]
    mode: str
    preferred_days: List[str]
    preferred_time: str
    teachers_found: int
    results: List[TeacherResult]


class HealthResponse(BaseModel):
    status: str


def get_db():
    return mysql.connector.connect(**DB_CONFIG)


def q(conn, sql, params=None):
    cur = conn.cursor(buffered=True)
    cur.execute(sql, params or ())
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description] if cur.description else []
    cur.close()
    return cols, rows


# ─────────────────────────────────────────────
# BATCH FETCH — all in one pass, no per-teacher loops
# ─────────────────────────────────────────────

def fetch_student(conn, student_id):
    _, rows = q(conn, """
        SELECT id, full_name, language, student_level
        FROM users WHERE id = %s AND role_name = 'user'
    """, (student_id,))
    if not rows:
        return None
    r = rows[0]
    student = {"id": r[0], "name": r[1], "native_language": r[2], "student_level": r[3]}
    # Real goal from most recent class (falls back to hardcoded default for new students)
    _, gr = q(conn, """
        SELECT student_goal FROM classes
        WHERE student_id = %s AND student_goal IS NOT NULL AND student_goal != ''
        ORDER BY created_at DESC LIMIT 1
    """, (student_id,))
    student["learning_goal"] = gr[0][0] if gr else "improve_conversation"
    return student


def fetch_all_teachers(conn):
    _, rows = q(conn, "SELECT id, full_name, language FROM users WHERE role_name='teacher' AND status='active'")
    return rows  # [(id, name, language), ...]


def fetch_all_conversion_rates(conn):
    """Real trial conversion from trial_class_registrations — batched for all teachers."""
    _, rows = q(conn, """
        SELECT teacher_id,
            ROUND(SUM(status='converted') / COUNT(*) * 100, 1) as conv_rate
        FROM trial_class_registrations
        WHERE teacher_id IS NOT NULL
        GROUP BY teacher_id
    """)
    return {r[0]: float(r[1]) for r in rows}


def fetch_all_quality_scores(conn):
    """Real lesson quality from lesson_feedbacks — batched for all teachers."""
    _, rows = q(conn, """
        SELECT teacher_id,
            AVG((COALESCE(grammar_rate,0) + COALESCE(pronunciation_rate,0) + COALESCE(speaking_rate,0)) / 3.0) as avg_score
        FROM lesson_feedbacks
        WHERE teacher_id IS NOT NULL
        GROUP BY teacher_id
    """)
    return {r[0]: round(float(r[1]) / 10.0 * 100, 1) for r in rows}


def fetch_all_student_counts(conn):
    """Current active students per teacher — batched."""
    _, rows = q(conn, """
        SELECT teacher_id, COUNT(DISTINCT student_id)
        FROM classes
        WHERE status IN ('pending', 'started', 'ended')
        GROUP BY teacher_id
    """)
    return {r[0]: r[1] for r in rows}


def fetch_student_preferences(conn, student_id):
    """Fetch student preferences from student_preferences table. Returns {} if not filled yet."""
    _, rows = q(conn, """
        SELECT language_preference, temperament, corrective_tolerance,
               scaffolding_preference, preferred_gadget, hobbies
        FROM student_preferences WHERE user_id = %s
    """, (student_id,))
    if not rows:
        return {}
    r = rows[0]
    return {
        "language_preference":  r[0],
        "temperament":          r[1],
        "corrective_tolerance": r[2],
        "scaffolding_preference": r[3],
        "preferred_gadget":     r[4],
        "hobbies":              r[5],
    }


def fetch_all_teacher_profiles(conn, teacher_ids):
    """Fetch teacher profiles for all teachers in one query."""
    if not teacher_ids:
        return {}
    placeholders = ",".join(["%s"] * len(teacher_ids))
    _, rows = q(conn, f"""
        SELECT user_id, teaching_style, correction_style, scaffolding_style,
               language_support, max_students
        FROM teacher_profile WHERE user_id IN ({placeholders})
    """, tuple(teacher_ids))
    return {r[0]: {
        "teaching_style":   r[1],
        "correction_style": r[2],
        "scaffolding_style": r[3],
        "language_support": r[4],
        "max_students":     r[5],
    } for r in rows}


def fetch_all_availability(conn, teacher_ids):
    """Fetch availability for all teachers in one query."""
    if not teacher_ids:
        return {}
    placeholders = ",".join(["%s"] * len(teacher_ids))
    _, rows = q(conn, f"SELECT user_id, mon, tue, wed, thu, fri, sat, sun FROM teacher_availability WHERE user_id IN ({placeholders})", tuple(teacher_ids))
    result = {}
    days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    for row in rows:
        uid = row[0]
        avail = {}
        for i, day in enumerate(days):
            if row[i + 1]:
                try:
                    avail[day] = json.loads(row[i + 1])
                except Exception:
                    avail[day] = {}
        result[uid] = avail
    return result


# ─────────────────────────────────────────────
# MATCHING LOGIC
# ─────────────────────────────────────────────

def _to_minutes(t):
    p = t.split(":")
    return int(p[0]) * 60 + int(p[1])


def get_matching_slots(availability, preferred_days, time_from, time_to):
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


def _pref_match(student_val, teacher_val, match_map=None):
    """
    Compare one student preference against teacher value.
    Returns 1.0 (match), 0.3 (mismatch), or 0.5 (neutral — data missing).
    match_map: optional dict for cross-field matching (e.g. temperament → teaching_style).
    """
    if not student_val or not teacher_val:
        return 0.5  # neutral — data not collected yet
    if match_map:
        return 1.0 if match_map.get(student_val) == teacher_val else 0.3
    return 1.0 if student_val == teacher_val else 0.3


def compute_student_fit(student_prefs, teacher_profile):
    """
    Student Fit (30%): compares student preferences against teacher profile.
    All fields default to 0.5 (neutral) when data is missing.
    Once mobile team + teacher form data starts flowing in, this becomes real.
    """
    scores = [
        # Language preference: does student want English-only or need Hebrew/Arabic help?
        _pref_match(
            student_prefs.get("language_preference"),
            teacher_profile.get("language_support")
        ),
        # Temperament: energetic student → perky teacher, calm student → business_like teacher
        _pref_match(
            student_prefs.get("temperament"),
            teacher_profile.get("teaching_style"),
            match_map={"energetic": "perky", "calm": "business_like"}
        ),
        # Corrective tolerance: student wants direct/indirect correction → teacher style
        _pref_match(
            student_prefs.get("corrective_tolerance"),
            teacher_profile.get("correction_style")
        ),
        # Scaffolding: student wants quick answers (high) or to think it out (low)
        _pref_match(
            student_prefs.get("scaffolding_preference"),
            teacher_profile.get("scaffolding_style")
        ),
    ]
    return sum(scores) / len(scores)


def compute_score(student_prefs, teacher_profile, slots, conv_rate, quality_score, current_students, preferred_days):
    """
    Spec weights: 30% student fit / 25% availability / 20% performance / 15% recurring / 10% capacity
    """
    # Student Fit (30%): preference matching (neutral 0.5 per field until data exists)
    student_fit = compute_student_fit(student_prefs, teacher_profile)

    # Availability Fit (25%): number of matching slots (5+ = max)
    avail_fit = min(len(slots) / 5.0, 1.0)

    # Performance (20%): real conversion rate + real lesson quality
    performance = (conv_rate / 100.0) * 0.6 + (quality_score / 100.0) * 0.4

    # Recurring Compatibility (15%): how many preferred days are covered
    days_covered = len(set(s.split(" ")[0] for s in slots))
    recurring = min(days_covered / max(len(preferred_days), 1), 1.0)

    # Capacity (10%): free slots (uses teacher's own max if set, else default 20)
    max_cap = teacher_profile.get("max_students") or MAX_CAPACITY
    capacity = min(max(max_cap - current_students, 0) / max_cap, 1.0)

    total = (
        student_fit * 0.30 +
        avail_fit   * 0.25 +
        performance * 0.20 +
        recurring   * 0.15 +
        capacity    * 0.10
    )
    return round(total * 100, 1)


# ─────────────────────────────────────────────
# API Endpoints
# ─────────────────────────────────────────────

@app.post("/match", response_model=MatchResponse)
async def match(request: MatchRequest):
    """
    Match teachers to a student based on preferences and availability.

    - **student_id**: Optional student ID (if None, returns all teachers without student-specific filtering)
    - **preferred_days**: List of preferred days (e.g., ["Sunday", "Tuesday"])
    - **preferred_time_from**: Preferred start time (HH:MM format)
    - **preferred_time_to**: Preferred end time (HH:MM format)
    - **mode**: "trial" or "subscription"
    """
    if not request.preferred_days:
        raise HTTPException(status_code=400, detail="preferred_days is required")

    conn = get_db()

    try:
        # Fetch student real data from DB
        student = fetch_student(conn, request.student_id) if request.student_id else None
        student_prefs = fetch_student_preferences(conn, request.student_id) if request.student_id else {}

        # Step 1: Active teachers (hard filter: English teaching language)
        all_teachers = fetch_all_teachers(conn)
        eligible = [(tid, name, lang) for tid, name, lang in all_teachers
                    if (lang or "EN").upper() in ("EN", "")]

        teacher_ids = [t[0] for t in eligible]

        # Batch fetch all data in 6 queries total
        conv_map     = fetch_all_conversion_rates(conn)
        qual_map     = fetch_all_quality_scores(conn)
        stud_map     = fetch_all_student_counts(conn)
        avail_map    = fetch_all_availability(conn, teacher_ids)
        profile_map  = fetch_all_teacher_profiles(conn, teacher_ids)

        # Step 2 + 3: Availability check + Scoring
        results = []
        for tid, name, lang in eligible:
            availability   = avail_map.get(tid, {})
            slots = get_matching_slots(availability, request.preferred_days, request.preferred_time_from, request.preferred_time_to)
            if not slots:
                continue

            conv_rate      = conv_map.get(tid, 0.0)
            quality_score  = qual_map.get(tid, 0.0)
            current_stud   = stud_map.get(tid, 0)
            teacher_profile = profile_map.get(tid, {})

            score = compute_score(student_prefs, teacher_profile, slots, conv_rate, quality_score, current_stud, request.preferred_days)

            max_cap = teacher_profile.get("max_students") or MAX_CAPACITY
            results.append({
                "teacher_id":            tid,
                "name":                  name,
                "teaching_language":     lang or "EN",
                "match_score":           score,
                "trial_conversion_rate": conv_rate,
                "lesson_quality_score":  quality_score,
                "available_slots":       slots[:5],
                "current_students":      current_stud,
                "free_capacity":         max(max_cap - current_stud, 0),
            })

        results.sort(key=lambda x: x["match_score"], reverse=True)
        top = results[:3]

        return {
            "student_id":              request.student_id,
            "student_name":            student["name"] if student else None,
            "student_native_language": student["native_language"] if student else None,
            "student_learning_goal":   student["learning_goal"] if student else None,
            "mode":                    request.mode,
            "preferred_days":          request.preferred_days,
            "preferred_time":          f"{request.preferred_time_from} - {request.preferred_time_to}",
            "teachers_found":          len(top),
            "results":                 top,
        }
    finally:
        conn.close()


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint"""
    return {"status": "ok"}


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Tulkka Matching Engine API",
        "version": "1.0.0",
        "endpoints": {
            "POST /match": "Match teachers to a student",
            "GET /health": "Health check",
            "GET /docs": "Interactive API documentation (Swagger UI)",
            "GET /redoc": "Alternative API documentation (ReDoc)"
        }
    }


if __name__ == "__main__":
    import uvicorn
    print("Tulkka Matching Engine (FastAPI) — http://localhost:5000")
    print()
    print("API Documentation:")
    print("  Swagger UI: http://localhost:5000/docs")
    print("  ReDoc:     http://localhost:5000/redoc")
    print()
    print("Test:")
    print('  curl -X POST http://localhost:5000/match -H "Content-Type: application/json" \\')
    print('  -d \'{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}\'')
    uvicorn.run(app, host="127.0.0.1", port=5000)
