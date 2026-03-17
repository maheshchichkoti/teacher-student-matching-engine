# Matching Engine — Spec Compliance & Quality Assessment

**Scope:** FastAPI implementation in `matching_engine.py` + `availability_service.py`
**Data:** PostgreSQL schemas `clean`, `analytics`, `serve`
**Spec version referenced in code:** `Teacher-Student Matching Engine Feature Specification v1.0 (March 2026)`

---

## 1. Endpoint & Protocol Compliance

- **Implemented endpoints (as in code):**
  - `POST /match` — main matching endpoint (request/response models via Pydantic).
  - `POST /trial-feedback` — writes a single row into `analytics.trial_class_feedback`.
  - `GET /health` — health check, returns `{"status": "ok"}`.
  - `GET /` — root info (version, changes, endpoint summary).

✔️ **Compliant** with the spec’s requirement for a single `/match` endpoint and basic health/info endpoints.
➕ **Extension:** `/trial-feedback` for feedback capture (spec extension, not a deviation).

---

## 2. Data Source & Schema Compliance

### 2.1 Students

**Spec intent:** Use canonical student profile and preference fields; avoid duplicate preference tables.

**Implementation (from `fetch_student` + migrations):**
- Table: `clean.students`
- Fields used:
  - `student_id`, `full_name`, `native_language`, `cefr_level`, `student_age`
  - `target_language`
  - `requires_native_language_teacher`
  - `preferred_days`, `preferred_time_start`, `preferred_time_end`
  - `sessions_per_week`
  - `learning_goal` (via `FINAL_MIGRATION.sql`)

✔️ **Compliant:** student matching dimensions are taken from `clean.students` as per migrations, not from separate `student_preferences` tables.
➕ **Extension:** request-level overrides (`student_age`, `english_level`, `native_language`, `student_tags`, `student_goals`) merge cleanly with DB data.

### 2.2 Teachers

**Spec intent:** Single source of truth for teacher profile, styles, and capacity.

**Implementation (from `fetch_all_teachers` + migrations):**
- Table: `clean.teachers`
- Fields used:
  - `teacher_id`, `full_name`
  - `teaching_languages`
  - `trial_enabled` (mode filter)
  - `age_min`, `age_max`
  - `teacher_tags`
  - `max_students_capacity`
  - `trial_priority`
  - `languages_spoken`
  - `status = 'active'` (hard filter)

✔️ **Compliant:** teacher tags, language and capacity columns are used from `clean.teachers` (per `FINAL_MIGRATION.sql`), not from a separate `teacher_profile` table.

### 2.3 Availability & Conflicts

**Spec intent:** Replicate Node.js availability logic to avoid double-booking.

**Implementation:**
- Base availability:
  - Table: `clean.teacher_availability`
  - Fields: `teacher_id`, `day_of_week` (0=Sun..6=Sat), `start_time`, `end_time`, `is_active`.
  - Expanded to 30‑minute slots with a canonical `DAY_NAMES` mapping shared by both Python modules.
- Holidays:
  - Table: `clean.teacher_holidays`
  - Used to block both trial and recurring slots.
- Existing classes:
  - Table: `clean.classes`, joined to `clean.students` for names.
  - Overlap logic: `meeting_start < slot_end AND COALESCE(meeting_end, meeting_start+30m) > slot_start`.

`AvailabilityService` implements:
- `get_trial_availability` — full 3‑layer trial logic (schedule, holidays, classes) on a 25‑minute slot grid.
- `get_recurring_availability` — 4‑week recurring pattern check using holidays + classes (no schedule check, as in Node.js).
- Occupancy helpers (`calculate_teacher_occupancy`, `get_active_student_count`) that match Node.js aggregation semantics.

✔️ **Compliant:** day-of-week semantics, holiday checks, and class conflict detection are aligned with the documented Node.js behaviour.
✔️ **Compliant:** subscription availability skips schedule checks and relies on conflict checks only, mirroring `monthly-class.controller.js`.

---

## 3. Matching Pipeline vs Spec

The `/match` endpoint implements the 3-stage pipeline described in the spec, with additional safety checks and small extensions.

### 3.1 Step 1 — Hard Filters

