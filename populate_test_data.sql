-- =============================================================================
-- Populate Test Data for Matching Engine
-- =============================================================================
-- Realistic test data for quality verification
-- Run after FINAL_MIGRATION.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: Populate Students (15 realistic students)
-- =============================================================================

INSERT INTO clean.students (
    student_id, full_name, email, native_language, student_age, english_level,
    target_language, requires_native_language_teacher, preferred_days,
    preferred_time_start, preferred_time_end, sessions_per_week,
    hobbies, language_preference, temperament, corrective_tolerance, scaffolding_preference,
    status, created_at
) VALUES
-- Hebrew students (ages 8-16)
(930, 'Yael Cohen', 'yael.cohen@test.com', 'Hebrew', 12, 'B1', 'English', false, 
 ARRAY['mon','wed','fri'], '16:00', '20:00', 2,
 '["sports","music","reading"]'::jsonb, 'bilingual', 'energetic', 'high', 'high', 'active', NOW()),

(931, 'Noam Levi', 'noam.levi@test.com', 'Hebrew', 14, 'A2', 'English', true,
 ARRAY['tue','thu'], '17:00', '21:00', 2,
 '["gaming","technology","science"]'::jsonb, 'bilingual', 'calm', 'medium', 'low', 'active', NOW()),

(932, 'Tamar Shapiro', 'tamar.shapiro@test.com', 'Hebrew', 10, 'A1', 'English', true,
 ARRAY['mon','wed'], '16:00', '19:00', 3,
 '["art","animals","cooking"]'::jsonb, 'native_only', 'energetic', 'low', 'high', 'active', NOW()),

(933, 'Eitan Goldberg', 'eitan.goldberg@test.com', 'Hebrew', 15, 'B2', 'English', false,
 ARRAY['mon','tue','wed','thu','fri'], '18:00', '21:00', 3,
 '["business","debate","politics"]'::jsonb, 'target_only', 'calm', 'high', 'low', 'active', NOW()),

(934, 'Maya Katz', 'maya.katz@test.com', 'Hebrew', 8, 'A1', 'English', true,
 ARRAY['sun','tue','thu'], '15:00', '18:00', 2,
 '["disney","cartoons","drawing"]'::jsonb, 'native_only', 'energetic', 'low', 'high', 'active', NOW()),

-- Arabic students (ages 9-16)
(935, 'Layla Hassan', 'layla.hassan@test.com', 'Arabic', 13, 'B1', 'English', true,
 ARRAY['mon','wed','fri'], '17:00', '21:00', 2,
 '["fashion","photography","travel"]'::jsonb, 'bilingual', 'calm', 'medium', 'low', 'active', NOW()),

(936, 'Omar Khalil', 'omar.khalil@test.com', 'Arabic', 11, 'A2', 'English', true,
 ARRAY['tue','thu','sat'], '16:00', '20:00', 3,
 '["soccer","sports","youtube"]'::jsonb, 'bilingual', 'energetic', 'high', 'high', 'active', NOW()),

(937, 'Fatima Ali', 'fatima.ali@test.com', 'Arabic', 16, 'C1', 'English', false,
 ARRAY['mon','wed'], '19:00', '22:00', 2,
 '["literature","writing","poetry"]'::jsonb, 'target_only', 'calm', 'high', 'low', 'active', NOW()),

(938, 'Zain Mansour', 'zain.mansour@test.com', 'Arabic', 9, 'A1', 'English', true,
 ARRAY['sun','mon','wed'], '15:00', '18:00', 2,
 '["lego","minecraft","robots"]'::jsonb, 'native_only', 'energetic', 'low', 'high', 'active', NOW()),

-- Mixed backgrounds
(939, 'Sofia Rodriguez', 'sofia.rodriguez@test.com', 'Spanish', 14, 'B1', 'English', false,
 ARRAY['tue','thu','sat'], '17:00', '21:00', 2,
 '["dance","music","friends"]'::jsonb, 'target_only', 'energetic', 'medium', 'low', 'active', NOW()),

