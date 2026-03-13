import asyncio
import json
from matching_engine import MatchRequest, match

async def test():
    request = MatchRequest(
        student_id=931,
        student_age=14,
        english_level="A2",
        target_language="English",
        native_language="HE",
        requires_native_language_teacher=True,
        preferred_days=["mon", "tue"],
        preferred_time_from="16:00",
        preferred_time_to="21:00",
        sessions_per_week=1,
        mode="trial"
    )
    
    result = await match(request)
    
    print(json.dumps(result, indent=2, default=str))
    print(f"\n✓ Teachers found: {result['teachers_found']}")
    
    if result['teachers_found'] > 0:
        print(f"✓ Top teacher: {result['results'][0]['name']} (score: {result['results'][0]['match_score']})")
    else:
        print("✗ STILL NO TEACHERS - BUG NOT FIXED")

asyncio.run(test())
