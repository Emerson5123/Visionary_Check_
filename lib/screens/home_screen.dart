import 'package:flutter/material.dart';
import '../widgets/accessible_widget.dart';
import '../widgets/custom_app_bar.dart';
import '../services/accessibility_service.dart';
import '../services/tts_service.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'camara_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TTSService _tts = TTSService();
  final AccessibilityService _accessibility = AccessibilityService();
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _accessibility.clearFocus();
    _welcomeAnnouncement();
  }

  void _welcomeAnnouncement() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak(
      'Bienvenido a Visionary Cash Check. '
          'Toca un elemento una vez para escuchar qué es. '
          'Toca dos veces para activarlo.',
    );
  }

  void _openCamera() {
    if (isProcessing) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
  }

  void _openHistory() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));

  void _openSettings() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Visionary Cash Check',
        onHistoryPressed: _openHistory,
        onSettingsPressed: _openSettings,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade500],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AccessibleWidget(
                  description: 'Icono de billete. Esta aplicación verifica si un billete es auténtico.',
                  onActivate: () => _tts.speak(
                    'Esta aplicación verifica la autenticidad de billetes. '
                        'Usa el botón Capturar Foto para escanear un billete.',
                  ),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.attach_money, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                AccessibleWidget(
                  description: 'Título: Verificar Billete',
                  onActivate: () => _tts.speak('Verificar Billete'),
                  child: const Text('Verificar Billete',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                AccessibleWidget(
                  description: 'Instrucciones: Captura o selecciona una foto de un billete para verificar su autenticidad.',
                  onActivate: () => _tts.speak(
                    'Captura o selecciona una foto de un billete para verificar su autenticidad.',
                  ),
                  child: Text(
                    'Captura o selecciona una foto de un billete\npara verificar su autenticidad',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                  ),
                ),
                const SizedBox(height: 50),
                AccessibleButton(
                  description: 'Botón Capturar Foto. Abre la cámara para escanear un billete.',
                  label: 'Capturar Foto',
                  onActivate: _openCamera,
                  backgroundColor: Colors.amber,
                  textColor: Colors.black,
                  icon: Icons.camera_alt,
                  height: 70,
                  enabled: !isProcessing,
                ),
                const SizedBox(height: 20),
                AccessibleButton(
                  description: 'Botón Ver Historial. Muestra las verificaciones anteriores.',
                  label: 'Ver Historial',
                  onActivate: _openHistory,
                  backgroundColor: Colors.blueAccent,
                  textColor: Colors.white,
                  icon: Icons.history,
                  height: 60,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}