(940, 'Dmitri Ivanov', 'dmitri.ivanov@test.com', 'Russian', 15, 'B2', 'English', false,
 ARRAY['mon','wed','fri'], '18:00', '22:00', 3,
 '["chess","programming","math"]'::jsonb, 'target_only', 'calm', 'high', 'low', 'active', NOW()),

(941, 'Mei Chen', 'mei.chen@test.com', 'Chinese', 12, 'A2', 'English', false,
 ARRAY['tue','thu'], '16:00', '20:00', 2,
 '["piano","art","anime"]'::jsonb, 'bilingual', 'calm', 'medium', 'high', 'active', NOW()),

(942, 'Lucas Silva', 'lucas.silva@test.com', 'Portuguese', 13, 'B1', 'English', false,
 ARRAY['mon','wed','fri'], '17:00', '21:00', 2,
 '["soccer","gaming","youtube"]'::jsonb, 'target_only', 'energetic', 'high', 'low', 'active', NOW()),

(943, 'Emma Johnson', 'emma.johnson@test.com', 'French', 11, 'A2', 'English', false,
 ARRAY['tue','thu','sat'], '16:00', '19:00', 3,
 '["reading","horses","nature"]'::jsonb, 'target_only', 'calm', 'medium', 'high', 'active', NOW()),

(944, 'Ali Rahman', 'ali.rahman@test.com', 'Arabic', 10, 'A1', 'English', true,
 ARRAY['sun','tue','thu'], '15:00', '18:00', 2,
 '["cars","dinosaurs","science"]'::jsonb, 'bilingual', 'energetic', 'low', 'high', 'active', NOW())
ON CONFLICT (student_id) DO NOTHING;

-- =============================================================================
-- STEP 2: Populate Teachers (15 realistic teachers)
-- =============================================================================

INSERT INTO clean.teachers (
    teacher_id, full_name, email, timezone, bio,
    teaching_languages, languages_spoken, cefr_can_teach,
    trial_enabled, age_min, age_max, teacher_tags,
    max_students_capacity, current_students, trial_priority,
    teaching_style, correction_style, scaffolding_style,
    status, created_at
) VALUES
-- Native English speakers with Hebrew
(201, 'Sarah Miller', 'sarah.miller@test.com', 'Asia/Jerusalem', 
 'Experienced ESL teacher specializing in young learners. 15 years teaching in Israel.',
 '["English"]'::jsonb, ARRAY['English','Hebrew'], ARRAY['A1','A2','B1','B2','C1'],
 true, 6, 16, ARRAY['kids_friendly','energetic','grammar_specialist'],
 25, 8, 'high', 'perky', 'direct', 'high', 'active', NOW()),

(202, 'David Cohen', 'david.cohen@test.com', 'Asia/Jerusalem',
 'Business English expert. Former corporate trainer. Specializes in teenagers preparing for exams.',
 '["English"]'::jsonb, ARRAY['English','Hebrew'], ARRAY['B1','B2','C1','C2'],
 true, 12, 18, ARRAY['business_english','exam_prep','structured'],
 20, 15, 'normal', 'business_like', 'direct', 'low', 'active', NOW()),

(203, 'Rachel Green', 'rachel.green@test.com', 'Asia/Jerusalem',
 'Fun and interactive teacher for beginners. Uses games and songs. Kids love my classes!',
 '["English"]'::jsonb, ARRAY['English','Hebrew'], ARRAY['A1','A2','B1'],
 true, 5, 12, ARRAY['kids_friendly','beginner_friendly','fun'],
 30, 5, 'high', 'perky', 'indirect', 'high', 'active', NOW()),

-- Native English speakers with Arabic
(204, 'Michael Johnson', 'michael.johnson@test.com', 'Asia/Dubai',
 'CELTA certified. 10 years in Middle East. Specializes in conversational English.',
 '["English"]'::jsonb, ARRAY['English','Arabic'], ARRAY['A2','B1','B2','C1'],
 true, 8, 18, ARRAY['conversation_focused','patient','cultural_expert'],
 22, 12, 'normal', 'business_like', 'indirect', 'low', 'active', NOW()),

