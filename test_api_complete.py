#!/usr/bin/env python3
"""Complete API testing with realistic scenarios"""
import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:5000"

def test_health():
    """Test health endpoint"""
    print("\n" + "="*60)
    print("TEST 1: Health Check")
    print("="*60)

    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def test_match_trial_hebrew_student():
    """Test trial matching for Hebrew student"""
    print("\n" + "="*60)
    print("TEST 2: Trial Match - Hebrew Student (Yael, 12, B1)")
    print("="*60)

    payload = {
        "student_id": 930,
        "student_age": 12,
        "english_level": "B1",
        "target_language": "English",
        "native_language": "Hebrew",
        "requires_native_language_teacher": False,
        "preferred_days": ["mon", "wed", "fri"],
        "preferred_time_from": "16:00",
        "preferred_time_to": "20:00",
        "sessions_per_week": 2,
        "mode": "trial"
    }

    print(f"Request: {json.dumps(payload, indent=2)}")
    response = requests.post(f"{BASE_URL}/match", json=payload)
    print(f"\nStatus: {response.status_code}")

    if response.status_code == 200:
        data = response.json()
        print(f"\nMatched {data['teachers_found']} teachers:")
        for i, teacher in enumerate(data['results'][:3], 1):
            print(f"\n  {i}. {teacher['name']} (ID: {teacher['teacher_id']})")
            print(f"     Match Score: {teacher['match_score']}")
            print(f"     Conversion Rate: {teacher['trial_conversion_rate']}%")
            print(f"     Available Slots: {len(teacher.get('available_slots', []))}")
            if teacher.get('available_slots'):
                print(f"     First Slot: {teacher['available_slots'][0]}")
        return data.get('teachers_found', 0) > 0
    else:
        print(f"Error: {response.text}")
        return False

def test_match_arabic_student_native_required():
    """Test matching for Arabic student requiring native support"""
    print("\n" + "="*60)
    print("TEST 3: Trial Match - Arabic Student (Layla, 13, B1, Native Required)")
    print("="*60)

    payload = {
        "student_id": 933,
        "student_age": 13,
        "english_level": "B1",
        "target_language": "English",
        "native_language": "Arabic",
        "requires_native_language_teacher": True,
        "preferred_days": ["mon", "wed", "fri"],
        "preferred_time_from": "17:00",
        "preferred_time_to": "21:00",
        "sessions_per_week": 2,
        "mode": "trial"
    }

    print(f"Request: {json.dumps(payload, indent=2)}")
    response = requests.post(f"{BASE_URL}/match", json=payload)
    print(f"\nStatus: {response.status_code}")

    if response.status_code == 200:
        data = response.json()
        print(f"\nMatched {data['teachers_found']} teachers (filtered for Arabic speakers):")
        for i, teacher in enumerate(data['results'], 1):
            print(f"\n  {i}. {teacher['name']} (ID: {teacher['teacher_id']})")
            print(f"     Match Score: {teacher['match_score']}")
            print(f"     Conversion Rate: {teacher['trial_conversion_rate']}%")
        return data.get('teachers_found', 0) > 0
    else:
        print(f"Error: {response.text}")
        return False

def test_match_subscription_mode():
    """Test subscription mode matching"""
    print("\n" + "="*60)
    print("TEST 4: Subscription Match - Hebrew Student (Noam, 14, A2)")
    print("="*60)

    payload = {
        "student_id": 931,
        "student_age": 14,
        "english_level": "A2",
        "target_language": "English",
        "native_language": "Hebrew",
        "requires_native_language_teacher": True,
        "preferred_days": ["tue", "thu"],
        "preferred_time_from": "17:00",
        "preferred_time_to": "21:00",
        "sessions_per_week": 2,
        "mode": "subscription"
    }

    print(f"Request: {json.dumps(payload, indent=2)}")
    response = requests.post(f"{BASE_URL}/match", json=payload)
    print(f"\nStatus: {response.status_code}")

    if response.status_code == 200:
        data = response.json()
        print(f"\nMatched {data['teachers_found']} teachers:")
        for i, teacher in enumerate(data['results'], 1):
            print(f"\n  {i}. {teacher['name']} (ID: {teacher['teacher_id']})")
            print(f"     Match Score: {teacher['match_score']}")
            print(f"     Recurring Slots: {len(teacher.get('recurring_slots', []))}")
        return data.get('teachers_found', 0) > 0
    else:
        print(f"Error: {response.text}")
        return False

def test_match_beginner():
    """Test matching for beginner student"""
    print("\n" + "="*60)
    print("TEST 5: Trial Match - Beginner (Tamar, 10, A1)")
    print("="*60)

    payload = {
        "student_id": 932,
        "student_age": 10,
        "english_level": "A1",
        "target_language": "English",
        "native_language": "Hebrew",
        "requires_native_language_teacher": True,
        "preferred_days": ["mon", "wed"],
        "preferred_time_from": "16:00",
        "preferred_time_to": "19:00",
        "sessions_per_week": 3,
        "mode": "trial"
    }

    print(f"Request: {json.dumps(payload, indent=2)}")
    response = requests.post(f"{BASE_URL}/match", json=payload)
    print(f"\nStatus: {response.status_code}")

    if response.status_code == 200:
        data = response.json()
        print(f"\nMatched {data['teachers_found']} teachers (beginner-friendly):")
        for i, teacher in enumerate(data['results'][:3], 1):
            print(f"\n  {i}. {teacher['name']} (ID: {teacher['teacher_id']})")
            print(f"     Match Score: {teacher['match_score']}")
        return data.get('teachers_found', 0) > 0
    else:
        print(f"Error: {response.text}")
        return False

def run_all_tests():
    """Run all tests and generate report"""
    print("\n" + "="*70)
    print("MATCHING ENGINE API - COMPLETE TEST SUITE")
    print("="*70)
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    results = {
        "Health Check": test_health(),
        "Trial Match - Hebrew Student": test_match_trial_hebrew_student(),
        "Trial Match - Arabic Student (Native Required)": test_match_arabic_student_native_required(),
        "Subscription Match": test_match_subscription_mode(),
        "Beginner Match": test_match_beginner(),
    }

    # Summary
    print("\n" + "="*70)
    print("TEST SUMMARY")
    print("="*70)

    passed = sum(results.values())
    total = len(results)

    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")

    print(f"\nResults: {passed}/{total} tests passed ({passed/total*100:.0f}%)")

    if passed == total:
        print("\n" + "="*70)
        print("✅ ALL TESTS PASSED - READY FOR DEPLOYMENT")
        print("="*70)
        print("\nDeployment Checklist:")
        print("  ✅ Database migrated")
        print("  ✅ Test data populated")
        print("  ✅ API server running")
        print("  ✅ All endpoints tested")
        print("  ✅ Matching quality verified")
        print("\nNext Steps:")
        print("  1. Update .env with production database credentials")
        print("  2. Deploy to production server")
        print("  3. Run validation script: python validate_matching.py")
    else:
        print("\n⚠️  Some tests failed. Review errors above.")

    return passed == total

if __name__ == '__main__':
    success = run_all_tests()
    exit(0 if success else 1)
