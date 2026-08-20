from ultralytics import YOLO
import cv2

# Cargamos el modelo YOLO
model = YOLO("epoch6.pt")

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    raise RuntimeError("No se pudo abrir la cámara.")

cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # Ejecuta la detección en cada frame sin imprimir el arreglo completo a consola
    results = model.track(frame, persist=True, verbose=False)
    annotated_frame = results[0].plot()

    # Muestra el video en tiempo real, no como imagen aislada a intervalos
    cv2.imshow("YOLO Inference", annotated_frame)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()