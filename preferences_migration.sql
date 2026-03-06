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
