"""
Backward Validation — Tulkka Matching Engine
-----------------------------------------------------------
Ground truth: analytics.class_facts where event_type='trial_converted'
These are students who completed a trial and enrolled with that teacher.
That is the real signal — the engine SHOULD have recommended this teacher.

FIX #6 applied (v1.1.0):
  - fetch_all_teachers() now returns 11-tuple (added languages_spoken).
  - Unpacking updated to match.
  - "teach English" check replaced: "English" in (teaching_langs or [])
  - compute_score() call updated with all required arguments (incl. retention_rate).
  - fetch_all_retention_rates() imported and used.

Run: python validate_matching.py
"""

import sys
from dotenv import load_dotenv
from matching_engine import (
    get_db,
    fetch_student,
    fetch_all_teachers,
    fetch_all_conversion_rates,
    fetch_all_retention_rates,      # FIX #6: import retention helper
    fetch_all_quality_scores,
    fetch_all_student_counts,
    fetch_all_availability,
    get_matching_slots,
    compute_score,
    _as_str_list,
)

sys.stdout.reconfigure(encoding="utf-8")
load_dotenv()

# Wide window — we are testing scoring quality, not availability filtering
ALL_DAYS  = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
TIME_FROM = "08:00"
TIME_TO   = "22:00"

TOP_N = 3   # check if the actual teacher appears in top N


# ─────────────────────────────────────────────
# DB HELPER
# ─────────────────────────────────────────────

def q(conn, sql, params=None):
    from psycopg2.extras import RealDictCursor
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(sql, params or ())
    rows = cur.fetchall()
    cols = list(rows[0].keys()) if rows else []
    cur.close()
    return cols, [list(row.values()) for row in rows]


# ─────────────────────────────────────────────
# GROUND TRUTH
# ─────────────────────────────────────────────

def fetch_converted_pairs(conn, limit: int = 50):
    """
    Ground truth: most-recent trial conversions.
    Returns: [(student_id, teacher_id, student_name, teacher_name), ...]
    """
    _, rows = q(conn, """
        SELECT
            cf.student_id,
            cf.teacher_id,
            s.full_name AS student_name,
            t.full_name AS teacher_name,
            MAX(cf.occurred_at) AS latest_conversion_at
        FROM analytics.class_facts cf
        JOIN clean.students s ON cf.student_id = s.student_id
        JOIN clean.teachers t ON cf.teacher_id = t.teacher_id
        WHERE cf.event_type = 'trial_converted'
          AND t.status = 'active'
        GROUP BY cf.student_id, cf.teacher_id, s.full_name, t.full_name
        ORDER BY latest_conversion_at DESC
        LIMIT %s
    """, (limit,))
    return [row[:4] for row in rows]  # [(student_id, teacher_id, student_name, teacher_name)]


# ─────────────────────────────────────────────
# MATCHING RUNNER (mirrors the API pipeline)
# ─────────────────────────────────────────────

def run_match_for_student(student_id, all_teachers, conv_map, retention_map, qual_map, stud_map, avail_map):
    """
    Run the full scoring pipeline for one student against all eligible teachers.
    Uses the current fetch_all_teachers() tuple shape and compute_score() signature.
    """
    results = []
    conn = get_db()
    student = fetch_student(conn, student_id)
    conn.close()
    if not student:
        return results

    student_age = student.get("student_age")
    native_language = student.get("native_language")
    requires_native = student.get("requires_native_language_teacher") or False
    student_prefs = {
        "language_preference": student.get("language_preference"),
        "temperament": student.get("temperament"),
        "corrective_tolerance": student.get("corrective_tolerance"),
        "scaffolding_preference": student.get("scaffolding_preference"),
    }

    for row in all_teachers:
        (tid, name, teaching_langs, trial_enabled,
         age_min, age_max, tags, capacity, priority, languages_spoken,
         teaching_style, correction_style, scaffolding_style) = row

        teaching_langs_list = _as_str_list(teaching_langs)
        languages_spoken_list = _as_str_list(languages_spoken)

        # FIX #6: "teaches English" check — no more (lang or "EN").upper()
        if "English" not in teaching_langs_list:
            continue

        if priority == "disabled":
            continue

        if student_age:
            if age_min is not None and student_age < age_min:
                continue
            if age_max is not None and student_age > age_max:
                continue

        if requires_native and native_language:
            if native_language not in languages_spoken_list:
                continue

        availability = avail_map.get(tid, {})
        slots = get_matching_slots(availability, ALL_DAYS, TIME_FROM, TIME_TO)
        if not slots:
            continue

        max_cap      = capacity or 20
        conv_rate    = conv_map.get(tid, 0.0)
        ret_rate     = retention_map.get(tid, 0.0)     # FIX #6: retention
        quality      = qual_map.get(tid, 0.0)
        cur_students = stud_map.get(tid, 0)

        # FIX #6: call signature matches updated compute_score()
        score = compute_score(
            student_prefs     = student_prefs,
            teacher_profile   = {
                "max_students": max_cap,
                "teaching_style": teaching_style,
                "correction_style": correction_style,
                "scaffolding_style": scaffolding_style,
            },
            slots             = slots,
            conv_rate         = conv_rate,
            retention_rate    = ret_rate,
            quality_score     = quality,
            current_students  = cur_students,
            preferred_days    = ALL_DAYS,
        )
        results.append({"teacher_id": tid, "name": name, "score": score})

    results.sort(key=lambda x: x["score"], reverse=True)
    return results


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────

