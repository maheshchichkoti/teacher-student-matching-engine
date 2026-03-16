import json
import requests

payload = {
    'class_id': 286624,
    'student_id': 8484,
    'teacher_id': 8684,
    'feedback_role': 'student',
    'trial_success': True,
    'teacher_match_quality': 5,
    'student_feedback': 'Enterprise verification success-path test'
}
response = requests.post('http://localhost:5050/trial-feedback', json=payload, timeout=20)
print('STATUS:', response.status_code)
try:
    print(json.dumps(response.json(), indent=2))
except Exception:
    print(response.text)
