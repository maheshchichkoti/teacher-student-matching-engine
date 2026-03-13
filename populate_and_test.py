#!/usr/bin/env python3
"""
Populate test data and verify matching engine
"""
import psycopg2
import json
import sys
from datetime import datetime, timedelta
import random

# Database connection
DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 5432,
    'dbname': 'tulkka_subset',
    'user': 'postgres',
    'password': 'Password@123'
}

def connect_db():
    """Connect to PostgreSQL"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print("✅ Connected to PostgreSQL")
        return conn
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        sys.exit(1)

def populate_students(conn):
    """Populate students table"""
    print("\n📊 Populating students...")
    cur = conn.cursor()

    students = [
        (930, 'Yael Cohen', 'yael.cohen@test.com', 'Hebrew', 12, 'B1', 'English', False,
         ['mon','wed','fri'], '16:00', '20:00', 2,
         json.dumps(["sports","music","reading"]), 'bilingual', 'energetic', 'high', 'high'),

        (931, 'Noam Levi', 'noam.levi@test.com', 'Hebrew', 14, 'A2', 'English', True,
         ['tue','thu'], '17:00', '21:00', 2,
         json.dumps(["gaming","technology","science"]), 'bilingual', 'calm', 'medium', 'low'),

        (932, 'Tamar Shapiro', 'tamar.shapiro@test.com', 'Hebrew', 10, 'A1', 'English', True,
         ['mon','wed'], '16:00', '19:00', 3,
         json.dumps(["art","animals","cooking"]), 'native_only', 'energetic', 'low', 'high'),

        (933, 'Eitan Goldberg', 'eitan.goldberg@test.com', 'Hebrew', 15, 'B2', 'English', False,
         ['mon','tue','wed','thu','fri'], '18:00', '21:00', 3,
         json.dumps(["business","debate","politics"]), 'target_only', 'calm', 'high', 'low'),

        (934, 'Maya Katz', 'maya.katz@test.com', 'Hebrew', 8, 'A1', 'English', True,
         ['sun','tue','thu'], '15:00', '18:00', 2,
         json.dumps(["disney","cartoons","drawing"]), 'native_only', 'energetic', 'low', 'high'),

        (935, 'Layla Hassan', 'layla.hassan@test.com', 'Arabic', 13, 'B1', 'English', True,
         ['mon','wed','fri'], '17:00', '21:00', 2,
         json.dumps(["fashion","photography","travel"]), 'bilingual', 'calm', 'medium', 'low'),

        (936, 'Omar Khalil', 'omar.khalil@test.com', 'Arabic', 11, 'A2', 'English', True,
         ['tue','thu','sat'], '16:00', '20:00', 3,
         json.dumps(["soccer","sports","youtube"]), 'bilingual', 'energetic', 'high', 'high'),

        (937, 'Fatima Ali', 'fatima.ali@test.com', 'Arabic', 16, 'C1', 'English', False,
         ['mon','wed'], '19:00', '22:00', 2,
         json.dumps(["literature","writing","poetry"]), 'target_only', 'calm', 'high', 'low'),

        (938, 'Zain Mansour', 'zain.mansour@test.com', 'Arabic', 9, 'A1', 'English', True,
         ['sun','mon','wed'], '15:00', '18:00', 2,
         json.dumps(["lego","minecraft","robots"]), 'native_only', 'energetic', 'low', 'high'),

        (939, 'Sofia Rodriguez', 'sofia.rodriguez@test.com', 'Spanish', 14, 'B1', 'English', False,
         ['tue','thu','sat'], '17:00', '21:00', 2,
         json.dumps(["dance","music","friends"]), 'target_only', 'energetic', 'medium', 'low'),
    ]

    for student in students:
        try:
            cur.execute("""
                INSERT INTO clean.students (
                    student_id, full_name, email, native_language, student_age, english_level,
                    target_language, requires_native_language_teacher, preferred_days,
                    preferred_time_start, preferred_time_end, sessions_per_week,
                    hobbies, language_preference, temperament, corrective_tolerance,
                    scaffolding_preference, status, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'active', NOW())
                ON CONFLICT (student_id) DO NOTHING
            """, student)
        except Exception as e:
            print(f"  ⚠️  Student {student[0]} error: {e}")

    conn.commit()
    cur.execute("SELECT COUNT(*) FROM clean.students WHERE student_id >= 930")
    count = cur.fetchone()[0]
    print(f"✅ Populated {count} students")

def populate_teachers(conn):
    """Populate teachers table"""
    print("\n📊 Populating teachers...")
    cur = conn.cursor()

    teachers = [
        (201, 'Sarah Miller', 'sarah.miller@test.com', 'Asia/Jerusalem',
         'Experienced ESL teacher specializing in young learners. 15 years teaching in Israel.',
         json.dumps(["English"]), ['English','Hebrew'], ['A1','A2','B1','B2','C1'],
         True, 6, 16, ['kids_friendly','energetic','grammar_specialist'],
         25, 8, 'high', 'perky', 'direct', 'high'),

        (202, 'David Cohen', 'david.cohen@test.com', 'Asia/Jerusalem',
         'Business English expert. Former corporate trainer. Specializes in teenagers preparing for exams.',
         json.dumps(["English"]), ['English','Hebrew'], ['B1','B2','C1','C2'],
         True, 12, 18, ['business_english','exam_prep','structured'],
         20, 15, 'normal', 'business_like', 'direct', 'low'),

        (203, 'Rachel Green', 'rachel.green@test.com', 'Asia/Jerusalem',
         'Fun and interactive teacher for beginners. Uses games and songs. Kids love my classes!',
         json.dumps(["English"]), ['English','Hebrew'], ['A1','A2','B1'],
         True, 5, 12, ['kids_friendly','beginner_friendly','fun'],
         30, 5, 'high', 'perky', 'indirect', 'high'),

        (204, 'Michael Johnson', 'michael.johnson@test.com', 'Asia/Dubai',
         'CELTA certified. 10 years in Middle East. Specializes in conversational English.',
         json.dumps(["English"]), ['English','Arabic'], ['A2','B1','B2','C1'],
         True, 8, 18, ['conversation_focused','patient','cultural_expert'],
         22, 12, 'normal', 'business_like', 'indirect', 'low'),

        (205, 'Fatima Williams', 'fatima.williams@test.com', 'Asia/Dubai',
         'Bilingual teacher (English/Arabic). Great with shy students. Focus on confidence building.',
         json.dumps(["English"]), ['English','Arabic'], ['A1','A2','B1','B2'],
         True, 6, 14, ['bilingual','supportive','confidence_builder'],
         25, 10, 'high', 'perky', 'indirect', 'high'),

        (206, 'Anna Petrova', 'anna.petrova@test.com', 'Europe/Moscow',
         'Speaks 5 languages. Great with beginners from any background. Patient and encouraging.',
         json.dumps(["English"]), ['English','Russian','Hebrew','Arabic'], ['A1','A2','B1','B2'],
         True, 7, 16, ['multilingual','beginner_friendly','patient'],
         28, 6, 'high', 'perky', 'indirect', 'high'),

        (207, 'Tom Baker', 'tom.baker@test.com', 'Europe/London',
         'Sports and gaming vocabulary specialist. Connects with kids through their interests.',
         json.dumps(["English"]), ['English','Hebrew'], ['A1','A2','B1'],
         True, 8, 14, ['sports','gaming','kids_friendly'],
         26, 11, 'normal', 'perky', 'direct', 'high'),
    ]

    for teacher in teachers:
        try:
            cur.execute("""
                INSERT INTO clean.teachers (
                    teacher_id, full_name, email, timezone, bio,
                    teaching_languages, languages_spoken, cefr_can_teach,
                    trial_enabled, age_min, age_max, teacher_tags,
                    max_students_capacity, current_students, trial_priority,
                    teaching_style, correction_style, scaffolding_style,
                    status, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'active', NOW())
                ON CONFLICT (teacher_id) DO NOTHING
            """, teacher)
        except Exception as e:
            print(f"  ⚠️  Teacher {teacher[0]} error: {e}")

    conn.commit()
    cur.execute("SELECT COUNT(*) FROM clean.teachers WHERE teacher_id >= 201")
    count = cur.fetchone()[0]
    print(f"✅ Populated {count} teachers")

def populate_availability(conn):
    """Populate teacher availability"""
    print("\n📊 Populating teacher availability...")
    cur = conn.cursor()

    # Sarah Miller (201) - Mon/Wed/Fri afternoons
    availability = [
        (201, 1, '16:00', '20:00', 'Asia/Jerusalem'),
        (201, 3, '16:00', '20:00', 'Asia/Jerusalem'),
        (201, 5, '16:00', '20:00', 'Asia/Jerusalem'),
        # David Cohen (202) - Tue/Thu evenings
        (202, 2, '18:00', '22:00', 'Asia/Jerusalem'),
        (202, 4, '18:00', '22:00', 'Asia/Jerusalem'),
        # Rachel Green (203) - Every day afternoons
        (203, 0, '15:00', '19:00', 'Asia/Jerusalem'),
        (203, 1, '15:00', '19:00', 'Asia/Jerusalem'),
        (203, 2, '15:00', '19:00', 'Asia/Jerusalem'),
        (203, 3, '15:00', '19:00', 'Asia/Jerusalem'),
        (203, 4, '15:00', '19:00', 'Asia/Jerusalem'),
        # Michael Johnson (204) - Mon/Wed/Fri evenings
        (204, 1, '17:00', '21:00', 'Asia/Dubai'),
        (204, 3, '17:00', '21:00', 'Asia/Dubai'),
        (204, 5, '17:00', '21:00', 'Asia/Dubai'),
        # Fatima Williams (205) - Tue/Thu/Sat afternoons
        (205, 2, '16:00', '20:00', 'Asia/Dubai'),
        (205, 4, '16:00', '20:00', 'Asia/Dubai'),
        (205, 6, '16:00', '20:00', 'Asia/Dubai'),
        # Anna Petrova (206) - Very flexible
        (206, 1, '16:00', '21:00', 'Europe/Moscow'),
        (206, 2, '16:00', '21:00', 'Europe/Moscow'),
        (206, 3, '16:00', '21:00', 'Europe/Moscow'),
        (206, 4, '16:00', '21:00', 'Europe/Moscow'),
        (206, 5, '16:00', '21:00', 'Europe/Moscow'),
        # Tom Baker (207) - Mon/Wed/Fri afternoons
        (207, 1, '16:00', '20:00', 'Europe/London'),
        (207, 3, '16:00', '20:00', 'Europe/London'),
        (207, 5, '16:00', '20:00', 'Europe/London'),
    ]

    for slot in availability:
        try:
            cur.execute("""
                INSERT INTO clean.teacher_availability
                (teacher_id, day_of_week, start_time, end_time, timezone, is_active, created_at)
                VALUES (%s, %s, %s, %s, %s, true, NOW())
                ON CONFLICT DO NOTHING
            """, slot)
        except Exception as e:
            print(f"  ⚠️  Availability error: {e}")

    conn.commit()
    cur.execute("SELECT COUNT(*) FROM clean.teacher_availability WHERE teacher_id >= 201")
    count = cur.fetchone()[0]
    print(f"✅ Populated {count} availability slots")

def populate_class_facts(conn):
    """Populate analytics.class_facts for performance scoring"""
    print("\n📊 Populating class facts (performance data)...")
    cur = conn.cursor()

    # High performers (80% conversion)
    high_performers = [201, 203, 205, 206]
    for teacher_id in high_performers:
        for i in range(20):
            event_type = 'trial_converted' if random.random() < 0.8 else 'trial_started'
            student_id = random.randint(930, 939)
            days_ago = random.randint(1, 90)

            try:
                cur.execute("""
                    INSERT INTO analytics.class_facts (
                        event_type, class_id, student_id, student_email, teacher_id, teacher_name,
                        meeting_start, duration_mins, cefr_level_before, cefr_level_after,
                        fluency_score, vocabulary_score, grammar_score, occurred_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    event_type,
                    1000 + (teacher_id * 100) + i,
                    student_id,
                    f'student{student_id}@test.com',
                    teacher_id,
                    f'Teacher {teacher_id}',
                    datetime.now() - timedelta(days=days_ago),
                    30,
                    'B1', 'B1',
                    round(75.0 + random.random() * 20, 2),
                    round(78.0 + random.random() * 18, 2),
                    round(80.0 + random.random() * 15, 2),
                    datetime.now() - timedelta(days=days_ago)
                ))
            except Exception as e:
                pass  # Ignore duplicates

    # Medium performers (60% conversion)
    medium_performers = [202, 204, 207]
    for teacher_id in medium_performers:
        for i in range(15):
            event_type = 'trial_converted' if random.random() < 0.6 else 'trial_started'
            student_id = random.randint(930, 939)
            days_ago = random.randint(1, 90)

            try:
                cur.execute("""
                    INSERT INTO analytics.class_facts (
                        event_type, class_id, student_id, student_email, teacher_id, teacher_name,
                        meeting_start, duration_mins, cefr_level_before, cefr_level_after,
                        fluency_score, vocabulary_score, grammar_score, occurred_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    event_type,
                    2000 + (teacher_id * 100) + i,
                    student_id,
                    f'student{student_id}@test.com',
                    teacher_id,
                    f'Teacher {teacher_id}',
                    datetime.now() - timedelta(days=days_ago),
                    30,
                    'B1', 'B1',
                    round(65.0 + random.random() * 20, 2),
                    round(68.0 + random.random() * 18, 2),
                    round(70.0 + random.random() * 15, 2),
                    datetime.now() - timedelta(days=days_ago)
                ))
            except Exception as e:
                pass

    conn.commit()
    cur.execute("SELECT COUNT(*) FROM analytics.class_facts WHERE teacher_id >= 201")
    count = cur.fetchone()[0]
    print(f"✅ Populated {count} class facts")

def verify_data(conn):
    """Verify populated data"""
    print("\n🔍 Verifying data...")
    cur = conn.cursor()

    # Check students
    cur.execute("SELECT COUNT(*) FROM clean.students WHERE student_id >= 930")
    student_count = cur.fetchone()[0]
    print(f"  Students: {student_count}")

    # Check teachers
    cur.execute("SELECT COUNT(*) FROM clean.teachers WHERE teacher_id >= 201")
    teacher_count = cur.fetchone()[0]
    print(f"  Teachers: {teacher_count}")

    # Check availability
    cur.execute("""
        SELECT teacher_id, COUNT(*) as slots
        FROM clean.teacher_availability
        WHERE teacher_id >= 201
        GROUP BY teacher_id
        ORDER BY teacher_id
    """)
    print(f"  Availability slots:")
    for row in cur.fetchall():
        print(f"    Teacher {row[0]}: {row[1]} slots")

    # Check conversion rates
    cur.execute("""
        SELECT teacher_id,
               COUNT(*) as total_trials,
               SUM(CASE WHEN event_type = 'trial_converted' THEN 1 ELSE 0 END) as conversions,
               ROUND(SUM(CASE WHEN event_type = 'trial_converted' THEN 1 ELSE 0 END)::numeric /
                     NULLIF(COUNT(*), 0) * 100, 1) as conversion_rate
        FROM analytics.class_facts
        WHERE teacher_id >= 201
        GROUP BY teacher_id
        ORDER BY conversion_rate DESC
    """)
    print(f"\n  Conversion rates:")
    for row in cur.fetchall():
        print(f"    Teacher {row[0]}: {row[3]}% ({row[2]}/{row[1]})")

if __name__ == '__main__':
    print("=" * 60)
    print("POPULATING TEST DATA FOR MATCHING ENGINE")
    print("=" * 60)

    conn = connect_db()

    try:
        populate_students(conn)
        populate_teachers(conn)
        populate_availability(conn)
        populate_class_facts(conn)
        verify_data(conn)

        print("\n" + "=" * 60)
        print("✅ DATA POPULATION COMPLETE")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Start API: python run_server.py")
        print("2. Test API: python test_api.py")
        print("3. Validate: python validate_matching.py")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        conn.close()