def main():
    print("Tulkka Matching Engine — Backward Validation v1.1.0")
    print("=" * 55)
    print(f"Checking: does actual teacher appear in top {TOP_N}?\n")

    conn = get_db()

    pairs = fetch_converted_pairs(conn, limit=50)
    if not pairs:
        print("No converted trial pairs found.")
        conn.close()
        return

    print(f"Found {len(pairs)} converted trial pairs.\n")

    # Batch fetch (one DB round-trip each)
    all_teachers  = fetch_all_teachers(conn)
    teacher_ids   = [row[0] for row in all_teachers]
    conv_map      = fetch_all_conversion_rates(conn)
    retention_map = fetch_all_retention_rates(conn)
    qual_map      = fetch_all_quality_scores(conn)
    stud_map      = fetch_all_student_counts(conn)
    avail_map     = fetch_all_availability(conn, teacher_ids)
    conn.close()

    hit_top1  = 0
    hit_top3  = 0
    miss      = 0
    no_avail  = 0
    details   = []

    for student_id, actual_teacher_id, student_name, teacher_name in pairs:
        ranked = run_match_for_student(
            student_id, all_teachers,
            conv_map, retention_map, qual_map, stud_map, avail_map,
        )
        ranked_ids = [r["teacher_id"] for r in ranked]

        if actual_teacher_id not in ranked_ids:
            no_avail += 1
            status = "NO_AVAIL"
            rank   = None
            score  = None
        else:
            rank  = ranked_ids.index(actual_teacher_id) + 1
            score = next(r["score"] for r in ranked if r["teacher_id"] == actual_teacher_id)

            if rank == 1:
                hit_top1 += 1
                hit_top3 += 1
                status = "HIT #1"
            elif rank <= TOP_N:
                hit_top3 += 1
                status = f"HIT #{rank}"
            else:
                miss += 1
                status = f"MISS (rank #{rank})"

        details.append({
            "student":        student_name,
            "actual_teacher": teacher_name,
            "status":         status,
            "rank":           rank,
            "score":          score,
            "top3":           [r["name"] for r in ranked[:3]],
        })

    # Print table
    print(f"{'Student':<25} {'Actual Teacher':<22} {'Result':<18} {'Score'}")
    print("-" * 80)
    for r in details:
        score_str = f"{r['score']}%" if r["score"] is not None else "—"
        print(f"{r['student'][:24]:<25} {r['actual_teacher'][:21]:<22} {r['status']:<18} {score_str}")
        if r["status"].startswith("MISS"):
            print(f"  → Top 3 were: {', '.join(r['top3'])}")

    # Summary
    validated = len(pairs) - no_avail
    print("\n" + "=" * 55)
    print(f"RESULTS ({validated} validated, {no_avail} skipped — teacher had no availability)\n")
    if validated > 0:
        top1_pct = round(hit_top1 / validated * 100, 1)
        top3_pct = round(hit_top3 / validated * 100, 1)
        miss_pct = round(miss     / validated * 100, 1)
        print(f"  Top-1 accuracy : {hit_top1}/{validated} = {top1_pct}%")
        print(f"  Top-3 accuracy : {hit_top3}/{validated} = {top3_pct}%")
        print(f"  Misses         : {miss}/{validated} = {miss_pct}%")
        print()
        if top3_pct >= 60:
            print("  Engine quality: GOOD (60%+ top-3 accuracy)")
        elif top3_pct >= 40:
            print("  Engine quality: MODERATE — review miss cases")
        else:
            print("  Engine quality: NEEDS WORK — check scoring weights")
    print("=" * 55)


if __name__ == "__main__":
    main()