(205, 'Fatima Williams', 'fatima.williams@test.com', 'Asia/Dubai',
 'Bilingual teacher (English/Arabic). Great with shy students. Focus on confidence building.',
 '["English"]'::jsonb, ARRAY['English','Arabic'], ARRAY['A1','A2','B1','B2'],
 true, 6, 14, ARRAY['bilingual','supportive','confidence_builder'],
 25, 10, 'high', 'perky', 'indirect', 'high', 'active', NOW()),

-- English-only teachers (immersion)
(206, 'James Anderson', 'james.anderson@test.com', 'Europe/London',
 'British accent. Immersion method specialist. No native language support - full English only.',
 '["English"]'::jsonb, ARRAY['English'], ARRAY['B1','B2','C1','C2'],
 true, 12, 18, ARRAY['immersion','british_accent','advanced_only'],
 18, 16, 'low', 'business_like', 'direct', 'low', 'active', NOW()),

(207, 'Emma Thompson', 'emma.thompson@test.com', 'America/New_York',
 'American accent. Specializes in pronunciation and accent reduction for advanced students.',
 '["English"]'::jsonb, ARRAY['English'], ARRAY['B2','C1','C2'],
 true, 14, 18, ARRAY['pronunciation','american_accent','advanced_only'],
 15, 13, 'normal', 'business_like', 'direct', 'low', 'active', NOW()),

-- Multilingual teachers
(208, 'Anna Petrova', 'anna.petrova@test.com', 'Europe/Moscow',
 'Speaks 5 languages. Great with beginners from any background. Patient and encouraging.',
 '["English"]'::jsonb, ARRAY['English','Russian','Hebrew','Arabic'], ARRAY['A1','A2','B1','B2'],
 true, 7, 16, ARRAY['multilingual','beginner_friendly','patient'],
 28, 6, 'high', 'perky', 'indirect', 'high', 'active', NOW()),

(209, 'Carlos Martinez', 'carlos.martinez@test.com', 'America/Sao_Paulo',
 'Former university professor. Academic English specialist. Excellent for exam preparation.',
 '["English"]'::jsonb, ARRAY['English','Spanish','Portuguese'], ARRAY['B1','B2','C1','C2'],
 true, 13, 18, ARRAY['academic','exam_prep','university_level'],
 20, 14, 'normal', 'business_like', 'direct', 'low', 'active', NOW()),

-- Specialized teachers
(210, 'Lisa Wong', 'lisa.wong@test.com', 'Asia/Singapore',
 'Creative writing and storytelling expert. Makes learning fun through stories and role-play.',
 '["English"]'::jsonb, ARRAY['English','Chinese'], ARRAY['A2','B1','B2'],
 true, 8, 15, ARRAY['creative','storytelling','fun'],
 24, 9, 'normal', 'perky', 'indirect', 'high', 'active', NOW()),

(211, 'Tom Baker', 'tom.baker@test.com', 'Europe/London',
 'Sports and gaming vocabulary specialist. Connects with kids through their interests.',
 '["English"]'::jsonb, ARRAY['English','Hebrew'], ARRAY['A1','A2','B1'],
 true, 8, 14, ARRAY['sports','gaming','kids_friendly'],
 26, 11, 'normal', 'perky', 'direct', 'high', 'active', NOW()),

(212, 'Sophia Kim', 'sophia.kim@test.com', 'Asia/Seoul',
 'STEM vocabulary expert. Perfect for students interested in science and technology.',
 '["English"]'::jsonb, ARRAY['English','Korean'], ARRAY['B1','B2','C1'],
 true, 11, 18, ARRAY['stem','technology','science'],
 20, 7, 'high', 'business_like', 'direct', 'low', 'active', NOW()),

-- Trial-only teachers (testing trial_enabled)
(213, 'Mark Stevens', 'mark.stevens@test.com', 'America/Los_Angeles',
 'Trial lesson specialist. Helps students find the right teacher match.',
 '["English"]'::jsonb, ARRAY['English'], ARRAY['A1','A2','B1','B2'],
 true, 6, 18, ARRAY['trial_specialist','flexible'],
 35, 2, 'high', 'perky', 'indirect', 'high', 'active', NOW()),

