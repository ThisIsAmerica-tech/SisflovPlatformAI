<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DetectionEventController;
use App\Http\Controllers\PythonModelProxyController;


// Ruta predeterminada del usuario
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// NUESTRAS RUTAS PARA LA INTELIGENCIA ARTIFICIAL Y FLUTTER
// --------------------------------------------------------

// 1. Ruta para que Python/IA envíe (POST) la detección
Route::post('/detections', [DetectionEventController::class, 'store']);

// 2. Ruta para que Flutter pida (GET) el historial de alertas
Route::get('/detections', [DetectionEventController::class, 'index']);

// 3. Ruta para que Flutter pida (GET) los contadores totales
Route::get('/detections/stats', [DetectionEventController::class, 'stats']);

// === Rutas proxy para el servicio Python (modelo YOLO) ===
// Envío de imagen al servicio Python y retorno de la imagen anotada
Route::get('/model/predict-image', function () {
    return response()->json(['message' => 'Use POST with a multipart file field named "file".'], 405);
});
Route::post('/model/predict-image', [PythonModelProxyController::class, 'predictImage']);

// Envío de video al servicio Python y retorno del video procesado
Route::get('/model/predict-video', function () {
    return response()->json(['message' => 'Use POST with a multipart file field named "file".'], 405);
});
Route::post('/model/predict-video', [PythonModelProxyController::class, 'predictVideo']);