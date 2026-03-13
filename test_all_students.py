import asyncio
import json
from matching_engine import MatchRequest, match

async def test_student(student_id, desc):
    print(f"\n{'='*60}")
    print(f"Testing: {desc} (Student {student_id})")
    print('='*60)
    
    request = MatchRequest(
        student_id=student_id,
        preferred_days=["mon", "tue"],
        preferred_time_from="16:00",
        preferred_time_to="21:00",
        sessions_per_week=1,
        mode="trial"
    )
    
    result = await match(request)
    
    print(f"Teachers found: {result['teachers_found']}")
    if result['teachers_found'] > 0:
        for i, t in enumerate(result['results'][:3], 1):
            print(f"  {i}. {t['name']} (ID: {t['teacher_id']}) - Score: {t['match_score']}")
            print(f"     Languages: {', '.join(t['languages_spoken'])}")
            print(f"     Available: {', '.join(t['available_slots'][:3])}")
    else:
        print("  ❌ NO TEACHERS FOUND")
    
    return result

async def main():
    students = [
        (931, "Hebrew native, requires Hebrew teacher"),
        (932, "Different student profile"),
        (933, "Another student"),
        (930, "Original test student")
    ]
    
    for student_id, desc in students:
        await test_student(student_id, desc)
    
    print(f"\n{'='*60}")
    print("Summary: All tests completed")
    print('='*60)

asyncio.run(main())
