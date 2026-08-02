import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const SmartCityAIApp());
}

class SmartCityAIApp extends StatelessWidget {
  const SmartCityAIApp({super.key});

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
        // Corregido: En versiones recientes de Flutter se utiliza CardThemeData
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 4,
          margin: EdgeInsets.all(8),
        ),
      ),
      home: const AIDashboardScreen(),
    );
  }
}

class AIDashboardScreen extends StatefulWidget {
  const AIDashboardScreen({super.key});

  @override
  State<AIDashboardScreen> createState() => _AIDashboardScreenState();
}

class _AIDashboardScreenState extends State<AIDashboardScreen> {
  // Variables de conteo acumulado
  int totalPeople = 142;
  int totalCars = 89;
  int totalBikes = 14;
  
  // Estado de la conexión simulada con Laravel
  bool isConnectedToLaravel = true;
  
  // Historial de detecciones en vivo
  final List<DetectionLog> _logs = [
    DetectionLog("Persona", "05:14:02", true),
    DetectionLog("Automóvil", "05:13:58", false),
    DetectionLog("Bicicleta", "05:13:45", false),
  ];

  // Simulación de "Cajas de detección" dinámicas sobre la cámara
  List<Rect> boundingBoxes = [
    const Rect.fromLTWH(40, 80, 100, 150),
    const Rect.fromLTWH(180, 120, 120, 80),
  ];
  List<String> boundingBoxLabels = ["Persona 92%", "Auto 88%"];

  Timer? _simulationTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Iniciamos la simulación en tiempo real (emula la llegada de datos de Laravel/Python)
    _startLiveSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startLiveSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;

      setState(() {
        // Decidir qué se detectó al azar
        int choice = _random.nextInt(3);
        String label = "";
        bool isAlert = false;

        if (choice == 0) {
          totalPeople++;
          label = "Persona";
          // 20% de probabilidad de generar una alerta (ej. persona en zona prohibida)
          isAlert = _random.nextDouble() < 0.2; 
        } else if (choice == 1) {
          totalCars++;
          label = "Automóvil";
        } else {
          totalBikes++;
          label = "Bicicleta";
        }

        // Agregar al feed de logs
        String timeStr = DateTime.now().toString().substring(11, 19);
        _logs.insert(0, DetectionLog(label, timeStr, isAlert));
        if (_logs.length > 20) _logs.removeLast(); // Limitar la lista

        // Simular nuevas coordenadas de bounding boxes
        _generateRandomBoundingBoxes();
      });
    });
  }

  void _generateRandomBoundingBoxes() {
    boundingBoxes.clear();
    boundingBoxLabels.clear();
    
    int boxesCount = _random.nextInt(3) + 1;
    for (int i = 0; i < boxesCount; i++) {
      double w = 60 + _random.nextDouble() * 100;
      double h = 60 + _random.nextDouble() * 120;
      double x = _random.nextDouble() * 200;
      double y = 40 + _random.nextDouble() * 120;
      
      boundingBoxes.add(Rect.fromLTWH(x, y, w, h));
      
      String type = _random.nextBool() ? "Persona" : "Auto";
      int confidence = 80 + _random.nextInt(19);
      boundingBoxLabels.add("$type $confidence%");
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
            const Text(
              'CCTV AI • Monitor de Tránsito',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          // Indicador de conexión con Laravel
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: isConnectedToLaravel ? Colors.green : Colors.red,
                radius: 6,
              ),
              label: Text(
                isConnectedToLaravel ? 'Laravel API: OK' : 'Laravel: Offline',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1E293B),
              side: BorderSide.none,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección 1: Feed de Cámara + Contadores rápidos
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 700;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna Cámara
                    Expanded(
                      flex: isWide ? 6 : 0,
                      child: _buildCameraFeedSection(),
                    ),
                    const SizedBox(width: 8, height: 8),
                    // Columna Contadores
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
            // Sección 2: Logs y Alertas de Inteligencia Artificial
            _buildRealtimeLogsSection(),
          ],
        ),
      ),
    );
  }

  // Tarjeta de Vista de Cámara con Bounding Boxes superpuestos
  Widget _buildCameraFeedSection() {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra superior de la cámara
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
          // Frame de video con bounding boxes simulados
          Stack(
            children: [
              // Imagen de fondo (Calle simulada)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?q=80&w=600&auto=format&fit=crop',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF111827),
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              // Capa de las cajas de detección (YOLO Simulation)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: List.generate(boundingBoxes.length, (index) {
                        final rect = boundingBoxes[index];
                        final label = boundingBoxLabels[index];
                        
                        // Adaptar las coordenadas relativas al tamaño actual del contenedor
                        double scaleX = constraints.maxWidth / 350;
                        double scaleY = constraints.maxHeight / 200;

                        return Positioned(
                          left: rect.left * scaleX,
                          top: rect.top * scaleY,
                          width: rect.width * scaleX,
                          height: rect.height * scaleY,
                          child: Container(
                            decoration: BorderStyleCustom.boxBorder(label.contains("Persona")),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  top: -18,
                                  left: -1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    color: label.contains("Persona") 
                                        ? const Color(0xFF3B82F6) 
                                        : const Color(0xFF10B981),
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white, 
                                        fontSize: 9, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Generador de Tarjetas de Contadores
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
                color: color.withOpacity(0.15),
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

  // Sección Inferior: Feed de Detecciones Recientes (Logs)
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
                    color: Colors.blueAccent.withOpacity(0.15),
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
                  ? const Center(child: Text("Esperando detecciones..."))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: log.isAlert 
                                ? const Color(0xFFEF4444).withOpacity(0.1) 
                                : const Color(0xFF0F172A).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: log.isAlert 
                                  ? const Color(0xFFEF4444).withOpacity(0.3) 
                                  : Colors.transparent,
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
                                    log.isAlert 
                                        ? 'Alerta: Cruce Peatonal Indebido Detectado' 
                                        : 'Nueva Detección: ${log.objectType}',
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

// Clase para moldear las alertas e historiales del feed
class DetectionLog {
  final String objectType;
  final String time;
  final bool isAlert;

  DetectionLog(this.objectType, this.time, this.isAlert);
}

// Estilo personalizado para las cajas de detección YOLO
class BorderStyleCustom {
  // Corregido: El contenedor necesita un BoxDecoration, no un Border directo
  static BoxDecoration boxBorder(bool isPerson) {
    return BoxDecoration(
      border: Border.all(
        color: isPerson ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
        width: 2.5,
      ),
    );
  }
}