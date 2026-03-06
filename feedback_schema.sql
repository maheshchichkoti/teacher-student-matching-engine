-- =============================================================================
-- Tulkka Feedback Schema
-- Covers all feedback touchpoints across the company
-- Author: Abhiram / Tulkka Engineering
-- =============================================================================
-- Existing table NOTE: lesson_feedbacks already exists (grammar_rate, pronunciation_rate,
-- speaking_rate from teacher side). These new tables are additive — don't drop that table.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. STUDENT → TEACHER (after every regular class)
--    "How was your lesson today?"
-- -----------------------------------------------------------------------------
CREATE TABLE feedback_student_to_teacher (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    class_id            INT NOT NULL,                        -- FK to classes.id
    student_id          INT NOT NULL,                        -- FK to users.id
    teacher_id          INT NOT NULL,                        -- FK to users.id

    -- Ratings (1-5)
    overall_rating      TINYINT NOT NULL,                    -- Overall lesson experience
    teacher_punctuality TINYINT DEFAULT NULL,                -- Did teacher join on time?
    lesson_clarity      TINYINT DEFAULT NULL,                -- Was the lesson clear/structured?
    felt_progress       TINYINT DEFAULT NULL,                -- Did student feel they improved?

    -- Qualitative
    highlight           VARCHAR(500) DEFAULT NULL,           -- What did you like most?
    improvement         VARCHAR(500) DEFAULT NULL,           -- What could be better?

    -- Key retention signal
    want_to_continue    TINYINT(1) DEFAULT NULL,             -- 1=yes, 0=no (want same teacher next time?)

    submitted_at        DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_class_student (class_id, student_id),     -- One feedback per class per student
    INDEX idx_teacher (teacher_id),
    INDEX idx_student (student_id)
);


-- -----------------------------------------------------------------------------
-- 2. TEACHER → STUDENT (after every regular class)
--    "How was your student today?"
-- -----------------------------------------------------------------------------
CREATE TABLE feedback_teacher_to_student (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    class_id            INT NOT NULL,
    teacher_id          INT NOT NULL,
    student_id          INT NOT NULL,

    -- Ratings (1-5)
    engagement          TINYINT DEFAULT NULL,                -- Was student engaged/attentive?
    effort              TINYINT DEFAULT NULL,                -- Did student make effort?
    preparation         TINYINT DEFAULT NULL,                -- Was student prepared?
    progress_observed   TINYINT DEFAULT NULL,                -- Did teacher observe improvement?

    -- Lesson outcome
    lesson_goal_met     TINYINT(1) DEFAULT NULL,             -- 1=yes, 0=no — did student meet lesson goals?
    student_level_note  VARCHAR(255) DEFAULT NULL,           -- Teacher's note on student's level
    next_lesson_focus   VARCHAR(500) DEFAULT NULL,           -- What to focus on next class

    -- Student fit signal (for matching engine)
    good_fit_for_me     TINYINT(1) DEFAULT NULL,             -- 1=yes, 0=no — is this student a good match for this teacher?

    submitted_at        DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_class_teacher (class_id, teacher_id),
    INDEX idx_teacher (teacher_id),
    INDEX idx_student (student_id)
);


-- -----------------------------------------------------------------------------
-- 3. STUDENT → TRIAL CLASS (after trial class only)
--    Higher stakes — this is the conversion moment
-- -----------------------------------------------------------------------------
CREATE TABLE feedback_trial_student (
    id                      INT AUTO_INCREMENT PRIMARY KEY,
    trial_registration_id   INT NOT NULL,                    -- FK to trial_class_registrations.id
    student_id              INT NOT NULL,
    teacher_id              INT NOT NULL,

    -- Core conversion question
    want_to_enroll          TINYINT(1) DEFAULT NULL,         -- 1=yes want to enroll, 0=no
    want_same_teacher       TINYINT(1) DEFAULT NULL,         -- 1=yes keep this teacher, 0=want different

    -- Why they're not enrolling (if want_to_enroll = 0)
    reason_not_enrolling    ENUM(
        'price',
        'teacher_not_right',
        'schedule_doesnt_fit',
        'not_ready_yet',
        'found_alternative',
        'other'
    ) DEFAULT NULL,

    -- Trial experience ratings (1-5)
    overall_trial_rating    TINYINT NOT NULL,
    teacher_communication   TINYINT DEFAULT NULL,
    lesson_structure        TINYINT DEFAULT NULL,
    felt_comfortable        TINYINT DEFAULT NULL,            -- Did student feel comfortable/not judged?

    -- Open feedback
    liked_most              VARCHAR(500) DEFAULT NULL,
    would_change            VARCHAR(500) DEFAULT NULL,

    submitted_at            DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_trial_student (trial_registration_id, student_id),
    INDEX idx_teacher (teacher_id),
    INDEX idx_student (student_id)
);


