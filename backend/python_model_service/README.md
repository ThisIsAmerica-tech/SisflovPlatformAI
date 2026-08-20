SisflovPlatformAI - Python Model Service

This folder contains a small FastAPI service that loads the YOLO model (epoch6.pt)
and exposes endpoints for image and video inference so the Laravel backend or
frontend can consume the model.

Files:
- app.py: FastAPI application (endpoints: /health, /predict/image, /predict/video)
- epoch6.pt: model weights (must be present in this folder)
- requirements.txt: Python requirements for the service

Quick start (from repo root):
1. Ensure a Python virtualenv is active and required packages installed, for example:
   .\.venv\Scripts\activate
   pip install -r SisflovPlatformAI\backend\python_model_service\requirements.txt

2. Run the service (from repo root or from the service folder):
   # from repo root
   python SisflovPlatformAI\backend\python_model_service\app.py

   # or using uvicorn
   uvicorn SisflovPlatformAI.backend.python_model_service.app:app --reload --host 0.0.0.0 --port 8001

Endpoints:
- GET  /health -> simple healthcheck
- POST /predict/image -> form upload (multipart) with field "file" (image). Returns annotated JPEG image (image/jpeg)
- POST /predict/video -> form upload (multipart) with field "file" (video). Returns processed MP4 video

Notes and recommendations:
- The model is loaded once at startup to minimize latency and memory churn.
- For production, run behind a process manager (systemd, supervisor) or containerize the service.
- If integrating with Laravel, call the endpoints from the backend or frontend and forward results as needed.
- By default the service returns an annotated image or video. To return JSON detection details, adapt app.py to include them in the response body or a separate endpoint.
