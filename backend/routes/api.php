<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DetectionEventController;


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