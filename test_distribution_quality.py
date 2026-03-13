import asyncio
import json
from matching_engine import MatchRequest, match

async def test_hebrew_students():
    """Test if Hebrew-speaking students get DIFFERENT teacher recommendations"""
    
    # All Hebrew-speaking students with similar profiles
    hebrew_students = [
        {"id": 931, "age": 14, "level": "A2", "name": "Noam (14, A2)"},
        {"id": 933, "age": 12, "level": "A1", "name": "Student 933 (12, A1)"},
        {"id": 932, "age": 16, "level": "B1", "name": "Student 932 (16, B1)"},
    ]
    
    results = {}
    
    for student in hebrew_students:
        request = MatchRequest(
            student_id=student["id"],
            student_age=student["age"],
            english_level=student["level"],
            target_language="English",
            native_language="Hebrew",
            requires_native_language_teacher=True,
            preferred_days=["mon", "tue"],
            preferred_time_from="16:00",
            preferred_time_to="21:00",
            sessions_per_week=1,
            mode="trial"
        )
        
        result = await match(request)
        results[student["id"]] = {
            "name": student["name"],
            "teachers_found": result["teachers_found"],
            "top_3": [(t["teacher_id"], t["name"], t["match_score"]) for t in result["results"][:3]]
        }
    
    print("="*80)
    print("RECOMMENDATION DISTRIBUTION TEST - Hebrew-Speaking Students")
    print("="*80)
    
    for student_id, data in results.items():
        print(f"\n{data['name']}:")
        print(f"  Teachers found: {data['teachers_found']}")
        for i, (tid, name, score) in enumerate(data['top_3'], 1):
            print(f"    {i}. Teacher {tid} - {name} (Score: {score})")
    
    # Check if all students got the SAME top teacher
    top_teachers = [data['top_3'][0][0] if data['top_3'] else None for data in results.values()]
    
    print("\n" + "="*80)
    print("DISTRIBUTION ANALYSIS")
    print("="*80)
    
    if len(set(top_teachers)) == 1:
        print("❌ POOR DISTRIBUTION: All students got the SAME top teacher!")
        print(f"   All recommended: Teacher {top_teachers[0]}")
        print("   This is NOT enterprise-grade - no load balancing")
        quality_rating = 3
    elif len(set(top_teachers)) == len(top_teachers):
        print("✅ EXCELLENT DISTRIBUTION: Each student got a DIFFERENT top teacher")
        print("   This shows proper personalization and load balancing")
        quality_rating = 9
    else:
        print("⚠️  MODERATE DISTRIBUTION: Some overlap in top recommendations")
        print(f"   Unique top teachers: {len(set(top_teachers))} out of {len(top_teachers)} students")
        quality_rating = 6
    
    # Check score differentiation
    all_scores = []
    for data in results.values():
        all_scores.extend([score for _, _, score in data['top_3']])
    
    score_range = max(all_scores) - min(all_scores) if all_scores else 0
    
    print(f"\nScore Range: {min(all_scores):.1f} - {max(all_scores):.1f} (spread: {score_range:.1f})")
    
    if score_range < 5:
        print("❌ POOR SCORING: All teachers have similar scores - no clear differentiation")
        quality_rating = min(quality_rating, 4)
    elif score_range > 15:
        print("✅ GOOD SCORING: Clear differentiation between teacher quality")
    else:
        print("⚠️  MODERATE SCORING: Some differentiation but could be better")
    
    print(f"\n{'='*80}")
    print(f"OVERALL QUALITY RATING: {quality_rating}/10")
    print(f"{'='*80}")
    
    if quality_rating < 7:
        print("\n❌ NOT ENTERPRISE-GRADE")
        print("Issues:")
        if len(set(top_teachers)) == 1:
            print("  - All students get same teacher (no personalization)")
        if score_range < 5:
            print("  - Scoring doesn't differentiate teacher quality")
        print("\nNeeds:")
        print("  - Better personalization based on student age/level")
        print("  - Load balancing to distribute students across teachers")
        print("  - More discriminating scoring algorithm")
    else:
        print("\n✅ ENTERPRISE-READY")
        print("  - Proper personalization per student")
        print("  - Good load distribution")
        print("  - Clear quality differentiation")
    
    return quality_rating

asyncio.run(test_hebrew_students())
