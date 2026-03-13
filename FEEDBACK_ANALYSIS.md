# Feedback Schema Analysis — What's Needed vs Already Exists

**Date:** March 13, 2026  
**Purpose:** Analyze feedback_schema.sql against existing database

---

## 🎯 Critical Finding

**The `feedback_schema.sql` file is for MySQL (tulkka-ai backend), NOT PostgreSQL (matching engine).**

**Two separate systems:**
1. **MySQL (tulkka-ai):** Existing backend with `lesson_feedbacks` table
2. **PostgreSQL (matching engine):** New system with `analytics.trial_class_feedback` table

---

## 📊 What Already Exists in MySQL

### ✅ Existing: `lesson_feedbacks` Table

**Location:** MySQL database (tulkka-ai backend)

**Schema:**
```sql
CREATE TABLE `lesson_feedbacks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `teacher_id` int DEFAULT NULL,
  `student_id` int DEFAULT NULL,
  `class_id` int DEFAULT NULL,
  `grammar_rate` int DEFAULT NULL,
  `pronunciation_rate` int DEFAULT NULL,
  `speaking_rate` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `teacher_id` (`teacher_id`),
  KEY `student_id` (`student_id`),
  KEY `class_id` (`class_id`)
);
```

**Current Data:** 101,571 rows

**Who Provides Feedback:** ❌ **TEACHER ONLY**

**Fields:**
- `grammar_rate` — Teacher rates student's grammar (1-5)
- `pronunciation_rate` — Teacher rates student's pronunciation (1-5)
- `speaking_rate` — Teacher rates student's speaking (1-5)

**Missing:** ❌ **NO STUDENT FEEDBACK**

---

## 🔴 What's Missing

### ❌ Missing: Student Feedback

**Current situation:**
```
After every class:
- Teacher gives feedback ✅ (lesson_feedbacks table)
- Student gives feedback ❌ (NO TABLE)
```

**Problem:** You have no way to know:
- Did student like the lesson?
- Does student want to continue with this teacher?
- What did student think of the teacher?

---

## 📋 Proposed New Tables (from feedback_schema.sql)

### 1. `feedback_student_to_teacher` (NEW)
**Purpose:** Student rates teacher after every class

**Key Fields:**
- `overall_rating` — How was the lesson? (1-5)
- `teacher_punctuality` — Did teacher join on time? (1-5)
- `lesson_clarity` — Was lesson clear? (1-5)
- `want_to_continue` — Want same teacher next time? (YES/NO)

**Why needed:** ✅ **CRITICAL for retention**

---

### 2. `feedback_teacher_to_student` (NEW)
**Purpose:** Teacher rates student after every class

**Key Fields:**
- `engagement` — Was student engaged? (1-5)
- `effort` — Did student make effort? (1-5)
- `good_fit_for_me` — Is this student a good match? (YES/NO)

**Why needed:** ✅ **Helps matching engine learn**

**Overlap with existing:** ⚠️ **OVERLAPS with `lesson_feedbacks`**

**Recommendation:** 
- Keep `lesson_feedbacks` for grammar/pronunciation/speaking scores
- Add `feedback_teacher_to_student` for engagement/fit signals
- OR merge them into one table

---

### 3. `feedback_trial_student` (NEW)
**Purpose:** Student feedback after trial class

**Key Fields:**
- `want_to_enroll` — Want to subscribe? (YES/NO)
- `want_same_teacher` — Keep this teacher? (YES/NO)
- `reason_not_enrolling` — Why not? (price, teacher, schedule, etc.)

**Why needed:** ✅ **CRITICAL for conversion tracking**

---

### 4. `feedback_trial_teacher` (NEW)
**Purpose:** Teacher feedback after trial class

**Key Fields:**
- `assessed_level` — Student's actual level
- `good_fit_for_me` — Would you take this student? (YES/NO)
- `suggested_frequency` — How often should student take classes?

**Why needed:** ✅ **Helps matching engine learn**

---

### 5. `feedback_platform` (NEW)
**Purpose:** Overall platform feedback (NPS)

**Key Fields:**
- `nps_score` — How likely to recommend Tulkka? (0-10)
- `booking_experience` — Was booking easy? (1-5)
- `value_for_money` — Is it worth the price? (1-5)

**Why needed:** ✅ **Product improvement**

---

## 🔴 Preference Tables Analysis

### ❌ NOT NEEDED: `student_preferences` Table

**From feedback_schema.sql:**
```sql
CREATE TABLE student_preferences (
    hobbies JSON,
    language_preference ENUM(...),
    temperament ENUM(...),
    corrective_tolerance ENUM(...),
    scaffolding_preference ENUM(...),
    preferred_gadget ENUM(...)
);
```

**Why not needed:** ❌ **ALREADY IN POSTGRESQL MIGRATION**

**Already added in `FINAL_MIGRATION.sql`:**
```sql
ALTER TABLE clean.students
ADD COLUMN hobbies JSONB,
ADD COLUMN language_preference TEXT,
ADD COLUMN temperament TEXT,
ADD COLUMN corrective_tolerance TEXT,
ADD COLUMN scaffolding_preference TEXT;
```

**Verdict:** ❌ **DO NOT CREATE** (duplicate)

---

### ❌ NOT NEEDED: `teacher_profile` Table

**From feedback_schema.sql:**
```sql
CREATE TABLE teacher_profile (
    teaching_style ENUM(...),
    correction_style ENUM(...),
    scaffolding_style ENUM(...),
    language_support ENUM(...),
    max_students INT
);
```

**Why not needed:** ❌ **ALREADY IN POSTGRESQL MIGRATION**

**Already added in `FINAL_MIGRATION.sql`:**
```sql
ALTER TABLE clean.teachers
ADD COLUMN teaching_style TEXT,
ADD COLUMN correction_style TEXT,
ADD COLUMN scaffolding_style TEXT,
ADD COLUMN max_students_capacity INT;
```

**Verdict:** ❌ **DO NOT CREATE** (duplicate)

---

## 🎯 What You Should Do

### ✅ NEEDED: Feedback Tables (MySQL)

**Create these 5 tables in MySQL (tulkka-ai backend):**

1. `feedback_student_to_teacher` — Student rates teacher after class
2. `feedback_teacher_to_student` — Teacher rates student after class
3. `feedback_trial_student` — Student feedback after trial
4. `feedback_trial_teacher` — Teacher feedback after trial
5. `feedback_platform` — Platform NPS feedback

**Database:** MySQL (tulkka-ai backend)

**Why:** Collect feedback from both students and teachers

---

### ❌ NOT NEEDED: Preference Tables

**DO NOT create:**
- `student_preferences` — Already in PostgreSQL as columns
- `teacher_profile` — Already in PostgreSQL as columns

**Why:** These fields are already added to PostgreSQL in `FINAL_MIGRATION.sql`

---

## 📊 Summary Table

| Table | Database | Status | Action |
|-------|----------|--------|--------|
| `lesson_feedbacks` | MySQL | ✅ Exists | Keep (101,571 rows) |
| `feedback_student_to_teacher` | MySQL | ❌ Missing | ✅ CREATE |
| `feedback_teacher_to_student` | MySQL | ❌ Missing | ✅ CREATE |
| `feedback_trial_student` | MySQL | ❌ Missing | ✅ CREATE |
| `feedback_trial_teacher` | MySQL | ❌ Missing | ✅ CREATE |
| `feedback_platform` | MySQL | ❌ Missing | ✅ CREATE |
| `student_preferences` | MySQL | ❌ Duplicate | ❌ DO NOT CREATE |
| `teacher_profile` | MySQL | ❌ Duplicate | ❌ DO NOT CREATE |
| `analytics.trial_class_feedback` | PostgreSQL | ✅ In migration | Already in FINAL_MIGRATION.sql |

---

## 🎯 Final Recommendation

### For PostgreSQL (Matching Engine)
**Run:** `FINAL_MIGRATION.sql` (already created)
- Adds preference columns to students/teachers
- Creates `analytics.trial_class_feedback` table

### For MySQL (Tulkka-AI Backend)
**Create:** Feedback tables only (remove preference tables)

**I'll create a cleaned-up MySQL feedback schema for you.**

---

**End of Analysis**
