import asyncio
import json
from statistics import mean
from matching_engine import MatchRequest, match

cases = [
    {
        'name': 'Hebrew Trial Age12 B1',
        'payload': {
            'student_id': 930,
            'student_age': 12,
            'english_level': 'B1',
            'target_language': 'English',
            'native_language': 'Hebrew',
            'requires_native_language_teacher': False,
            'preferred_days': ['mon', 'wed', 'fri'],
            'preferred_time_from': '16:00',
            'preferred_time_to': '20:00',
            'sessions_per_week': 2,
            'mode': 'trial'
        }
    },
    {
        'name': 'Arabic Trial NativeRequired Age13 B1',
        'payload': {
            'student_id': 933,
            'student_age': 13,
            'english_level': 'B1',
            'target_language': 'English',
            'native_language': 'Arabic',
            'requires_native_language_teacher': True,
            'preferred_days': ['mon', 'wed', 'fri'],
            'preferred_time_from': '17:00',
            'preferred_time_to': '21:00',
            'sessions_per_week': 2,
            'mode': 'trial'
        }
    },
    {
        'name': 'Hebrew Subscription Age14 A2',
        'payload': {
            'student_id': 931,
            'student_age': 14,
            'english_level': 'A2',
            'target_language': 'English',
            'native_language': 'Hebrew',
            'requires_native_language_teacher': True,
            'preferred_days': ['tue', 'thu'],
            'preferred_time_from': '17:00',
            'preferred_time_to': '21:00',
            'sessions_per_week': 2,
            'mode': 'subscription'
        }
    },
    {
        'name': 'Hebrew Beginner Trial Age10 A1',
        'payload': {
            'student_id': 932,
            'student_age': 10,
            'english_level': 'A1',
            'target_language': 'English',
            'native_language': 'Hebrew',
            'requires_native_language_teacher': True,
            'preferred_days': ['mon', 'wed'],
            'preferred_time_from': '16:00',
            'preferred_time_to': '19:00',
            'sessions_per_week': 3,
            'mode': 'trial'
        }
    },
    {
        'name': 'Arabic Trial NoNativeRequired Age12 A2',
        'payload': {
            'student_id': 935,
            'student_age': 12,
            'english_level': 'A2',
            'target_language': 'English',
            'native_language': 'Arabic',
            'requires_native_language_teacher': False,
            'preferred_days': ['sun', 'tue', 'thu'],
            'preferred_time_from': '16:00',
            'preferred_time_to': '20:00',
            'sessions_per_week': 2,
            'mode': 'trial'
        }
    },
    {
        'name': 'Teen Advanced Subscription Hebrew',
        'payload': {
            'student_id': 936,
            'student_age': 17,
            'english_level': 'C1',
            'target_language': 'English',
            'native_language': 'Hebrew',
            'requires_native_language_teacher': False,
            'preferred_days': ['sun', 'mon', 'wed'],
            'preferred_time_from': '18:00',
            'preferred_time_to': '21:00',
            'sessions_per_week': 2,
            'mode': 'subscription'
        }
    }
]

async def main():
    results = []
    score_values = []
    found_counts = []

    for case in cases:
        body = await match(MatchRequest(**case['payload']))
        top = body.get('results', [])[:3]
        found = body.get('teachers_found', 0)
        found_counts.append(found)
        score_values.extend([item.get('match_score', 0) for item in top])
        results.append({
            'name': case['name'],
            'teachers_found': found,
            'top_3': [
                {
                    'teacher_id': item.get('teacher_id'),
                    'name': item.get('name'),
                    'match_score': item.get('match_score'),
                    'trial_conversion_rate': item.get('trial_conversion_rate'),
                    'retention_rate': item.get('retention_rate'),
                    'lesson_quality_score': item.get('lesson_quality_score'),
                    'current_students': item.get('current_students'),
                    'free_capacity': item.get('free_capacity'),
                    'available_slots_count': len(item.get('available_slots', [])),
                    'recurring_slots_count': len(item.get('recurring_slots', [])),
                    'teacher_tags': item.get('teacher_tags', []),
                }
                for item in top
            ]
        })

    report = {
        'scenario_count': len(cases),
        'avg_teachers_found': round(mean(found_counts), 2) if found_counts else 0,
        'avg_top3_score': round(mean(score_values), 2) if score_values else 0,
        'min_teachers_found': min(found_counts) if found_counts else 0,
        'max_teachers_found': max(found_counts) if found_counts else 0,
        'cases': results,
    }

    with open('enterprise_e2e_output.json', 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2)

    print('WROTE enterprise_e2e_output.json')

asyncio.run(main())