Applied in the main loop over `fetch_all_teachers(...)`:
- Teacher must be:
  - `status = 'active'`.
  - `trial_enabled = true` for `mode="trial"`.
  - (For subscription mode) implicitly full‑time; no `recurring_enabled` flag — spec field removed, behaviour simplified.
- Student age must fall into `age_min`–`age_max` when age is known.
- Teacher must be able to teach `target_language` (membership in `teaching_languages`).
- If `requires_native_language_teacher`:
  - Normalise requested native language via `LANGUAGE_CODE_MAP`.
  - Require it to be present in `languages_spoken`.

✔️ **Compliant:** implements language, age, mode and native-language hard filters.
➕ **Extension:** mode is explicitly validated to `"trial"` / `"subscription"` and invalid modes return 400.

### 3.2 Step 2 — Availability

For each eligible teacher:
- Loads the per-teacher availability matrix (expanded 30‑minute slots) from `clean.teacher_availability`.
- For **trial** mode:
  - For each preferred day, calls `AvailabilityService.get_trial_availability(teacher_id, next_date_for_day, 'UTC')`.
  - Filters to slots that fall inside `[preferred_time_from, preferred_time_to]`.
  - If no trial slots remain → teacher is skipped (FIX #1 behaviour).
- For **subscription** mode:
  - For each preferred day, chooses a representative time inside the preferred window (first slot or `18:00`).
  - Calls `AvailabilityService.get_recurring_availability(...)` for the next 4 weeks.
  - If no weekly occurrence is available → teacher is skipped.

All final slot strings are attached to:
- `available_slots` (trial slots; empty in pure subscription mode).
- `recurring_slots` (per‑day recurring options; always present when teacher passes filters).

✔️ **Compliant:** availability is checked against real conflicts and holidays; subscription matching is based on recurring viability, not trial schedules.
✔️ **Compliant:** day-of-week normalisation and preferred-days validation match the spec.

### 3.3 Step 3 — Scoring

The score is computed in `compute_score(...)` and then adjusted by three small post‑score adjustments.

**Base score components (exact weights in code):**
- **Student Fit — 30%**
  - Uses `compute_student_fit`, incorporating:
    - Age vs tags (kids, business, exam).
    - Level vs tags.
    - Tag overlap (student ↔ teacher tags).
    - Learning goals vs tag clusters.
  - Each dimension returns 1.0 (match), 0.3 (mismatch) or 0.5 (neutral / missing).

- **Availability Fit — 25%**
  - `avail_fit = min(len(slots) / 5.0, 1.0)` where `slots` are mode‑appropriate slots.

- **Performance — 20%**
  - `performance = conv_rate*0.40 + retention_rate*0.30 + quality_score*0.30` (all in 0–1 space).
  - Data sources:
    - Conversion: `clean.classes` + `analytics.leads`.
    - Quality: `analytics.class_facts`.
    - Retention: `serve.teacher_performance_profile`.

- **Recurring Compatibility — 15%**
  - Fraction of preferred days that have at least one slot in `score_slots`.

- **Capacity — 10%**
  - `capacity = (max_students - current_students) / max_students`, clamped to [0,1].
  - `max_students` comes from `max_students_capacity` or `MAX_CAPACITY = 20`.

**Post‑score adjustments:**
- `compute_load_balancing_adjustment` — nudges heavily loaded teachers down and under‑utilised teachers up.
- `compute_priority_adjustment` — honours `trial_priority = 'high' | 'normal' | 'low' | 'disabled'`.
- `compute_personalization_adjustment` — extra age/level/tag-based tuning for kids vs teens, beginners vs advanced.

✔️ **Compliant:** weights and core factors match the documented spec; retention has been fully wired into performance as per the v1.1.0 fix.
➕ **Extension:** additional small calibration terms (load balancing, priority, personalisation) improve operational behaviour without breaking the spec’s weighting.

---

## 4. Quality Assessment

This section focuses on the implementation itself (code + data use), not business outcomes.

### 4.1 Strengths

- **End-to-end correctness:**
  - Reads exclusively from the intended PostgreSQL schemas.
  - Applies Node.js‑equivalent availability and conflict rules.
  - Enforces spec hard filters and score weights.

- **Batching & performance considerations:**
  - All large queries are batched per request (no per‑teacher DB calls in the main loop).
  - Availability is fetched for all eligible teachers in a single query.

- **Explainability:**
  - All components of the score can be traced directly to named functions (`compute_student_fit`, `compute_score`, adjustments).
  - Response includes `trial_conversion_rate`, `retention_rate`, `lesson_quality_score`, `current_students`, `free_capacity`, and the three adjustment terms.

- **Spec alignment:**
  - Day-of-week semantics and availability semantics are explicitly documented and enforced in both Python modules.
  - Teacher and student preference fields are taken from the same locations as defined in the SQL migrations.

### 4.2 Known Limitations / Gaps

These are sourced directly from the code and existing analysis notes; no new claims are made:

- **Outcome calibration:**
  The scoring formula is hand‑tuned rather than learned from downstream conversion/retention; rank‑1 accuracy is therefore not yet calibrated from live outcomes.

- **Sparse data behaviour:**
  Teachers with little or no history (few trials, few classes) get neutral-ish performance components and can still surface on the shortlist. The code does include a small “sparse data penalty”, but there is no explicit minimum-evidence threshold.

- **Capacity modelling edge cases:**
  Active student counts are computed from a mix of subscriptions and classes; unusual legacy or edge-case data patterns could cause slight over‑ or under‑counting until fully validated on production‑scale datasets.

- **Preference completeness:**
  Several preference fields (e.g. hobbies/tags, goals) depend on data population quality in `clean.students` and `clean.teachers`. Where data is missing, the engine intentionally falls back to neutral weights (0.5), which is safe but less discriminative.

### 4.3 Readiness Summary

- **For assisted use (human-in-the-loop):**
  ✅ Ready. The implementation is consistent, explainable, and aligned with the spec. It reliably produces a sensible shortlist and exposes enough detail for humans to make the final call.

- **For fully autonomous assignment:**
  ⚠️ Not yet recommended. The engine does not yet close the loop on outcome-based calibration (conversion/retention by archetype) and still relies on hand-tuned weights.

---

## 5. Checklist — What Is Implemented vs Spec

| Area                                   | Status       | Notes |
|----------------------------------------|-------------|-------|
| `/match` endpoint                      | ✅ Implemented | Pydantic request/response models, full pipeline |
| Hard filters (language, age, mode)     | ✅ Implemented | In `match()` loop |
| Native-language hard filter            | ✅ Implemented | Uses `languages_spoken` (FIX #2) |
| Trial availability (3-layer logic)     | ✅ Implemented | `AvailabilityService.get_trial_availability` |
| Subscription availability (4-week)     | ✅ Implemented | `AvailabilityService.get_recurring_availability` |
| Day-of-week canonical mapping          | ✅ Implemented | 0=Sunday shared between both modules (FIX #4) |
| Performance metrics (conversion, quality) | ✅ Implemented | `clean.classes` + `analytics.leads`, `analytics.class_facts` |
| Retention metric                       | ✅ Implemented | `serve.teacher_performance_profile` |
| Scoring weights (30/25/20/15/10)       | ✅ Implemented | `compute_score` |
| Load balancing / capacity              | ✅ Implemented | `fetch_all_student_counts`, adjustments |
| Student tags & goals in scoring        | ✅ Implemented | `compute_student_fit` and personalisation adjustment |
| Response enrichment (rates, tags, slots)| ✅ Implemented | All surfaced in `TeacherResult` model |
| `POST /trial-feedback`                 | ✅ Implemented | Writes to `analytics.trial_class_feedback` |

---

## 6. Conclusion

From a spec and implementation perspective, the current FastAPI + PostgreSQL matching engine:

- Uses the correct schemas and fields for both students and teachers.
- Faithfully reproduces the intended availability and conflict rules from the Node.js backend.
- Implements the documented scoring formula and the v1.1.0 fixes called out in the code header.
- Exposes enough detail in responses to be audited and debugged by both engineering and operations.

The remaining gap to “enterprise-grade, fully autonomous matching” is not a missing implementation detail, but calibration and validation against full production outcome data. That work sits on top of this implementation rather than inside it.

