<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DetectionEvent extends Model
{
    // Esto protege nuestra base de datos indicando qué campos se pueden rellenar por la API
    protected $fillable = [
        'camera_id',
        'object_type',
        'is_alert',
        'confidence'
    ];
}