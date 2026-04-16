import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_app_bar.dart';
import '../services/tts_service.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  final TTSService _ttsService = TTSService();
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    await _ttsService.speak('Bienvenido a Visionary Cash Check. '
        'Use el botón grande para capturar un billete.');
  }

  Future<void> _captureImage() async {
    try {
      setState(() => isProcessing = true);
      await _ttsService.speak('Abriendo cámara de detección...');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScreen(),  // ← Sin const
          ),
        );
      }
    } catch (e) {
      await _ttsService.speak('Error al abrir la cámara');
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() => isProcessing = true);
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image != null) {
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                imagePath: image.path,
                isAuthentic: false,
                confidence: '88%',
                denomination: '\$50',
              ),
            ),
          );
        }
      }
    } catch (e) {
      await _ttsService.speak('Error al seleccionar la imagen');
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Visionary Cash Check',
        onHistoryPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          );
        },
        onSettingsPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
      ),
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono principal
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Texto principal
                const Text(
                  'Verificar Billete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Descripción
                Text(
                  'Captura o selecciona una foto de un billete\npara verificar su autenticidad',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 60),

                // Botón principal (Capturar)
                CustomButton(
                  label: 'Capturar Foto',
                  onPressed: isProcessing ? null : () => _captureImage(),
                  backgroundColor: Colors.amber,
                  textColor: Colors.black,
                  height: 70,
                  icon: Icons.camera_alt,
                  isEnabled: !isProcessing,
                ),
                const SizedBox(height: 20),

                // Botón secundario (Galería)
                CustomButton(
                  label: 'Seleccionar de Galería',
                  onPressed: isProcessing ? null : () => _pickImageFromGallery(),
                  backgroundColor: Colors.blueAccent,
                  textColor: Colors.white,
                  height: 60,
                  icon: Icons.image,
                  isEnabled: !isProcessing,
                ),
                const SizedBox(height: 20),

                // Indicador de carga
                if (isProcessing)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Procesando imagen...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
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