import json
import urllib.request
from statistics import mean

BASE = 'http://127.0.0.1:5000'

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
        'name': 'Omar Trial Age12 Arabic NoNativeRequired',
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
    }
]

def post_json(path, payload):
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        BASE + path,
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status, json.loads(resp.read().decode('utf-8'))

summary = []
all_scores = []
all_counts = []

for case in cases:
    status, body = post_json('/match', case['payload'])
    results = body.get('results', [])
    top3 = results[:3]
    scores = [r.get('match_score', 0) for r in top3]
    count = body.get('teachers_found', 0)
    all_counts.append(count)
    all_scores.extend(scores)
    summary.append({
        'name': case['name'],
        'status_code': status,
        'teachers_found': count,
        'top_3': [
            {
                'teacher_id': r.get('teacher_id'),
                'name': r.get('name'),
                'score': r.get('match_score'),
                'conversion_rate': r.get('trial_conversion_rate'),
                'retention_rate': r.get('retention_rate'),
                'available_slots_count': len(r.get('available_slots', [])),
                'recurring_slots_count': len(r.get('recurring_slots', [])),
                'languages_spoken': r.get('languages_spoken'),
                'teacher_tags': r.get('teacher_tags'),
            }
            for r in top3
        ]
    })

report = {
    'scenario_count': len(cases),
    'avg_teachers_found': round(mean(all_counts), 2) if all_counts else 0,
    'avg_top3_score': round(mean(all_scores), 2) if all_scores else 0,
    'min_teachers_found': min(all_counts) if all_counts else 0,
    'max_teachers_found': max(all_counts) if all_counts else 0,
    'cases': summary,
}

with open('quality_rating_output.json', 'w', encoding='utf-8') as f:
    json.dump(report, f, indent=2)

print('WROTE quality_rating_output.json')
