from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import StreamingResponse, FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
from PIL import Image
import uvicorn
import numpy as np
import cv2
import io
import os
import tempfile

app = FastAPI(title="SisflovModelService")

# Allow CORS for local frontend/backend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Model path (relative to this file)
MODEL_PATH = os.path.join(os.path.dirname(__file__), "epoch6.pt")
if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(f"Model file not found at {MODEL_PATH}. Please copy epoch6.pt into this folder.")

# Load model once at startup
print("Loading YOLO model from:", MODEL_PATH)
model = YOLO(MODEL_PATH)
print("Model loaded.")


@app.get("/health")
def health():
    return {"status": "ok"}


def pil_to_bgr_np(pil_img: Image.Image) -> np.ndarray:
    rgb = pil_img.convert("RGB")
    arr = np.array(rgb)
    # Convert RGB to BGR for OpenCV
    return arr[:, :, ::-1].copy()


@app.post("/predict/image")
async def predict_image(file: UploadFile = File(...)):
    # Accepts image upload, runs inference, returns annotated image + JSON detections
    try:
        contents = await file.read()
        pil_img = Image.open(io.BytesIO(contents))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image: {e}")

    frame = pil_to_bgr_np(pil_img)

    # Run inference (synchronous) - tune params if needed
    results = model(frame)  # ultralytics handles numpy arrays

    r = results[0]

    # Annotated frame
    annotated = r.plot()  # returns numpy BGR image

    # Encode annotated image to JPEG
    success, encoded = cv2.imencode('.jpg', annotated)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to encode result image")

    # Build detections JSON
    detections = []
    try:
        boxes = r.boxes
        coords = boxes.xyxy.cpu().numpy() if hasattr(boxes, 'xyxy') else []
        confs = boxes.conf.cpu().numpy() if hasattr(boxes, 'conf') else []
        classes = boxes.cls.cpu().numpy() if hasattr(boxes, 'cls') else []
        for i in range(len(coords)):
            x1, y1, x2, y2 = coords[i].tolist()
            detections.append({
                "bbox": [float(x1), float(y1), float(x2), float(y2)],
                "confidence": float(confs[i]) if len(confs)>i else None,
                "class": int(classes[i]) if len(classes)>i else None,
            })
    except Exception:
        # If structure different, ignore and return minimal info
        pass

    return StreamingResponse(io.BytesIO(encoded.tobytes()), media_type="image/jpeg", headers={"X-Detections-Count": str(len(detections))}, status_code=200)


@app.post("/predict/video")
async def predict_video(file: UploadFile = File(...)):
    # Accepts uploaded video, processes frames and returns annotated video
    suffix = os.path.splitext(file.filename)[1] or '.mp4'
    with tempfile.TemporaryDirectory() as tmpdir:
        in_path = os.path.join(tmpdir, 'input' + suffix)
        out_path = os.path.join(tmpdir, 'output.mp4')

        # Save uploaded file
        with open(in_path, 'wb') as f:
            while True:
                chunk = await file.read(1024*1024)
                if not chunk:
                    break
                f.write(chunk)

        cap = cv2.VideoCapture(in_path)
        if not cap.isOpened():
            raise HTTPException(status_code=400, detail="Cannot open uploaded video")

        fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(out_path, fourcc, fps, (width, height))

        frame_count = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            # Run inference per frame (use track for consistent IDs if needed)
            results = model.track(frame)
            annotated = results[0].plot()
            out.write(annotated)
            frame_count += 1

        cap.release()
        out.release()

        return FileResponse(out_path, media_type='video/mp4', filename='annotated_' + os.path.basename(file.filename))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8002"))
    uvicorn.run(app, host='0.0.0.0', port=port)
