import 'package:flutter/material.dart';
import 'dart:io';
import '../widgets/custom_button.dart';
import '../widgets/custom_app_bar.dart';
import '../services/tts_service.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final bool isAuthentic;
  final String confidence;
  final String denomination;

  const ResultScreen({
    Key? key,
    required this.imagePath,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TTSService _ttsService = TTSService();

  @override
  void initState() {
    super.initState();
    _announceResult();
  }

  void _announceResult() async {
    String message = widget.isAuthentic
        ? 'El billete es AUTÉNTICO con una confianza del ${widget.confidence}'
        : 'El billete es FALSO con una confianza del ${widget.confidence}';
    await _ttsService.speak(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Resultado de Verificación'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isAuthentic
                ? [Colors.green.shade900, Colors.green.shade500]
                : [Colors.red.shade900, Colors.red.shade500],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Imagen capturada
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Ícono de resultado
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isAuthentic ? Icons.check_circle : Icons.cancel,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // Resultado
                Text(
                  widget.isAuthentic ? '¡AUTÉNTICO!' : '¡FALSO!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Detalles
                Card(
                  color: Colors.white.withOpacity(0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Denominación',
                          widget.denomination,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Confianza',
                          widget.confidence,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Estado',
                          widget.isAuthentic ? 'Auténtico' : 'Falso',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Botones de acción
                CustomButton(
                  label: 'Verificar Otro',
                  onPressed: () => Navigator.pop(context),
                  backgroundColor: Colors.amber,
                  textColor: Colors.black,
                  height: 60,
                  icon: Icons.repeat,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: 'Volver al Inicio',
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  backgroundColor: Colors.blueAccent,
                  textColor: Colors.white,
                  height: 60,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}