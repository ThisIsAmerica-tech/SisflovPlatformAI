<?php

namespace App\Http\Controllers;

use App\Models\DetectionEvent;
use Illuminate\Http\Request;

class DetectionEventController extends Controller
{
    // Este método será llamado por Python/IA cada vez que detecte algo
    public function store(Request $request) 
    {
        // 1. Validamos que los datos que envía la IA sean correctos
        $validated = $request->validate([
            'camera_id' => 'required|string',
            'object_type' => 'required|string',
            'is_alert' => 'required|boolean',
            'confidence' => 'nullable|numeric'
        ]);

        // 2. Guardamos en la base de datos
        $event = DetectionEvent::create($validated);

        // 3. Respondemos que todo salió bien
        return response()->json([
            'message' => 'Detección registrada con éxito',
            'data' => $event
        ], 201);
    }

    // Este método será llamado por nuestra App en Flutter para ver los logs
    public function index() 
    {
        // Obtenemos las últimas 50 detecciones ordenadas por la más reciente
        $events = DetectionEvent::orderBy('created_at', 'desc')->take(50)->get();
        return response()->json($events);
    }
    
    // Este método cuenta los totales para los contadores grandes de Flutter
    public function stats() 
    {
        $personas = DetectionEvent::where('object_type', 'Persona')->count();
        $autos = DetectionEvent::where('object_type', 'Automóvil')->count();
        $bicicletas = DetectionEvent::where('object_type', 'Bicicleta')->count();
        
        return response()->json([
            'totalPeople' => $personas,
            'totalCars' => $autos,
            'totalBikes' => $bicicletas,
        ]);
    }
}