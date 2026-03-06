"""
Backward Validation — Tulkka Matching Engine
---------------------------------------------
Ground truth: trial_class_registrations where status='converted'
These are students who did a trial and actually enrolled with that teacher.
That's the real signal — engine SHOULD have recommended this teacher.

Join via email: trial_class_registrations.email -> users.email to get student_id.

Run: python validate_matching.py
"""

import json
import os
import sys
from dotenv import load_dotenv

sys.stdout.reconfigure(encoding='utf-8')
import mysql.connector
from matching_engine import (
    get_db, fetch_all_teachers, fetch_all_conversion_rates,
    fetch_all_quality_scores, fetch_all_student_counts,
    fetch_all_availability, get_matching_slots, compute_score
)

load_dotenv()

# Use a wide time window so availability isn't the bottleneck
# We're testing scoring quality, not availability filtering
ALL_DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
TIME_FROM = "08:00"
TIME_TO   = "22:00"

TOP_N = 3   # check if actual teacher is in top N


def q(conn, sql, params=None):
    cur = conn.cursor(buffered=True)
    cur.execute(sql, params or ())
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description] if cur.description else []
    cur.close()
    return cols, rows


def fetch_converted_pairs(conn, limit=50):
    """
    Ground truth: trial students who converted to enrolled with a specific teacher.
    trial_class_registrations has no student_id FK — join via email to users table.
    Only includes cases where email match is found (student exists as a user).
    """
    _, rows = q(conn, """
        SELECT DISTINCT u.id as student_id, tcr.teacher_id,
               tcr.student_name, t.full_name as teacher_name
        FROM trial_class_registrations tcr
        JOIN users u ON LOWER(TRIM(u.email)) = LOWER(TRIM(tcr.email))
        JOIN users t ON t.id = tcr.teacher_id
        WHERE tcr.status = 'converted'
          AND tcr.email IS NOT NULL AND tcr.email != ''
          AND u.role_name = 'user'
          AND t.role_name = 'teacher'
          AND t.status = 'active'
        GROUP BY u.id, tcr.teacher_id, tcr.student_name, t.full_name
        ORDER BY MAX(tcr.id) DESC
        LIMIT %s
    """, (limit,))
    return rows  # [(student_id, teacher_id, student_name, teacher_name), ...]


def run_match_for_student(student_id, all_teachers, conv_map, qual_map, stud_map, avail_map):
    """Run the matching engine for one student, return ranked teacher list."""
    eligible = [(tid, name, lang) for tid, name, lang in all_teachers
                if (lang or "EN").upper() in ("EN", "")]

    results = []
    for tid, name, lang in eligible:
        availability = avail_map.get(tid, {})
        slots = get_matching_slots(availability, ALL_DAYS, TIME_FROM, TIME_TO)
        if not slots:
            continue

        score = compute_score(
            {},  # student dict not needed for current scoring
            slots,
            conv_map.get(tid, 0.0),
            qual_map.get(tid, 0.0),
            stud_map.get(tid, 0),
            ALL_DAYS
        )
        results.append({"teacher_id": tid, "name": name, "score": score})

    results.sort(key=lambda x: x["score"], reverse=True)
    return results


def main():
    print("Tulkka Matching Engine — Backward Validation")
    print("=" * 55)
    print(f"Checking: does actual teacher appear in top {TOP_N}?\n")

    conn = get_db()

    # Ground truth pairs
    pairs = fetch_converted_pairs(conn, limit=50)
    if not pairs:
        print("No converted trial pairs found (email join returned nothing).")
        conn.close()
        return

    print(f"Found {len(pairs)} converted trial pairs (email-matched to users table).\n")

    # Batch fetch all data once
    all_teachers = fetch_all_teachers(conn)
    teacher_ids  = [t[0] for t in all_teachers]
    conv_map     = fetch_all_conversion_rates(conn)
    qual_map     = fetch_all_quality_scores(conn)
    stud_map     = fetch_all_student_counts(conn)
    avail_map    = fetch_all_availability(conn, teacher_ids)
    conn.close()

    # Validate each pair
    hit_top1  = 0
    hit_top3  = 0
    miss      = 0
    no_avail  = 0
    results_detail = []

    for student_id, actual_teacher_id, student_name, teacher_name in pairs:
        ranked = run_match_for_student(
            student_id, all_teachers, conv_map, qual_map, stud_map, avail_map
        )

        ranked_ids = [r["teacher_id"] for r in ranked]

        if actual_teacher_id not in ranked_ids:
            # Teacher has no availability in our wide window — skip
            no_avail += 1
            status = "NO_AVAIL"
            rank = None
            score = None
        else:
            rank  = ranked_ids.index(actual_teacher_id) + 1  # 1-based
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

        results_detail.append({
            "student": student_name,
            "actual_teacher": teacher_name,
            "status": status,
            "rank": rank,
            "score": score,
            "top3": [r["name"] for r in ranked[:3]]
        })

    # Print detailed results
    print(f"{'Student':<25} {'Actual Teacher':<22} {'Result':<15} {'Score'}")
    print("-" * 80)
    for r in results_detail:
        score_str = f"{r['score']}%" if r['score'] is not None else "—"
        print(f"{r['student'][:24]:<25} {r['actual_teacher'][:21]:<22} {r['status']:<15} {score_str}")
        if r['status'].startswith("MISS"):
            print(f"  -> Top 3 were: {', '.join(r['top3'])}")

    # Summary
    validated = len(pairs) - no_avail
    print("\n" + "=" * 55)
    print(f"RESULTS ({validated} validated, {no_avail} skipped — teacher had no availability)\n")
    if validated > 0:
        print(f"  Top-1 accuracy : {hit_top1}/{validated} = {round(hit_top1/validated*100, 1)}%")
        print(f"  Top-3 accuracy : {hit_top3}/{validated} = {round(hit_top3/validated*100, 1)}%")
        print(f"  Misses         : {miss}/{validated} = {round(miss/validated*100, 1)}%")
        print()
        if hit_top3 / validated >= 0.6:
            print("  Engine quality: GOOD (60%+ top-3 accuracy)")
        elif hit_top3 / validated >= 0.4:
            print("  Engine quality: MODERATE — review miss cases")
        else:
            print("  Engine quality: NEEDS WORK — check scoring weights")
    print("=" * 55)


if __name__ == "__main__":
    main()
