-- =============================================================================
-- Tulkka Matching Engine — Preferences Migration
-- Adds student preference + teacher profile fields needed for personalization.
-- These are the fields Mahesh requested (from client side / Zoe input).
--
-- Run this once on tulkka_live DB.
-- After running, mobile team adds questions at student signup.
-- Teachers fill their profile form.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. STUDENT PREFERENCES
--    Collected at signup (mobile team to add these questions)
-- -----------------------------------------------------------------------------
CREATE TABLE student_preferences (
    id                      INT AUTO_INCREMENT PRIMARY KEY,
    user_id                 INT NOT NULL UNIQUE,              -- FK to users.id

    -- Hobbies / interests (used to match teacher's topic specialties)
    hobbies                 JSON DEFAULT NULL,                -- e.g. ["sports","music","cooking"]

    -- Language preference: does student want English-only or assisted?
    language_preference     ENUM(
        'english_only',
        'hebrew_assisted',
        'arabic_assisted'
    ) DEFAULT NULL,

    -- Temperament: energetic vs calm student
    temperament             ENUM('energetic', 'calm') DEFAULT NULL,

    -- Corrective tolerance: does student want immediate or indirect correction?
    corrective_tolerance    ENUM('direct', 'indirect') DEFAULT NULL,

    -- Scaffolding preference: quick answers (high) vs let me think (low)
    scaffolding_preference  ENUM('high', 'low') DEFAULT NULL,

    -- Device student uses for classes
    preferred_gadget        ENUM('phone', 'laptop', 'tablet') DEFAULT NULL,

    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_user (user_id)
);


-- -----------------------------------------------------------------------------
-- 2. TEACHER PROFILE
--    Filled by teacher via onboarding form
-- -----------------------------------------------------------------------------
CREATE TABLE teacher_profile (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    user_id             INT NOT NULL UNIQUE,                  -- FK to users.id

    -- Teaching personality style
    teaching_style      ENUM('perky', 'business_like') DEFAULT NULL,

    -- How teacher handles corrections
    correction_style    ENUM('direct', 'indirect') DEFAULT NULL,

    -- How teacher handles student struggling
    scaffolding_style   ENUM('high', 'low') DEFAULT NULL,

    -- Language support: can teacher assist in Hebrew/Arabic or English only?
    language_support    ENUM(
        'english_only',
        'hebrew_assisted',
        'arabic_assisted'
    ) DEFAULT NULL,

    -- Teacher's self-reported max students (replaces hardcoded MAX_CAPACITY=20)
    max_students        INT DEFAULT NULL,

    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_user (user_id)
);


-- =============================================================================
-- WHAT EACH FIELD UNLOCKS IN THE MATCHING ENGINE
-- =============================================================================
-- language_preference vs language_support  → hard filter or strong match signal
-- temperament vs teaching_style            → energetic→perky, calm→business_like
-- corrective_tolerance vs correction_style → direct student → direct teacher
-- scaffolding_preference vs scaffolding_style → high student → high teacher
-- preferred_gadget                         → (future) filter teachers optimized for mobile
-- hobbies                                  → (future) match with teacher topic specialties
-- max_students                             → replaces hardcoded MAX_CAPACITY = 20
-- =============================================================================

BEGIN;

----------------------------------------------------
-- STUDENT MATCHING FIELDS
----------------------------------------------------

ALTER TABLE clean.students

ADD COLUMN IF NOT EXISTS student_age INT,

ADD COLUMN IF NOT EXISTS target_language TEXT DEFAULT 'English',

ADD COLUMN IF NOT EXISTS native_language TEXT,

ADD COLUMN IF NOT EXISTS requires_native_language_teacher BOOLEAN DEFAULT FALSE,

-- schedule preferences (required for matching)

ADD COLUMN IF NOT EXISTS preferred_days TEXT[],

ADD COLUMN IF NOT EXISTS preferred_time_start TIME,

ADD COLUMN IF NOT EXISTS preferred_time_end TIME,

ADD COLUMN IF NOT EXISTS sessions_per_week INT,

-- personalization signals (future)

ADD COLUMN IF NOT EXISTS hobbies JSONB,

ADD COLUMN IF NOT EXISTS language_preference TEXT,

ADD COLUMN IF NOT EXISTS temperament TEXT,

ADD COLUMN IF NOT EXISTS corrective_tolerance TEXT,

ADD COLUMN IF NOT EXISTS scaffolding_preference TEXT,

ADD COLUMN IF NOT EXISTS preferred_gadget TEXT;


----------------------------------------------------
-- TEACHER MATCHING FIELDS
----------------------------------------------------

ALTER TABLE clean.teachers

ADD COLUMN IF NOT EXISTS trial_enabled BOOLEAN DEFAULT TRUE,

ADD COLUMN IF NOT EXISTS recurring_enabled BOOLEAN DEFAULT TRUE,

ADD COLUMN IF NOT EXISTS age_min INT DEFAULT 5,

ADD COLUMN IF NOT EXISTS age_max INT DEFAULT 18,

ADD COLUMN IF NOT EXISTS teacher_tags TEXT[],

ADD COLUMN IF NOT EXISTS languages_spoken TEXT[],

ADD COLUMN IF NOT EXISTS teaching_languages TEXT[],

ADD COLUMN IF NOT EXISTS max_students_capacity INT DEFAULT 20,

ADD COLUMN IF NOT EXISTS current_students INT DEFAULT 0,

ADD COLUMN IF NOT EXISTS trial_priority TEXT DEFAULT 'normal',

ADD COLUMN IF NOT EXISTS teaching_style TEXT,

ADD COLUMN IF NOT EXISTS correction_style TEXT,

ADD COLUMN IF NOT EXISTS scaffolding_style TEXT,

ADD COLUMN IF NOT EXISTS language_support TEXT;


----------------------------------------------------
-- TRIAL PRIORITY CONSTRAINT
----------------------------------------------------

ALTER TABLE clean.teachers
ADD CONSTRAINT IF NOT EXISTS chk_trial_priority
CHECK (trial_priority IN ('high','normal','low','disabled'));


----------------------------------------------------
-- POST TRIAL FEEDBACK
----------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.trial_class_feedback (

feedback_id BIGSERIAL PRIMARY KEY,

class_id INT REFERENCES clean.classes(class_id),

student_id INT REFERENCES clean.students(student_id),

teacher_id INT REFERENCES clean.teachers(teacher_id),

feedback_role TEXT CHECK (feedback_role IN ('student','teacher')),

trial_success BOOLEAN,

teacher_match_quality INT CHECK (teacher_match_quality BETWEEN 1 AND 5),

student_feedback TEXT,

created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);


----------------------------------------------------
-- PERFORMANCE INDEXES
----------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_teachers_trial_enabled
ON clean.teachers(trial_enabled);

CREATE INDEX IF NOT EXISTS idx_teachers_recurring_enabled
ON clean.teachers(recurring_enabled);

CREATE INDEX IF NOT EXISTS idx_teachers_languages
ON clean.teachers USING GIN(languages_spoken);

CREATE INDEX IF NOT EXISTS idx_teachers_tags
ON clean.teachers USING GIN(teacher_tags);

CREATE INDEX IF NOT EXISTS idx_teachers_age_range
ON clean.teachers(age_min, age_max);

CREATE INDEX IF NOT EXISTS idx_students_age
ON clean.students(student_age);

CREATE INDEX IF NOT EXISTS idx_trial_feedback_teacher
ON analytics.trial_class_feedback(teacher_id);

COMMIT;
