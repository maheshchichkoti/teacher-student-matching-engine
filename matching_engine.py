"""
Tulkka — Rule-Based Teacher-Student Matching Engine
----------------------------------------------------
Endpoint: POST /match
Input : student_id + preferred_days + preferred_time (days/time hardcoded for demo — only missing data per Mahesh)
Output: top 3 teachers ranked by match score + available slots

Run:  python matching_engine.py
Test: curl -X POST http://localhost:5000/match -H "Content-Type: application/json"
      -d '{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}'
"""

import json
import os
from flask import Flask, request, jsonify
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

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

MAX_CAPACITY = 20  # teacher max capacity not in DB yet (coming from teacher form import)


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


def compute_score(student, slots, conv_rate, quality_score, current_students, preferred_days):
    """
    Spec weights: 30% student fit / 25% availability / 20% performance / 15% recurring / 10% capacity
    """
    # Student Fit (30%): language match + level match
    # Language fit = 1.0 (all EN teachers match — Tulkka is English learning platform)
    # Level fit = 0.5 neutral (sparse data)
    student_fit = 1.0 * 0.7 + 0.5 * 0.3

    # Availability Fit (25%): number of matching slots (5+ = max)
    avail_fit = min(len(slots) / 5.0, 1.0)

    # Performance (20%): real conversion rate + real lesson quality
    performance = (conv_rate / 100.0) * 0.6 + (quality_score / 100.0) * 0.4

    # Recurring Compatibility (15%): how many preferred days are covered
    days_covered = len(set(s.split(" ")[0] for s in slots))
    recurring = min(days_covered / max(len(preferred_days), 1), 1.0)

    # Capacity (10%): free slots
    capacity = min(max(MAX_CAPACITY - current_students, 0) / MAX_CAPACITY, 1.0)

    total = (
        student_fit * 0.30 +
        avail_fit   * 0.25 +
        performance * 0.20 +
        recurring   * 0.15 +
        capacity    * 0.10
    )
    return round(total * 100, 1)


# ─────────────────────────────────────────────
# API
# ─────────────────────────────────────────────

@app.route("/match", methods=["POST"])
def match():
    """
    {
        "student_id": 930,
        "preferred_days": ["Sunday", "Tuesday"],
        "preferred_time_from": "16:00",
        "preferred_time_to": "21:00",
        "mode": "trial"
    }
    preferred_days/time are passed in request — not in DB yet (Mahesh confirmed missing).
    Everything else is real data from DB.
    """
    data = request.get_json()
    if not data:
        return jsonify({"error": "JSON body required"}), 400

    student_id     = data.get("student_id")
    preferred_days = data.get("preferred_days", [])
    time_from      = data.get("preferred_time_from", "16:00")
    time_to        = data.get("preferred_time_to", "21:00")
    mode           = data.get("mode", "trial")

    if not preferred_days:
        return jsonify({"error": "preferred_days is required"}), 400

    conn = get_db()

    # Fetch student real data from DB
    student = fetch_student(conn, student_id) if student_id else None

    # Step 1: Active teachers (hard filter: English teaching language)
    all_teachers = fetch_all_teachers(conn)
    eligible = [(tid, name, lang) for tid, name, lang in all_teachers
                if (lang or "EN").upper() in ("EN", "")]

    teacher_ids = [t[0] for t in eligible]

    # Batch fetch all data in 4 queries total
    conv_map   = fetch_all_conversion_rates(conn)
    qual_map   = fetch_all_quality_scores(conn)
    stud_map   = fetch_all_student_counts(conn)
    avail_map  = fetch_all_availability(conn, teacher_ids)

    conn.close()

    # Step 2 + 3: Availability check + Scoring
    results = []
    for tid, name, lang in eligible:
        availability = avail_map.get(tid, {})
        slots = get_matching_slots(availability, preferred_days, time_from, time_to)
        if not slots:
            continue

        conv_rate     = conv_map.get(tid, 0.0)
        quality_score = qual_map.get(tid, 0.0)
        current_stud  = stud_map.get(tid, 0)

        score = compute_score(student or {}, slots, conv_rate, quality_score, current_stud, preferred_days)

        results.append({
            "teacher_id":            tid,
            "name":                  name,
            "teaching_language":     lang or "EN",
            "match_score":           score,
            "trial_conversion_rate": conv_rate,
            "lesson_quality_score":  quality_score,
            "available_slots":       slots[:5],
            "current_students":      current_stud,
            "free_capacity":         max(MAX_CAPACITY - current_stud, 0),
        })

    results.sort(key=lambda x: x["match_score"], reverse=True)
    top = results[:3]

    return jsonify({
        "student_id":              student_id,
        "student_name":            student["name"] if student else None,
        "student_native_language": student["native_language"] if student else None,
        "student_learning_goal":   student["learning_goal"] if student else None,
        "mode":                    mode,
        "preferred_days":          preferred_days,
        "preferred_time":          f"{time_from} - {time_to}",
        "teachers_found":          len(top),
        "results":                 top,
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    print("Tulkka Matching Engine — http://localhost:5000")
    print()
    print("Test:")
    print('  curl -X POST http://localhost:5000/match -H "Content-Type: application/json" \\')
    print('  -d \'{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}\'')
    app.run(debug=True, port=5000)


# =============================================================================
# ASSUMPTIONS — only what Mahesh confirmed missing + data gaps
# =============================================================================
# 1. preferred_days / preferred_time — from request params.
#    Mahesh confirmed: student goals + schedule NOT captured at signup. Everything else is real.
#
# 2. student learning_goal — fetched from classes.student_goal (most recent class, real data).
#    New students (no prior classes): defaults to "improve_conversation".
#
# 3. trial_conversion_rate — computed LIVE from trial_class_registrations (real).
#    users.trial_conversion_rate column was mostly 0/unreliable, not used.
#
# 4. lesson_quality_score — avg of grammar_rate + pronunciation_rate + speaking_rate
#    from lesson_feedbacks (101,571 real rows). Normalized to 0-100.
#
# 5. Language hard filter: teacher.language = 'EN' (Tulkka = English learning platform).
#    Teachers with NULL language included (assumed EN). HE/AR teachers excluded.
#
# 6. Teacher native_language / languages_spoken — not in DB.
#    Native language matching bonus skipped until teacher form data imported.
#
# 7. student_level matching — skipped. Only 1354/6466 students have it.
#    Level fit set to neutral (0.5).
#
# 8. teacher_tags / teaching_style — not in DB. Skipped until teacher form imported.
#
# 9. MAX_CAPACITY = 20 — not in DB. Update once teacher form data is imported.
#
# 10. current_students from classes with status in (pending, started, ended).
#
# 11. Scoring weights match spec exactly: 30/25/20/15/10.
#
# 12. Returns top 3 (Vinay said 2-3).
#
# 13. One-time availability (trial slots) not implemented — using recurring calendar.
#     Will add once cancellation/one-time slot logic is defined.