-- High-capacity teachers
(214, 'Jennifer Lee', 'jennifer.lee@test.com', 'Asia/Hong_Kong',
 'Group class specialist. Can handle many students. Energetic and organized.',
 '["English"]'::jsonb, ARRAY['English','Chinese','Hebrew'], ARRAY['A1','A2','B1','B2','C1'],
 true, 7, 16, ARRAY['group_specialist','energetic','organized'],
 40, 18, 'normal', 'perky', 'direct', 'high', 'active', NOW()),

-- Near-capacity teacher (for testing capacity scoring)
(215, 'Robert Wilson', 'robert.wilson@test.com', 'Europe/Berlin',
 'Experienced teacher. Almost at capacity. Selective about new students.',
 '["English"]'::jsonb, ARRAY['English','German','Hebrew'], ARRAY['B1','B2','C1','C2'],
 true, 12, 18, ARRAY['selective','experienced','structured'],
 20, 19, 'low', 'business_like', 'direct', 'low', 'active', NOW())
ON CONFLICT (teacher_id) DO NOTHING;

-- =============================================================================
-- STEP 3: Populate Teacher Availability (realistic schedules)
-- =============================================================================

-- Sarah Miller (201) - Available afternoons Mon/Wed/Fri
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(201, 1, '16:00', '20:00', 'Asia/Jerusalem', true),  -- Monday
(201, 3, '16:00', '20:00', 'Asia/Jerusalem', true),  -- Wednesday
(201, 5, '16:00', '20:00', 'Asia/Jerusalem', true)   -- Friday
ON CONFLICT DO NOTHING;

-- David Cohen (202) - Available evenings Tue/Thu
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(202, 2, '18:00', '22:00', 'Asia/Jerusalem', true),  -- Tuesday
(202, 4, '18:00', '22:00', 'Asia/Jerusalem', true)   -- Thursday
ON CONFLICT DO NOTHING;

-- Rachel Green (203) - Available afternoons every day
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(203, 0, '15:00', '19:00', 'Asia/Jerusalem', true),  -- Sunday
(203, 1, '15:00', '19:00', 'Asia/Jerusalem', true),  -- Monday
(203, 2, '15:00', '19:00', 'Asia/Jerusalem', true),  -- Tuesday
(203, 3, '15:00', '19:00', 'Asia/Jerusalem', true),  -- Wednesday
(203, 4, '15:00', '19:00', 'Asia/Jerusalem', true)   -- Thursday
ON CONFLICT DO NOTHING;

-- Michael Johnson (204) - Available Mon/Wed/Fri evenings
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(204, 1, '17:00', '21:00', 'Asia/Dubai', true),
(204, 3, '17:00', '21:00', 'Asia/Dubai', true),
(204, 5, '17:00', '21:00', 'Asia/Dubai', true)
ON CONFLICT DO NOTHING;

-- Fatima Williams (205) - Available Tue/Thu/Sat afternoons
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(205, 2, '16:00', '20:00', 'Asia/Dubai', true),
(205, 4, '16:00', '20:00', 'Asia/Dubai', true),
(205, 6, '16:00', '20:00', 'Asia/Dubai', true)
ON CONFLICT DO NOTHING;

-- James Anderson (206) - Available Mon/Wed evenings (advanced only)
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(206, 1, '19:00', '22:00', 'Europe/London', true),
(206, 3, '19:00', '22:00', 'Europe/London', true)
ON CONFLICT DO NOTHING;

-- Emma Thompson (207) - Available Tue/Thu evenings
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(207, 2, '19:00', '22:00', 'America/New_York', true),
(207, 4, '19:00', '22:00', 'America/New_York', true)
ON CONFLICT DO NOTHING;

-- Anna Petrova (208) - Very flexible, available most days
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(208, 1, '16:00', '21:00', 'Europe/Moscow', true),
(208, 2, '16:00', '21:00', 'Europe/Moscow', true),
(208, 3, '16:00', '21:00', 'Europe/Moscow', true),
(208, 4, '16:00', '21:00', 'Europe/Moscow', true),
(208, 5, '16:00', '21:00', 'Europe/Moscow', true)
ON CONFLICT DO NOTHING;

