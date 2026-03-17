BEGIN;

-- =============================================================================
-- STEP 1: Student Table — Add Matching Engine Fields
-- =============================================================================

ALTER TABLE clean.students
ADD COLUMN IF NOT EXISTS student_age INT,
ADD COLUMN IF NOT EXISTS english_level clean.cefr_level,
ADD COLUMN IF NOT EXISTS target_language TEXT DEFAULT 'English',
ADD COLUMN IF NOT EXISTS requires_native_language_teacher BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS preferred_days TEXT[],
ADD COLUMN IF NOT EXISTS preferred_time_start TIME,
ADD COLUMN IF NOT EXISTS preferred_time_end TIME,
ADD COLUMN IF NOT EXISTS sessions_per_week INT;

ALTER TABLE clean.students
ALTER COLUMN native_language TYPE TEXT;

ALTER TABLE clean.students
DROP CONSTRAINT IF EXISTS chk_preferred_days_valid,
ADD CONSTRAINT chk_preferred_days_valid
CHECK (preferred_days IS NULL OR preferred_days <@ ARRAY['mon','tue','wed','thu','fri','sat','sun']);

-- =============================================================================
-- STEP 2: Teacher Table — Add Matching Engine Fields
-- =============================================================================

ALTER TABLE clean.teachers
ADD COLUMN IF NOT EXISTS trial_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS age_min INT DEFAULT 5,
ADD COLUMN IF NOT EXISTS age_max INT DEFAULT 18,
ADD COLUMN IF NOT EXISTS teacher_tags JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS languages_spoken JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS max_students_capacity INT DEFAULT 20,
ADD COLUMN IF NOT EXISTS trial_priority TEXT DEFAULT 'normal';

ALTER TABLE clean.teachers
DROP CONSTRAINT IF EXISTS chk_capacity_positive,
ADD CONSTRAINT chk_capacity_positive
CHECK (max_students_capacity >= 0);

ALTER TABLE clean.teachers
DROP CONSTRAINT IF EXISTS chk_trial_priority,
ADD CONSTRAINT chk_trial_priority
CHECK (trial_priority IN ('high', 'normal', 'low', 'disabled'));

-- =============================================================================
-- STEP 3: Post-Trial Feedback
-- =============================================================================

CREATE TABLE IF NOT EXISTS analytics.trial_class_feedback (
    feedback_id BIGSERIAL PRIMARY KEY,
    class_id INT NOT NULL,
    student_id INT NOT NULL,
    teacher_id INT NOT NULL,
    feedback_role TEXT NOT NULL CHECK (feedback_role IN ('student', 'teacher')),
    trial_success BOOLEAN,
    teacher_match_quality INT CHECK (teacher_match_quality BETWEEN 1 AND 5),
    student_feedback TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_trial_feedback_class FOREIGN KEY (class_id) REFERENCES clean.classes(class_id),
    CONSTRAINT fk_trial_feedback_student FOREIGN KEY (student_id) REFERENCES clean.students(student_id),
    CONSTRAINT fk_trial_feedback_teacher FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id)
);

-- =============================================================================
-- STEP 4: Performance Indexes
-- =============================================================================

-- Student indexes
CREATE INDEX IF NOT EXISTS idx_students_age ON clean.students(student_age);
CREATE INDEX IF NOT EXISTS idx_students_level ON clean.students(english_level);
CREATE INDEX IF NOT EXISTS idx_students_target_lang ON clean.students(target_language);
CREATE INDEX IF NOT EXISTS idx_students_native_lang ON clean.students(native_language);
CREATE INDEX IF NOT EXISTS idx_students_preferred_days ON clean.students USING GIN(preferred_days);

CREATE INDEX IF NOT EXISTS idx_teachers_trial_enabled ON clean.teachers(trial_enabled);
CREATE INDEX IF NOT EXISTS idx_teachers_age_range ON clean.teachers(age_min, age_max);
CREATE INDEX IF NOT EXISTS idx_teachers_capacity ON clean.teachers(max_students_capacity);
CREATE INDEX IF NOT EXISTS idx_teachers_priority ON clean.teachers(trial_priority);
CREATE INDEX IF NOT EXISTS idx_teachers_tags ON clean.teachers USING GIN(teacher_tags);
CREATE INDEX IF NOT EXISTS idx_teachers_languages_spoken ON clean.teachers USING GIN(languages_spoken);

-- Analytics indexes
CREATE INDEX IF NOT EXISTS idx_trial_feedback_student ON analytics.trial_class_feedback(student_id);
CREATE INDEX IF NOT EXISTS idx_trial_feedback_teacher ON analytics.trial_class_feedback(teacher_id);
CREATE INDEX IF NOT EXISTS idx_trial_feedback_success ON analytics.trial_class_feedback(trial_success);

-- =============================================================================
-- STEP 5: Column Comments (Documentation)
-- =============================================================================

COMMENT ON COLUMN clean.students.student_age IS 'Student age for age-range matching with teachers';
COMMENT ON COLUMN clean.students.english_level IS 'Student English proficiency level using CEFR standard (A1-C2)';
COMMENT ON COLUMN clean.students.target_language IS 'Language the student wants to learn (default: English)';
COMMENT ON COLUMN clean.students.native_language IS 'Student native/mother tongue language';
COMMENT ON COLUMN clean.students.requires_native_language_teacher IS 'Hard filter: teacher MUST speak student native language';
COMMENT ON COLUMN clean.students.preferred_days IS 'Preferred lesson days using lowercase 3-letter codes: mon, tue, wed, thu, fri, sat, sun';
COMMENT ON COLUMN clean.students.preferred_time_start IS 'Earliest preferred lesson time';
COMMENT ON COLUMN clean.students.preferred_time_end IS 'Latest preferred lesson time';
COMMENT ON COLUMN clean.students.sessions_per_week IS 'Desired number of lessons per week';

COMMENT ON COLUMN clean.teachers.trial_enabled IS 'Can this teacher receive trial lesson requests?';
COMMENT ON COLUMN clean.teachers.age_min IS 'Minimum student age this teacher works with';
COMMENT ON COLUMN clean.teachers.age_max IS 'Maximum student age this teacher works with';
COMMENT ON COLUMN clean.teachers.teacher_tags IS 'Teaching style tags as JSON array (e.g., ["energetic", "grammar_specialist", "beginner_friendly"])';
COMMENT ON COLUMN clean.teachers.languages_spoken IS 'All languages teacher speaks as JSON array (for native language matching)';
COMMENT ON COLUMN clean.teachers.max_students_capacity IS 'Maximum number of students this teacher can handle';
COMMENT ON COLUMN clean.teachers.trial_priority IS 'Trial lesson distribution priority: high | normal | low | disabled';

COMMENT ON TABLE analytics.trial_class_feedback IS 'Post-trial feedback for matching engine quality improvement and AI training data';

COMMIT;
