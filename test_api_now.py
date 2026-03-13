import requests
import json

url = "http://localhost:5050/match"
payload = {
    "student_id": 931,
    "student_age": 14,
    "english_level": "A2",
    "target_language": "English",
    "native_language": "Hebrew",
    "requires_native_language_teacher": True,
    "preferred_days": ["mon", "tue"],
    "preferred_time_from": "16:00",
    "preferred_time_to": "21:00",
    "sessions_per_week": 1,
    "mode": "trial"
}

try:
    r = requests.post(url, json=payload, timeout=10)
    result = r.json()
    print(f"Status: {r.status_code}")
    print(f"Teachers found: {result['teachers_found']}")
    if result['teachers_found'] > 0:
        print("\nTop 3 teachers:")
        for i, t in enumerate(result['results'][:3], 1):
            print(f"  {i}. {t['name']} - Score: {t['match_score']}")
    else:
        print("ERROR: No teachers returned!")
        print(json.dumps(result, indent=2))
except Exception as e:
    print(f"ERROR: {e}")
