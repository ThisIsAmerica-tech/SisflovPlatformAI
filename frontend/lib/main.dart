import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(SmartCityAIApp(cameras: cameras));
}

class SmartCityAIApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const SmartCityAIApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart City AI Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 4,
          margin: EdgeInsets.all(8),
        ),
      ),
      home: AIDashboardScreen(cameras: cameras),
    );
  }
}

class AIDashboardScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const AIDashboardScreen({super.key, required this.cameras});

  @override
  State<AIDashboardScreen> createState() => _AIDashboardScreenState();
}

class _AIDashboardScreenState extends State<AIDashboardScreen> {
  static final String _backendBaseUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000'
          : 'http://127.0.0.1:8000';

  CameraController? _cameraController;
  bool _isProcessing = false;
  bool _detectionActive = false;
  bool _isConnectedToLaravel = false;
  Uint8List? _annotatedImageBytes;
  String _statusMessage = 'Iniciando cámara...';
  String? _lastError;
  int _detectionCount = 0;
  int _captureCount = 0;

  int totalPeople = 142;
  int totalCars = 89;
  int totalBikes = 14;

  final List<DetectionLog> _logs = [
    DetectionLog('Persona', '05:14:02', true),
    DetectionLog('Automóvil', '05:13:58', false),
    DetectionLog('Bicicleta', '05:13:45', false),
  ];

  Timer? _simulationTimer;
  Timer? _detectionTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startLiveSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'No se detectó una cámara en el dispositivo.';
        _lastError = 'Conecta una cámara o usa un emulador/dispositivo con cámara.';
      });
      return;
    }

    final camera = widget.cameras.first;
    _cameraController = CameraController(camera, ResolutionPreset.medium, enableAudio: false);

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isConnectedToLaravel = true;
        _statusMessage = 'Cámara lista. Activa la detección para ver resultados del modelo.';
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'No se pudo inicializar la cámara.';
        _lastError = e.description ?? e.toString();
      });
    }
  }

  void _startLiveSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      setState(() {
        int choice = _random.nextInt(3);
        String label = '';
        bool isAlert = false;

        if (choice == 0) {
          totalPeople++;
          label = 'Persona';
          isAlert = _random.nextDouble() < 0.2;
        } else if (choice == 1) {
          totalCars++;
          label = 'Automóvil';
        } else {
          totalBikes++;
          label = 'Bicicleta';
        }

        String timeStr = DateTime.now().toString().substring(11, 19);
        _logs.insert(0, DetectionLog(label, timeStr, isAlert));
        if (_logs.length > 20) _logs.removeLast();
      });
    });
  }

  Future<void> _toggleDetection() async {
    if (_detectionActive) {
      _detectionTimer?.cancel();
      setState(() {
        _detectionActive = false;
        _statusMessage = 'Detección detenida. Presiona el botón para reanudar.';
      });
      return;
    }

    setState(() {
      _detectionActive = true;
      _statusMessage = 'Detección activada. Procesando cámara en tiempo real...';
      _lastError = null;
    });

    await _captureAndAnalyze();
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      _captureAndAnalyze();
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'La cámara aún no está lista.';
      });
      return;
    }

    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Procesando imagen con el modelo...';
      _lastError = null;
    });

    try {
      final picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendBaseUrl/api/model/predict-image'),
      )..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'camera_capture.jpg'));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.toBytes();
      final contentType = streamedResponse.headers['content-type'] ?? '';

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        if (contentType.startsWith('image/')) {
          setState(() {
            _annotatedImageBytes = responseBody;
            _captureCount += 1;
            _detectionCount = int.tryParse(streamedResponse.headers['x-detections-count'] ?? '0') ?? 0;
            _statusMessage = 'Resultado recibido. Observa la imagen anotada.';
            _isConnectedToLaravel = true;
          });
        } else {
          throw Exception(utf8.decode(responseBody, allowMalformed: true));
        }
      } else {
        final decoded = utf8.decode(responseBody, allowMalformed: true);
        throw Exception(decoded.isNotEmpty ? decoded : 'Error del servidor ${streamedResponse.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnectedToLaravel = false;
        _lastError = e.toString();
        _statusMessage = 'Error al procesar la imagen. Revisa la conexión con el backend.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF3B82F6)),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'CCTV AI • Monitor de Tránsito',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: _isConnectedToLaravel ? Colors.green : Colors.red,
                radius: 6,
              ),
              label: Text(
                _isConnectedToLaravel ? 'Laravel API: OK' : 'Laravel: Offline',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1E293B),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 700;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 6 : 0,
                      child: _buildCameraFeedSection(),
                    ),
                    const SizedBox(width: 8, height: 8),
                    Expanded(
                      flex: isWide ? 4 : 0,
                      child: Column(
                        children: [
                          _buildCounterTile(
                            'Personas Detectadas',
                            totalPeople.toString(),
                            Icons.directions_walk,
                            const Color(0xFF3B82F6),
                          ),
                          _buildCounterTile(
                            'Vehículos Registrados',
                            totalCars.toString(),
                            Icons.directions_car,
                            const Color(0xFF10B981),
                          ),
                          _buildCounterTile(
                            'Ciclistas / Otros',
                            totalBikes.toString(),
                            Icons.pedal_bike,
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _buildRealtimeLogsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraFeedSection() {
    final hasCamera = _cameraController != null && _cameraController!.value.isInitialized;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.videocam, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CÁMARA_AV_PRINCIPAL_01',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  'EN VIVO',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: hasCamera
                    ? CameraPreview(_cameraController!)
                    : Container(
                        color: const Color(0xFF111827),
                        child: const Center(
                          child: Icon(Icons.camera_alt, color: Colors.white38, size: 64),
                        ),
                      ),
              ),
              if (_annotatedImageBytes != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.95,
                    child: Image.memory(
                      _annotatedImageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (_lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _lastError!,
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _toggleDetection,
                  icon: Icon(_detectionActive ? Icons.pause : Icons.play_arrow),
                  label: Text(_detectionActive ? 'Detener detección' : 'Iniciar detección'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Capturas', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(_captureCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Detecciones', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(_detectionCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Endpoint: $_backendBaseUrl/api/model/predict-image',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterTile(String title, String count, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeLogsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.yellow, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Historial de IA en Tiempo Real',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x2625A2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PROCESANDO CON YOLO',
                    style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.grey),
            SizedBox(
              height: 200,
              child: _logs.isEmpty
                  ? const Center(child: Text('Esperando detecciones...'))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: log.isAlert ? const Color(0x1AEF4444) : const Color(0x660F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: log.isAlert ? const Color(0x4DFF4444) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    log.isAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                    color: log.isAlert ? Colors.redAccent : Colors.greenAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    log.isAlert ? 'Alerta: Cruce Peatonal Indebido Detectado' : 'Nueva Detección: ${log.objectType}',
                                    style: TextStyle(
                                      fontWeight: log.isAlert ? FontWeight.bold : FontWeight.normal,
                                      color: log.isAlert ? Colors.redAccent : Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                log.time,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetectionLog {
  final String objectType;
  final String time;
  final bool isAlert;

  DetectionLog(this.objectType, this.time, this.isAlert);
}
