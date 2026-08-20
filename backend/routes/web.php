<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\WebAiController;

Route::get('/', function () {
    return redirect()->route('web-ai');
});

Route::get('/web-ai', [WebAiController::class, 'index'])->name('web-ai');