-- -----------------------------------------------------------------------------
-- 4. TEACHER → TRIAL STUDENT (after trial class)
--    Teacher's assessment of the new student
-- -----------------------------------------------------------------------------
CREATE TABLE feedback_trial_teacher (
    id                      INT AUTO_INCREMENT PRIMARY KEY,
    trial_registration_id   INT NOT NULL,
    teacher_id              INT NOT NULL,
    student_id              INT NOT NULL,

    -- Student assessment
    assessed_level          ENUM('beginner','elementary','pre_intermediate','intermediate',
                                 'upper_intermediate','advanced') DEFAULT NULL,
    student_motivation      TINYINT DEFAULT NULL,            -- 1-5: How motivated did the student seem?
    student_engagement      TINYINT DEFAULT NULL,            -- 1-5

    -- Fit signals (feeds back into matching engine)
    good_fit_for_me         TINYINT(1) DEFAULT NULL,         -- Would you take this student?
    recommended_teacher     VARCHAR(255) DEFAULT NULL,       -- If not a fit, suggest another teacher name

    -- Learning plan
    suggested_goal          VARCHAR(255) DEFAULT NULL,       -- What should this student work on?
    suggested_frequency     ENUM('1x_week','2x_week','3x_week','daily') DEFAULT NULL,

    notes                   VARCHAR(500) DEFAULT NULL,

    submitted_at            DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_trial_teacher (trial_registration_id, teacher_id),
    INDEX idx_teacher (teacher_id),
    INDEX idx_student (student_id)
);


-- -----------------------------------------------------------------------------
-- 5. PLATFORM FEEDBACK (students + teachers about the app/company)
--    "How is your experience with Tulkka as a product?"
-- -----------------------------------------------------------------------------
CREATE TABLE feedback_platform (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,                            -- FK to users.id (student or teacher)
    user_role       ENUM('student','teacher') NOT NULL,

    -- Context: what triggered this feedback?
    trigger_event   ENUM(
        'after_trial',
        'after_class',
        'after_enrollment',
        'after_cancellation',
        'monthly_check_in',
        'voluntary'
    ) NOT NULL,

    -- Overall platform rating (1-5)
    overall_rating      TINYINT NOT NULL,

    -- Student-specific (NULL if teacher)
    booking_experience  TINYINT DEFAULT NULL,                -- Was booking easy?
    app_usability       TINYINT DEFAULT NULL,
    value_for_money     TINYINT DEFAULT NULL,

    -- Teacher-specific (NULL if student)
    scheduling_tools    TINYINT DEFAULT NULL,                -- Are scheduling tools good?
    payment_experience  TINYINT DEFAULT NULL,
    support_quality     TINYINT DEFAULT NULL,

    -- Open feedback
    what_works          VARCHAR(1000) DEFAULT NULL,
    what_to_improve     VARCHAR(1000) DEFAULT NULL,
    feature_request     VARCHAR(500) DEFAULT NULL,

    -- NPS (Net Promoter Score)
    nps_score           TINYINT DEFAULT NULL,                -- 0-10: How likely to recommend Tulkka?

    submitted_at        DATETIME DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_user (user_id),
    INDEX idx_role_trigger (user_role, trigger_event)
);


-- =============================================================================
-- SUMMARY OF TABLES
-- =============================================================================
-- feedback_student_to_teacher  — student rates every class + want_to_continue signal
-- feedback_teacher_to_student  — teacher rates student engagement + good_fit signal
-- feedback_trial_student       — student trial rating + want_to_enroll (conversion signal)
-- feedback_trial_teacher       — teacher assesses trial student + fit signal
-- feedback_platform            — anyone rates the product (NPS + feature requests)
--
-- EXISTING (keep as-is):
-- lesson_feedbacks             — teacher's grammar/pronunciation/speaking ratings (101,571 rows)
-- trial_class_registrations    — trial conversion tracking
-- =============================================================================