-- Carlos Martinez (209) - Available Mon/Wed/Fri evenings
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(209, 1, '18:00', '22:00', 'America/Sao_Paulo', true),
(209, 3, '18:00', '22:00', 'America/Sao_Paulo', true),
(209, 5, '18:00', '22:00', 'America/Sao_Paulo', true)
ON CONFLICT DO NOTHING;

-- Lisa Wong (210) - Available Tue/Thu/Sat afternoons
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(210, 2, '16:00', '20:00', 'Asia/Singapore', true),
(210, 4, '16:00', '20:00', 'Asia/Singapore', true),
(210, 6, '16:00', '20:00', 'Asia/Singapore', true)
ON CONFLICT DO NOTHING;

-- Tom Baker (211) - Available Mon/Wed/Fri afternoons
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(211, 1, '16:00', '20:00', 'Europe/London', true),
(211, 3, '16:00', '20:00', 'Europe/London', true),
(211, 5, '16:00', '20:00', 'Europe/London', true)
ON CONFLICT DO NOTHING;

-- Sophia Kim (212) - Available Tue/Thu evenings
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(212, 2, '17:00', '21:00', 'Asia/Seoul', true),
(212, 4, '17:00', '21:00', 'Asia/Seoul', true)
ON CONFLICT DO NOTHING;

-- Mark Stevens (213) - Very flexible (trial specialist)
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(213, 0, '15:00', '21:00', 'America/Los_Angeles', true),
(213, 1, '15:00', '21:00', 'America/Los_Angeles', true),
(213, 2, '15:00', '21:00', 'America/Los_Angeles', true),
(213, 3, '15:00', '21:00', 'America/Los_Angeles', true),
(213, 4, '15:00', '21:00', 'America/Los_Angeles', true)
ON CONFLICT DO NOTHING;

-- Jennifer Lee (214) - Available most days (high capacity)
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(214, 1, '16:00', '21:00', 'Asia/Hong_Kong', true),
(214, 2, '16:00', '21:00', 'Asia/Hong_Kong', true),
(214, 3, '16:00', '21:00', 'Asia/Hong_Kong', true),
(214, 4, '16:00', '21:00', 'Asia/Hong_Kong', true),
(214, 5, '16:00', '21:00', 'Asia/Hong_Kong', true)
ON CONFLICT DO NOTHING;

-- Robert Wilson (215) - Limited availability (near capacity)
INSERT INTO clean.teacher_availability (teacher_id, day_of_week, start_time, end_time, timezone, is_active)
VALUES
(215, 1, '19:00', '21:00', 'Europe/Berlin', true),
(215, 3, '19:00', '21:00', 'Europe/Berlin', true)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- STEP 4: Populate analytics.class_facts (historical performance data)
-- =============================================================================

-- Generate realistic performance data for each teacher
-- High performers
INSERT INTO analytics.class_facts (
    event_type, class_id, student_id, student_email, teacher_id, teacher_name,
    meeting_start, duration_mins, cefr_level_before, cefr_level_after,
    fluency_score, vocabulary_score, grammar_score, occurred_at
)
SELECT 
    CASE 
        WHEN random() < 0.8 THEN 'trial_converted'
        ELSE 'trial_started'
    END,
    1000 + generate_series,
    930 + (random() * 14)::int,
    'student' || (930 + (random() * 14)::int) || '@test.com',
    teacher_id,
    full_name,
    NOW() - (random() * 90 || ' days')::interval,
    30,
    'B1',
    'B1',
    75.0 + (random() * 20)::numeric(5,2),
    78.0 + (random() * 18)::numeric(5,2),
    80.0 + (random() * 15)::numeric(5,2),
    NOW() - (random() * 90 || ' days')::interval
FROM clean.teachers
CROSS JOIN generate_series(1, 20)
WHERE teacher_id IN (201, 203, 205, 208, 213)  -- High performers
ON CONFLICT DO NOTHING;

