import uvicorn
from matching_engine import app

if __name__ == "__main__":
    print("Tulkka Matching Engine (FastAPI) — http://localhost:5000")
    print()
    print("API Documentation:")
    print("  Swagger UI: http://localhost:5000/docs")
    print("  ReDoc:     http://localhost:5000/redoc")
    print()
    print("Test:")
    print('  curl -X POST http://localhost:5000/match -H "Content-Type: application/json" \\')
    print('  -d \'{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}\'')
    print()
    uvicorn.run(app, host="127.0.0.1", port=5000)
