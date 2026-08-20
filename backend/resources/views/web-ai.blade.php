<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Detección YOLO en la Web</title>
    <style>
        :root { color-scheme: dark; }
        body {
            margin: 0;
            font-family: Inter, Arial, sans-serif;
            background: #07111f;
            color: #f8fafc;
        }
        .app { max-width: 1200px; margin: 0 auto; padding: 24px; }
        .hero { display: flex; gap: 20px; align-items: center; justify-content: space-between; margin-bottom: 16px; }
        .card { background: #111827; border-radius: 18px; padding: 16px; box-shadow: 0 10px 30px rgba(0,0,0,.25); }
        .grid { display: grid; grid-template-columns: 2fr 1fr; gap: 16px; }
        video, img, canvas { width: 100%; border-radius: 16px; background: #020617; display: block; }
        .viewport { position: relative; overflow: hidden; border-radius: 16px; background: #020617; }
        .viewport video, .viewport img { width: 100%; height: auto; object-fit: cover; }
        .viewport .overlay { position: absolute; inset: 0; display: none; background: rgba(2,6,23,.15); }
        .viewport .overlay img { width: 100%; height: 100%; object-fit: contain; }
        .toolbar { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
        button { border: 0; border-radius: 999px; padding: 10px 16px; cursor: pointer; font-weight: 700; background: #2563eb; color: white; }
        button.secondary { background: #334155; }
        .status { margin-top: 8px; color: #cbd5e1; font-size: 14px; }
        .pill { display:inline-block; padding:6px 10px; border-radius:999px; background:#0f172a; color:#93c5fd; font-size:12px; font-weight:700; }
        .metrics { display:flex; gap:12px; flex-wrap:wrap; margin-top:10px; }
        .metric { flex:1; background:#0f172a; padding:12px; border-radius:12px; }
        .metric strong { display:block; font-size: 18px; }
        .log { margin-top: 10px; max-height: 240px; overflow: auto; }
        .log .entry { padding: 8px 10px; border-radius: 10px; background:#0f172a; margin-bottom: 8px; }
        @media (max-width: 900px) { .grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
<div class="app">
    <div class="hero">
        <div>
            <div class="pill">YOLO • detección en tiempo real</div>
            <h1 style="margin: 8px 0 4px; font-size: 28px;">Reconocimiento de objetos en la web</h1>
            <p style="margin:0; color:#94a3b8;">La cámara del navegador envía frames al modelo y muestra la visión procesada directamente aquí.</p>
        </div>
        <div class="card" style="min-width: 240px;">
            <div id="connectionState" class="pill">Esperando conexión</div>
            <div class="status" id="statusText">Inicia la transmisión para empezar.</div>
        </div>
    </div>

    <div class="grid">
        <div class="card">
            <div class="toolbar">
                <button id="startBtn">Iniciar transmisión</button>
                <button id="stopBtn" class="secondary">Detener</button>
            </div>
            <div class="viewport">
                <video id="videoEl" autoplay playsinline muted></video>
                <div id="overlay" class="overlay"><img id="resultImage" alt="Resultado del modelo" /></div>
            </div>
            <div class="status" id="frameStats">Sin frames aún.</div>
        </div>
        <div class="card">
            <h3 style="margin-top:0;">Estado del modelo</h3>
            <div class="metrics">
                <div class="metric"><strong id="framesCount">0</strong><span>Frames</span></div>
                <div class="metric"><strong id="detectionsCount">0</strong><span>Detecciones</span></div>
            </div>
            <div class="log" id="logList"></div>
        </div>
    </div>
</div>

<script>
const backendBase = window.location.origin;
const videoEl = document.getElementById('videoEl');
const resultImage = document.getElementById('resultImage');
const overlay = document.getElementById('overlay');
const startBtn = document.getElementById('startBtn');
const stopBtn = document.getElementById('stopBtn');
const statusText = document.getElementById('statusText');
const connectionState = document.getElementById('connectionState');
const frameStats = document.getElementById('frameStats');
const framesCountEl = document.getElementById('framesCount');
const detectionsCountEl = document.getElementById('detectionsCount');
const logList = document.getElementById('logList');

let stream = null;
let animationFrameId = null;
let framesSent = 0;
let detections = 0;
let active = false;
let requestInFlight = false;
let lastDetectionMillis = 0;
let latestRequestToken = 0;
const DETECTION_INTERVAL_MS = 120;
const MAX_FRAME_WIDTH = 640;
let currentResultUrl = null;

function log(message) {
    const entry = document.createElement('div');
    entry.className = 'entry';
    entry.textContent = message;
    logList.prepend(entry);
    while (logList.children.length > 8) logList.removeChild(logList.lastChild);
}

async function checkBackend() {
    try {
        const res = await fetch(`${backendBase}/api/model/predict-image`, { method: 'GET' });
        if (res.ok) {
            connectionState.textContent = 'Backend OK';
            statusText.textContent = 'Listo para enviar frames.';
            return true;
        }
    } catch (e) {
        connectionState.textContent = 'Sin conexión';
        statusText.textContent = 'No se pudo contactar al backend.';
    }
    return false;
}

function captureCurrentFrame() {
    return new Promise((resolve) => {
        const videoWidth = videoEl.videoWidth || 640;
        const videoHeight = videoEl.videoHeight || 480;
        const scale = Math.min(1, MAX_FRAME_WIDTH / videoWidth);
        const canvas = document.createElement('canvas');
        canvas.width = Math.max(1, Math.round(videoWidth * scale));
        canvas.height = Math.max(1, Math.round(videoHeight * scale));
        const ctx = canvas.getContext('2d');
        if (!ctx) {
            resolve(null);
            return;
        }
        ctx.drawImage(videoEl, 0, 0, canvas.width, canvas.height);
        canvas.toBlob((blob) => resolve(blob), 'image/jpeg', 0.7);
    });
}

async function sendFrameForDetection() {
    if (!active || requestInFlight || !videoEl || !videoEl.videoWidth || !videoEl.videoHeight) {
        return;
    }

    const requestToken = ++latestRequestToken;
    requestInFlight = true;
    const blob = await captureCurrentFrame();
    if (!blob) {
        requestInFlight = false;
        return;
    }

    framesSent += 1;
    framesCountEl.textContent = framesSent;
    frameStats.textContent = `Enviando frame #${framesSent}`;

    const form = new FormData();
    form.append('file', blob, 'capture.jpg');

    try {
        const response = await fetch(`${backendBase}/api/model/predict-image`, {
            method: 'POST',
            body: form,
        });
        if (!response.ok) throw new Error('response not ok');

        const imageBlob = await response.blob();
        if (requestToken !== latestRequestToken) {
            return;
        }

        if (currentResultUrl) URL.revokeObjectURL(currentResultUrl);
        currentResultUrl = URL.createObjectURL(imageBlob);
        resultImage.src = currentResultUrl;
        overlay.style.display = 'block';

        detections = Number(response.headers.get('x-detections-count') || 0);
        detectionsCountEl.textContent = detections;
        frameStats.textContent = `Frame #${framesSent} • ${detections} detecciones`;
        connectionState.textContent = 'Procesando';
        statusText.textContent = 'Modelo activo y mostrando resultados.';
    } catch (e) {
        if (requestToken !== latestRequestToken) {
            return;
        }
        connectionState.textContent = 'Error';
        statusText.textContent = 'No se pudo procesar el frame.';
        log('Error de procesamiento: ' + e.message);
    } finally {
        if (requestToken === latestRequestToken) {
            requestInFlight = false;
        }
    }
}

function startFrameLoop() {
    const tick = async () => {
        if (!active) return;

        const now = performance.now();
        if (!requestInFlight && now - lastDetectionMillis >= DETECTION_INTERVAL_MS) {
            lastDetectionMillis = now;
            await sendFrameForDetection();
        }

        animationFrameId = requestAnimationFrame(tick);
    };

    animationFrameId = requestAnimationFrame(tick);
}

async function startStream() {
    if (active) return;
    active = true;
    startBtn.disabled = true;
    stopBtn.disabled = false;

    try {
        stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: false });
        videoEl.srcObject = stream;
        await videoEl.play();
        connectionState.textContent = 'Capturando';
        statusText.textContent = 'Transmitiendo frames al modelo...';
        log('Cámara iniciada');
        checkBackend();
        startFrameLoop();
    } catch (e) {
        active = false;
        startBtn.disabled = false;
        stopBtn.disabled = true;
        connectionState.textContent = 'Error';
        statusText.textContent = 'No se pudo acceder a la cámara.';
        log('No se pudo iniciar cámara: ' + e.message);
    }
}

function stopStream() {
    active = false;
    startBtn.disabled = false;
    stopBtn.disabled = true;
    if (animationFrameId) cancelAnimationFrame(animationFrameId);
    if (stream) {
        stream.getTracks().forEach((track) => track.stop());
        stream = null;
    }
    if (videoEl.srcObject) videoEl.srcObject = null;
    if (currentResultUrl) {
        URL.revokeObjectURL(currentResultUrl);
        currentResultUrl = null;
    }
    overlay.style.display = 'none';
    connectionState.textContent = 'Detenido';
    statusText.textContent = 'Transmisión detenida.';
    log('Transmisión detenida');
}

startBtn.addEventListener('click', startStream);
stopBtn.addEventListener('click', stopStream);
stopBtn.disabled = true;
checkBackend();
</script>
</body>
</html>
