import requests
import json

r = requests.post('http://localhost:5050/match', json={
    'student_id': 931,
    'student_age': 14,
    'english_level': 'A2',
    'target_language': 'English',
    'native_language': 'Hebrew',
    'requires_native_language_teacher': True,
    'preferred_days': ['mon', 'tue'],
    'preferred_time_from': '16:00',
    'preferred_time_to': '21:00',
    'sessions_per_week': 1,
    'mode': 'trial'
})

result = r.json()
print(f"Teachers found: {result['teachers_found']}")

if result['teachers_found'] > 0:
    for i, t in enumerate(result['results'][:3], 1):
        print(f"{i}. {t['name']} - Score: {t['match_score']}")
else:
    print("ERROR: 0 teachers - server has old code")
    print(json.dumps(result, indent=2))
