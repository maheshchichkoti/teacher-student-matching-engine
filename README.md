# Tulkka Matching Engine

Rule-based teacher-student matching API. Takes a student ID + preferred schedule, returns top 3 teachers ranked by match score.

## Setup

**Requires Python 3.8+**

```bash
pip install -r requirements.txt
```

## Run the server

```bash
python run_server.py
```

Server starts at `http://localhost:5000`

## Test it

```bash
curl -X POST http://localhost:5000/match \
  -H "Content-Type: application/json" \
  -d '{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}'
```

## Files

| File | Purpose |
|------|---------|
| `matching_engine.py` | Main Flask API — all matching logic lives here |
| `run_server.py` | Starts the server (use this, not matching_engine.py directly) |
| `matching_engine_explainer.html` | Full explanation of how the engine works, data sources, scoring |
| `requirements.txt` | Python dependencies |

## How scoring works

| Factor | Weight | Source |
|--------|--------|--------|
| Student fit (language + level) | 30% | `users` table |
| Availability overlap | 25% | `teacher_availability` table |
| Performance (conversion + quality) | 20% | `trial_class_registrations` + `lesson_feedbacks` |
| Recurring day coverage | 15% | computed from slots |
| Capacity (free slots) | 10% | `classes` table |

Open `matching_engine_explainer.html` in a browser for the full breakdown.

## DB access

Connects to the live Tulkka DB (credentials in `matching_engine.py`).

> **Note:** The DB has an IP whitelist. If you get a connection refused error, send your public IP to Mahesh and ask him to whitelist it, or ask him to run:
> ```sql
> GRANT ALL ON tulkka_live.* TO 'admin'@'%';
> ```
> to allow connections from any IP.

## API

**POST /match**

```json
{
  "student_id": 930,
  "preferred_days": ["Sunday", "Tuesday"],
  "preferred_time_from": "16:00",
  "preferred_time_to": "21:00",
  "mode": "trial"
}
```

**GET /health** — returns `{"status": "ok"}`
