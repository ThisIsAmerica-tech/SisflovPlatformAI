<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PythonModelProxyController extends Controller
{
    protected $pythonBase;

    public function __construct()
    {
        // Configurable via .env as PYTHON_MODEL_SERVICE (default localhost:8002)
        $this->pythonBase = env('PYTHON_MODEL_SERVICE', 'http://127.0.0.1:8002');
    }

    /**
     * Forward an uploaded image to the Python model service and return the annotated image.
     */
    public function predictImage(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:jpg,jpeg,png'
        ]);

        $file = $request->file('file');
        $path = $file->getRealPath();
        $name = $file->getClientOriginalName();

        try {
            $response = Http::timeout(120)
                ->attach('file', fopen($path, 'r'), $name)
                ->post($this->pythonBase . '/predict/image');
        } catch (\Exception $e) {
            Log::error('Error contacting Python model service: ' . $e->getMessage());
            return response()->json(['error' => 'Model service unreachable', 'details' => $e->getMessage()], 502);
        }

        if ($response->failed()) {
            return response()->json(['error' => 'Model service error', 'details' => $response->body()], 502);
        }

        $contentType = $response->header('Content-Type', 'image/jpeg');
        $detectionsCount = $response->header('X-Detections-Count', 0);

        return response($response->body(), 200)
            ->header('Content-Type', $contentType)
            ->header('X-Detections-Count', $detectionsCount);
    }

    /**
     * Forward an uploaded video to the Python model service and return the processed video.
     */
    public function predictVideo(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimetypes:video/mp4,video/quicktime,video/x-msvideo,video/x-matroska'
        ]);

        $file = $request->file('file');
        $path = $file->getRealPath();
        $name = $file->getClientOriginalName();

        try {
            $response = Http::timeout(600)
                ->attach('file', fopen($path, 'r'), $name)
                ->post($this->pythonBase . '/predict/video');
        } catch (\Exception $e) {
            Log::error('Error contacting Python model service: ' . $e->getMessage());
            return response()->json(['error' => 'Model service unreachable', 'details' => $e->getMessage()], 502);
        }

        if ($response->failed()) {
            return response()->json(['error' => 'Model service error', 'details' => $response->body()], 502);
        }

        $contentType = $response->header('Content-Type', 'video/mp4');

        return response($response->body(), 200)
            ->header('Content-Type', $contentType)
            ->header('Content-Disposition', 'attachment; filename="annotated_' . $name . '"');
    }
}
