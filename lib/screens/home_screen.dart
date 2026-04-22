import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/accessible_widget.dart';
import '../widgets/custom_app_bar.dart';
import '../services/accessibility_service.dart';
import '../services/tts_service.dart';
import '../services/permission_service.dart';
import '../services/bill_detection_service.dart';
import '../services/bill_repository.dart';
import '../models/bill_record.dart';
import 'package:uuid/uuid.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'camara_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TTSService            _tts               = TTSService();
  final AccessibilityService  _accessibility     = AccessibilityService();
  final PermissionService     _permissionService = PermissionService();
  final BillDetectionService  _detectionService  = BillDetectionService();
  final BillRepository        _billRepository    = BillRepository();
  final ImagePicker           _imagePicker       = ImagePicker();

  bool _isProcessing = false;

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
    if (_isProcessing) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  Future<void> _openGallery() async {
    if (_isProcessing) return;

    final permResult = await _permissionService.checkAndRequestPhotos();

    if (permResult == PermissionResult.permanentlyDenied) {
      await _tts.speak(
        'El permiso de galería fue denegado permanentemente. '
            'Ve a Configuración del teléfono y activa el acceso a fotos.',
      );
      await _permissionService.openSettings();
      return;
    }

    if (permResult == PermissionResult.denied ||
        permResult == PermissionResult.restricted) {
      await _tts.speak(
        'Se necesita permiso para acceder a la galería. '
            'Por favor otorga el permiso e intenta de nuevo.',
      );
      return;
    }

    try {
      await _tts.speak('Abriendo galería de fotos...');

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) {
        await _tts.speak('No se seleccionó ninguna imagen.');
        return;
      }

      setState(() => _isProcessing = true);
      await _tts.speak('Analizando billete con inteligencia artificial...');

      final analysis = await _detectionService.analyzeBill(image.path);

      final billRecord = BillRecord(
        id: const Uuid().v4(),
        date: DateTime.now(),
        imagePath: image.path,
        isAuthentic: analysis.isAuthentic && analysis.hasBilletFeatures,
        confidence: analysis.confidencePercentage,
        denomination: analysis.denomination,
        currency: analysis.currency,
      );
      await _billRepository.insertBill(billRecord);

      await _provideFeedback(analysis);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imagePath: image.path,
              isAuthentic: analysis.isAuthentic && analysis.hasBilletFeatures,
              confidence: analysis.confidencePercentage,
              denomination: analysis.denomination,
              currency: analysis.currency,
              details: analysis.details,
              detectedFeatures: analysis.detectedFeatures,
              suspiciousIndicators: analysis.suspiciousIndicators,
            ),
          ),
        );
      }
    } catch (e) {
      await _tts.speak('Error al procesar la imagen. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _provideFeedback(BillAnalysis analysis) async {
    final currencyLabel = analysis.currency == 'USD'
        ? 'dólar estadounidense'
        : analysis.currency == 'ECU'
        ? 'billete ecuatoriano'
        : 'billete';

    final featuresText = analysis.detectedFeatures.isEmpty
        ? ''
        : ' Se detectaron ${analysis.detectedFeatures.length} características positivas.';

    final suspiciousText = analysis.suspiciousIndicators.isEmpty
        ? ''
        : ' ${analysis.suspiciousIndicators.length} indicadores sospechosos.';

    if (!analysis.hasBilletFeatures) {
      await _tts.speak(
        'No se detectó un billete en la imagen seleccionada. '
            'Asegúrate de seleccionar una foto clara de un billete.',
      );
    } else if (analysis.isAuthentic) {
      await _tts.speak(
        '¡Billete auténtico! '
            'Es un $currencyLabel de ${analysis.denomination}. '
            'Confianza ${analysis.confidencePercentage}.$featuresText',
      );
    } else {
      await _tts.speak(
        'Advertencia: este $currencyLabel de ${analysis.denomination} '
            'podría ser sospechoso. '
            'Confianza ${analysis.confidencePercentage}.$suspiciousText '
            'Verifica manualmente.',
      );
    }
  }

  void _openHistory() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const HistoryScreen()));

  void _openSettings() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono principal
                AccessibleWidget(
                  description:
                  'Icono de billete. Esta aplicación verifica '
                      'si un billete es auténtico.',
                  onActivate: () => _tts.speak(
                    'Esta aplicación verifica la autenticidad de billetes. '
                        'Usa el botón Capturar Foto para escanear con la cámara, '
                        'o Seleccionar de Galería para usar una foto existente.',
                  ),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0f3460).withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.attach_money, size: 80, color: Color(0xFF00d4ff),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                AccessibleWidget(
                  description: 'Título: Verificar Billete',
                  onActivate: () => _tts.speak('Verificar Billete'),
                  child: const Text(
                    'Verificar Billete',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                AccessibleWidget(
                  description:
                  'Instrucciones: Captura o selecciona una foto de un '
                      'billete para verificar su autenticidad.',
                  onActivate: () => _tts.speak(
                    'Captura con la cámara o selecciona una foto existente '
                        'de un billete para verificar su autenticidad.',
                  ),
                  child: Text(
                    'Captura o selecciona una foto de un billete\n'
                        'para verificar su autenticidad',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Botón 1 — Cámara
                AccessibleButton(
                  description:
                  'Botón Capturar Foto. '
                      'Abre la cámara para fotografiar y verificar un billete.',
                  label: 'Capturar Foto',
                  onActivate: _openCamera,
                  backgroundColor: const Color(0xFF00d4ff),
                  textColor: const Color(0xFF1a1a2e),
                  icon: Icons.camera_alt,
                  height: 70,
                  enabled: !_isProcessing,
                ),

                const SizedBox(height: 16),

                // Botón 2 — Galería
                AccessibleButton(
                  description:
                  'Botón Seleccionar de Galería. '
                      'Elige una foto existente de tu teléfono para verificarla.',
                  label: 'Seleccionar de Galería',
                  onActivate: _openGallery,
                  backgroundColor: const Color(0xFF0f3460),
                  textColor: const Color(0xFF00d4ff),
                  icon: Icons.photo_library,
                  height: 62,
                  enabled: !_isProcessing,
                ),

                const SizedBox(height: 16),

                // Botón 3 — Historial
                AccessibleButton(
                  description:
                  'Botón Ver Historial. '
                      'Muestra las verificaciones anteriores.',
                  label: 'Ver Historial',
                  onActivate: _openHistory,
                  backgroundColor: const Color(0xFF00d4ff),
                  textColor: const Color(0xFF1a1a2e),
                  icon: Icons.history,
                  height: 60,
                  enabled: !_isProcessing,
                ),

                const SizedBox(height: 20),

                // Indicador de carga
                if (_isProcessing)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Analizando imagen...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}