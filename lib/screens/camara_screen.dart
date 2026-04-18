import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:uuid/uuid.dart';
import '../widgets/custom_app_bar.dart';
import '../services/bill_detection_service.dart';
import '../services/tts_service.dart';
import '../services/bill_repository.dart';
import '../models/bill_record.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _cameraController;
  final BillDetectionService _detectionService = BillDetectionService();
  final TTSService _ttsService = TTSService();
  final BillRepository _billRepository = BillRepository();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isCameraReady = false;
  String? _initializationError;

  // Variables para enfocar y estabilizar
  double _confidenceThreshold = 0.75;
  int _captureAttempts = 0;
  final int _maxAttempts = 1;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Inicializar la cámara
  Future<void> _initializeCamera() async {
    try {
      // Obtener cámaras disponibles
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _initializationError = 'No se encontró cámara en el dispositivo';
        });
        await _ttsService.speak('No se encontró cámara en el dispositivo');
        return;
      }

      // Usar la cámara trasera (primera)
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Inicializar controlador
      await _cameraController.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isCameraReady = true;
        });

        // Feedback al usuario
        await _ttsService.speak(
            'Cámara lista. Coloca el billete frente a la cámara. '
                'Asegúrate de que esté bien iluminado y centrado.'
        );
      }
    } catch (e) {
      print('❌ Error al inicializar cámara: $e');

      if (mounted) {
        setState(() {
          _isInitialized = true; // Mostrar error
          _initializationError = 'Error al inicializar cámara: $e';
        });
      }

      await _ttsService.speak('Error al inicializar la cámara');
    }
  }

  /// Capturar foto y analizar billete
  Future<void> _captureAndAnalyze() async {
    // Validaciones previas
    if (_isProcessing || !_isInitialized || !_isCameraReady) {
      await _ttsService.speak('Por favor espera, la cámara se está preparando');
      return;
    }

    try {
      setState(() => _isProcessing = true);
      _captureAttempts++;

      // Feedback al usuario
      await _ttsService.speak('Capturando imagen del billete...');

      // Pequeña pausa para estabilidad
      await Future.delayed(const Duration(milliseconds: 500));

      // Capturar foto
      final XFile capturedImage = await _cameraController.takePicture();

      print('📸 Foto capturada: ${capturedImage.path}');

      if (!mounted) return;

      // Análisis con IA
      await _ttsService.speak('Analizando billete con inteligencia artificial...');

      final analysis = await _detectionService.analyzeBill(capturedImage.path);

      if (!mounted) return;

      print('🔍 Análisis completado:');
      print('  - Es billete: ${analysis.hasBilletFeatures}');
      print('  - Auténtico: ${analysis.isAuthentic}');
      print('  - Confianza: ${analysis.confidence}');
      print('  - Denominación: ${analysis.denomination}');

      // Guardar en base de datos
      await _saveBillToDatabase(
        imagePath: capturedImage.path,
        analysis: analysis,
      );

      // Feedback de resultado
      _provideFeedback(analysis);

      // Navegar a pantalla de resultados
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              imagePath: capturedImage.path,
              isAuthentic: analysis.isAuthentic && analysis.hasBilletFeatures,
              confidence: analysis.confidencePercentage,
              denomination: analysis.denomination,
            ),
          ),
        ).then((_) {
          // Reiniciar estado después de volver
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _captureAttempts = 0;
              _isCameraReady = true;
            });
          }
        });
      }
    } catch (e) {
      print('❌ Error al capturar/analizar: $e');

      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          'Error al procesar la imagen',
          'Detalle: $e',
        );
      }

      await _ttsService.speak('Error al procesar la imagen. Intenta de nuevo.');
    }
  }

  /// Guardar billete en la base de datos
  Future<void> _saveBillToDatabase({
    required String imagePath,
    required BillAnalysis analysis,
  }) async {
    try {
      final billRecord = BillRecord(
        id: const Uuid().v4(), // ID único
        date: DateTime.now(),
        imagePath: imagePath,
        isAuthentic: analysis.isAuthentic && analysis.hasBilletFeatures,
        confidence: analysis.confidencePercentage,
        denomination: analysis.denomination,
      );

      final success = await _billRepository.insertBill(billRecord);

      if (success) {
        print('✅ Billete guardado en BD: ${billRecord.id}');
      } else {
        print('⚠️ Error al guardar billete en BD');
      }
    } catch (e) {
      print('❌ Error al guardar en BD: $e');
    }
  }

  /// Proporcionar feedback de voz según resultado
  Future<void> _provideFeedback(BillAnalysis analysis) async {
    String message = '';

    if (!analysis.hasBilletFeatures) {
      message = 'No se detectó un billete. Por favor, asegúrate de que sea un '
          'billete real y que esté bien iluminado. Intenta de nuevo.';
    } else if (analysis.isAuthentic) {
      message = '¡Billete auténtico! Denominación ${analysis.denomination}. '
          'Confianza ${analysis.confidencePercentage}.';
    } else {
      message = 'Advertencia: Este billete podría ser falso. '
          'Confianza ${analysis.confidencePercentage}. '
          'Verifica manualmente o contacta a una autoridad.';
    }

    await _ttsService.speak(message);
  }

  /// Mostrar diálogo de error
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Mostrar overlay de instrucciones
  Widget _buildInstructionOverlay() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.info,
              color: Colors.amber,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Instrucciones:',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Coloca el billete en el centro\n'
                  '• Asegúrate de que esté bien iluminado\n'
                  '• Evita sombras y reflejos\n'
                  '• Presiona el botón para capturar',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostrar guía visual (marco de enfoque)
  Widget _buildFocusGuide() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.25,
      left: 30,
      right: 30,
      height: MediaQuery.of(context).size.height * 0.4,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.amber,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.attach_money,
                color: Colors.amber,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                'Billete aquí',
                style: TextStyle(
                  color: Colors.amber.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón de captura
  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Column(
        children: [
          // Botón circular
          GestureDetector(
            onTap: _isProcessing ? null : _captureAndAnalyze,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isProcessing ? Colors.grey : Colors.amber,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                color: Colors.black,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Indicador de estado
          if (_isProcessing)
            Column(
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Analizando con IA...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Text(
                  'Presiona para capturar',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Intento $_captureAttempts/$_maxAttempts',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Pantalla de inicialización
  Widget _buildInitializingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            strokeWidth: 4,
          ),
          const SizedBox(height: 24),
          Text(
            'Inicializando cámara...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Pantalla de error
  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 24),
            Text(
              'Error de Cámara',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _initializationError ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isInitialized = false;
                  _initializationError = null;
                });
                _initializeCamera();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Confirmar antes de salir si hay captura en progreso
        if (_isProcessing) {
          final shouldPop = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('¿Salir?'),
              content: const Text('Hay una captura en progreso. ¿Deseas salir?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sí'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Capturar Billete'),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.deepPurple.shade900,
                Colors.deepPurple.shade500,
              ],
            ),
          ),
          child: !_isInitialized
              ? _buildInitializingScreen()
              : _initializationError != null
              ? _buildErrorScreen()
              : Stack(
            children: [
              // Vista previa de cámara
              Center(
                child: CameraPreview(_cameraController),
              ),

              // Overlay de instrucciones
              _buildInstructionOverlay(),

              // Guía visual
              _buildFocusGuide(),

              // Botón de captura
              _buildCaptureButton(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _cameraController.dispose();
      _detectionService.dispose();
    } catch (e) {
      print('Error al limpiar recursos: $e');
    }
    super.dispose();
  }
}