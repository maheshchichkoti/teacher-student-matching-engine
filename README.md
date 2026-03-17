# Tulkka Matching Engine

Rule-based teacher-student matching API running on FastAPI + PostgreSQL.
Takes a student ID + preferred schedule and returns a ranked shortlist of teachers with scores and slots.

## Setup

**Requires Python 3.8+**

```bash
pip install -r requirements.txt
```

You also need a PostgreSQL database with the `clean`, `analytics` and `serve` schemas
as used in `matching_engine.py` and `availability_service.py`. Connection details
are read from environment variables (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`).

## Run the server

```bash
python run_server.py
```

Server starts at `http://localhost:5050`.

**API Documentation:**
- Swagger UI: `http://localhost:5050/docs`
- ReDoc: `http://localhost:5050/redoc`

## Test it

```bash
curl -X POST http://localhost:5050/match \
  -H "Content-Type: application/json" \
  -d '{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}'
```

## Files

| File | Purpose |
|------|---------|
| `matching_engine.py` | Main FastAPI app — all matching, scoring and API endpoints (`/match`, `/trial-feedback`, `/health`, `/`, `/demo`, `/matching-engine-explainer`) |
| `availability_service.py` | Availability + conflict logic mirroring the Node.js scheduling behaviour on PostgreSQL data |
| `run_server.py` | Convenience entrypoint to start the FastAPI app on port 5050 |
| `matching_engine_explainer.html` | Human-friendly explainer of what the engine does, data sources and scoring (kept in sync with the code) |
| `MATCHING_ENGINE_REPORT.md` | Narrative implementation report for leadership / stakeholders |
| `SPEC_COMPLIANCE_AND_QUALITY_ASSESSMENT.md` | Spec compliance + quality assessment for this matching engine implementation |
| `requirements.txt` | Python dependencies |

## How scoring works (as implemented)

Weights and logic come directly from `compute_score` in `matching_engine.py`:

| Factor | Weight | Source in code / DB |
|--------|--------|---------------------|
| Student fit (age, level, tags, goals) | 30% | `compute_student_fit` using `clean.students` core fields + request-level tags/goals |
| Availability fit (trial/recurring slots) | 25% | Matching between preferred window and slots from `clean.teacher_availability` + `AvailabilityService` |
| Performance (conversion + retention + lesson quality) | 20% | Conversion from `clean.classes` + `analytics.leads`, retention from `serve.teacher_performance_profile`, quality from `analytics.class_facts` |
| Recurring compatibility (day coverage) | 15% | How many preferred days have viable recurring slots (`recurring_slots`) |
| Capacity (free students) | 10% | Active student counts from `clean.classes`, `clean.subscriptions`, `clean.subscription_members` vs `max_students_capacity` |

Additional small bonuses/penalties are applied for:
- load balancing (under/over-utilised teachers),
- teacher priority (`trial_priority`),
- simple age/level-based personalisation tags.

## DB access

The engine connects directly to PostgreSQL using `psycopg2` with configuration from
environment variables. See `DB_CONFIG` in `matching_engine.py` for the exact keys.

## API

**POST `/match`**

Request body (minimal example):

```json
{
  "student_id": 930,
  "preferred_days": ["Sunday", "Tuesday"],
  "preferred_time_from": "16:00",
  "preferred_time_to": "21:00",
  "mode": "trial"
}
```

Optional fields supported by the implementation:
- `student_age`, `english_level`, `native_language`
- `requires_native_language_teacher`
- `target_language` (defaults to `"English"`)
- `student_tags` (list of strings)
- `student_goals` (list of strings)
- `search_option` (e.g. `"earliest_available"`)
- `allow_flexibility_suggestions` (boolean)

**GET `/health`** — returns `{"status": "ok"}`
**GET `/`** — Returns basic API information, version and implemented fixes
**GET `/demo`** — CSV/demo UI served from the same FastAPI app
**GET `/matching-engine-explainer`** — explainer page for stakeholders

**POST `/trial-feedback`** — writes one row into `analytics.trial_class_feedback` with:
- `class_id`, `student_id`, `teacher_id`,
- `trial_success`, `teacher_match_quality`, `student_feedback`.

## Development

For development with auto-reload:

```bash
uvicorn matching_engine:app --reload --port 5050
```

## Production Deployment

For production, use a production ASGI server, pointing at the `app` in `matching_engine.py`:

```bash
uvicorn matching_engine:app --host 0.0.0.0 --port 5050 --workers 4
```
