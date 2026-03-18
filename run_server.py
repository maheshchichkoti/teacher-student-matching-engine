import uvicorn
from matching_engine import app

if __name__ == "__main__":
    import os
    import uvicorn

    # Grab the port Render assigns, but fall back to 5050 for local testing
    port = int(os.environ.get("PORT", 5050))

    print(f"Tulkka Matching Engine (FastAPI) — http://localhost:{port}")
    print()
    print("API Documentation:")
    print(f"  Swagger UI: http://localhost:{port}/docs")
    print(f"  ReDoc:      http://localhost:{port}/redoc")
    print()
    print("Test:")
    print(
        f'  curl -X POST http://localhost:{port}/match -H "Content-Type: application/json" \\'
    )
    print(
        '  -d \'{"student_id": 930, "preferred_days": ["Sunday","Tuesday"], "preferred_time_from": "16:00", "preferred_time_to": "21:00", "mode": "trial"}\''
    )
    print()

    # CRITICAL FIX: host="0.0.0.0" allows Render to route external traffic to your app
    uvicorn.run(app, host="0.0.0.0", port=port)
