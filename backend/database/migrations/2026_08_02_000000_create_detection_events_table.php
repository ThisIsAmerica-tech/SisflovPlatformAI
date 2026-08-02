<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Ejecuta las migraciones (Crea la tabla en la base de datos)
     */
    public function up(): void
    {
        Schema::create('detection_events', function (Blueprint $table) {
            // ID único del evento
            $table->id();
            
            // Identificador de la cámara (ej. CAM_CALLE_01)
            $table->string('camera_id');
            
            // Qué detectó la IA (Persona, Automóvil, Bicicleta)
            $table->string('object_type'); 
            
            // Si este evento generó una alerta (ej. persona en zona prohibida)
            $table->boolean('is_alert')->default(false);
            
            // Porcentaje de seguridad de la IA (ej. 98.5%)
            $table->float('confidence')->nullable(); 
            
            // created_at y updated_at automáticos
            $table->timestamps();
        });
    }

    /**
     * Revierte las migraciones
     */
    public function down(): void
    {
        Schema::dropIfExists('detection_events');
    }
};