-- Medium performers
INSERT INTO analytics.class_facts (
    event_type, class_id, student_id, student_email, teacher_id, teacher_name,
    meeting_start, duration_mins, cefr_level_before, cefr_level_after,
    fluency_score, vocabulary_score, grammar_score, occurred_at
)
SELECT 
    CASE 
        WHEN random() < 0.6 THEN 'trial_converted'
        ELSE 'trial_started'
    END,
    2000 + generate_series,
    930 + (random() * 14)::int,
    'student' || (930 + (random() * 14)::int) || '@test.com',
    teacher_id,
    full_name,
    NOW() - (random() * 90 || ' days')::interval,
    30,
    'B1',
    'B1',
    65.0 + (random() * 20)::numeric(5,2),
    68.0 + (random() * 18)::numeric(5,2),
    70.0 + (random() * 15)::numeric(5,2),
    NOW() - (random() * 90 || ' days')::interval
FROM clean.teachers
CROSS JOIN generate_series(1, 15)
WHERE teacher_id IN (202, 204, 209, 210, 211, 212, 214)  -- Medium performers
ON CONFLICT DO NOTHING;

-- Lower performers
INSERT INTO analytics.class_facts (
    event_type, class_id, student_id, student_email, teacher_id, teacher_name,
    meeting_start, duration_mins, cefr_level_before, cefr_level_after,
    fluency_score, vocabulary_score, grammar_score, occurred_at
)
SELECT 
    CASE 
        WHEN random() < 0.4 THEN 'trial_converted'
        ELSE 'trial_started'
    END,
    3000 + generate_series,
    930 + (random() * 14)::int,
    'student' || (930 + (random() * 14)::int) || '@test.com',
    teacher_id,
    full_name,
    NOW() - (random() * 90 || ' days')::interval,
    30,
    'B1',
    'B1',
    55.0 + (random() * 20)::numeric(5,2),
    58.0 + (random() * 18)::numeric(5,2),
    60.0 + (random() * 15)::numeric(5,2),
    NOW() - (random() * 90 || ' days')::interval
FROM clean.teachers
CROSS JOIN generate_series(1, 10)
WHERE teacher_id IN (206, 207, 215)  -- Lower performers (advanced only, near capacity)
ON CONFLICT DO NOTHING;

-- Add retention data (subscription_active events)
INSERT INTO analytics.class_facts (
    event_type, class_id, student_id, student_email, teacher_id, teacher_name,
    meeting_start, duration_mins, occurred_at
)
SELECT 
    'subscription_active',
    4000 + generate_series,
    930 + (random() * 14)::int,
    'student' || (930 + (random() * 14)::int) || '@test.com',
    teacher_id,
    full_name,
    NOW() - (random() * 60 || ' days')::interval,
    30,
    NOW() - (random() * 60 || ' days')::interval
FROM clean.teachers
CROSS JOIN generate_series(1, 15)
WHERE teacher_id IN (201, 203, 205, 208, 213)  -- High retention
ON CONFLICT DO NOTHING;

COMMIT;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Check students
SELECT COUNT(*) as student_count FROM clean.students WHERE student_id >= 930;

-- Check teachers
SELECT COUNT(*) as teacher_count FROM clean.teachers WHERE teacher_id >= 201;

-- Check availability
SELECT teacher_id, COUNT(*) as availability_slots 
FROM clean.teacher_availability 
WHERE teacher_id >= 201 
GROUP BY teacher_id 
ORDER BY teacher_id;

-- Check class facts
SELECT teacher_id, 
       COUNT(*) as total_trials,
       SUM(CASE WHEN event_type = 'trial_converted' THEN 1 ELSE 0 END) as conversions,
       ROUND(SUM(CASE WHEN event_type = 'trial_converted' THEN 1 ELSE 0 END)::numeric / 
             NULLIF(COUNT(*), 0) * 100, 1) as conversion_rate
FROM analytics.class_facts
WHERE teacher_id >= 201
GROUP BY teacher_id
ORDER BY conversion_rate DESC;

-- =============================================================================
-- DATA POPULATION COMPLETE
-- =============================================================================
-- Students: 15 (IDs 930-944)
-- Teachers: 15 (IDs 201-215)
-- Availability: ~50 slots across all teachers
-- Class Facts: ~500 historical events for performance scoring
-- =============================================================================
