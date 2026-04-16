import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../widgets/custom_app_bar.dart';
import '../services/bill_detection_service.dart';
import '../services/tts_service.dart';
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
  bool _isInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _ttsService.speak('No se encontró cámara en el dispositivo');
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
        _ttsService.speak('Cámara lista. Coloca el billete frente a la cámara');
      }
    } catch (e) {
      _ttsService.speak('Error al inicializar la cámara');
      print('Error: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_isProcessing || !_isInitialized) return;

    try {
      setState(() => _isProcessing = true);
      _ttsService.speak('Capturando imagen...');

      final image = await _cameraController.takePicture();
      await _ttsService.speak('Analizando billete con IA...');

      final analysis = await _detectionService.analyzeBill(image.path);

      if (mounted) {
        String message;
        if (!analysis.hasBilletFeatures) {
          message = 'No se detectó un billete. Por favor, intenta de nuevo.';
        } else if (analysis.isAuthentic) {
          message = 'Billete auténtico. Denominación ${analysis.denomination}. Confianza ${analysis.confidencePercentage}';
        } else {
          message = 'Billete posiblemente falso. Verifica manualmente.';
        }

        _ttsService.speak(message);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              imagePath: image.path,
              isAuthentic: analysis.isAuthentic && analysis.hasBilletFeatures,
              confidence: analysis.confidencePercentage,
              denomination: analysis.denomination,
            ),
          ),
        );
      }
    } catch (e) {
      _ttsService.speak('Error al procesar la imagen');
      print('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _detectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
              const SizedBox(height: 20),
              Text(
                'Inicializando cámara...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
            : Stack(
          children: [
            Center(
              child: CameraPreview(_cameraController),
            ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
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
                      'Coloca el billete en el centro\nAsegúrate de que esté bien iluminado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
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
                ),
                child: Center(
                  child: Text(
                    'Billete aquí',
                    style: TextStyle(
                      color: Colors.amber.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Column(
                children: [
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
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isProcessing)
                    Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Analizando con IA...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Presiona para capturar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}