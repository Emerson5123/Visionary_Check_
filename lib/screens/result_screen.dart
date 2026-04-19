import 'package:flutter/material.dart';
import 'dart:io';
import '../widgets/accessible_widget.dart';
import '../widgets/custom_app_bar.dart';
import '../services/tts_service.dart';
import '../services/accessibility_service.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final bool isAuthentic;
  final String confidence;
  final String denomination;
  final String currency;
  final String details;

  const ResultScreen({
    Key? key,
    required this.imagePath,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
    this.currency = 'UNKNOWN',
    this.details  = '',
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TTSService _tts = TTSService();
  final AccessibilityService _accessibility = AccessibilityService();

  @override
  void initState() {
    super.initState();
    _accessibility.clearFocus();
    _announceResult();
  }

  void _announceResult() async {
    await Future.delayed(const Duration(milliseconds: 400));

    final currencyLabel = widget.currency == 'USD'
        ? 'dólar estadounidense'
        : widget.currency == 'ECU'
        ? 'billete ecuatoriano'
        : 'billete';

    final status = widget.isAuthentic ? 'AUTÉNTICO' : 'SOSPECHOSO';

    await _tts.speak(
      'Resultado: Billete $status. '
          'Es un $currencyLabel de ${widget.denomination}. '
          'Confianza ${widget.confidence}. '
          'Toca cualquier elemento para escuchar más detalles.',
    );
  }

  String get _currencyLabel {
    switch (widget.currency) {
      case 'USD': return 'USD 🇺🇸';
      case 'ECU': return 'Ecuador 🇪🇨';
      default:    return 'Desconocida';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isAuthentic
        ? [Colors.green.shade900, Colors.green.shade500]
        : [Colors.red.shade900,   Colors.red.shade500];

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Resultado',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 10),

              AccessibleWidget(
                description: 'Imagen del billete capturado.',
                onActivate: () => _tts.speak('Imagen del billete capturado.'),
                child: Container(
                  width: 220, height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              AccessibleWidget(
                description: widget.isAuthentic
                    ? 'Resultado: Billete AUTÉNTICO'
                    : 'Resultado: Billete SOSPECHOSO',
                onActivate: () => _tts.speak(
                  widget.isAuthentic
                      ? 'El billete fue verificado como auténtico.'
                      : 'El billete fue marcado como sospechoso. Verifica manualmente.',
                ),
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isAuthentic
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    size: 65,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              AccessibleWidget(
                description: widget.isAuthentic ? 'Estado: AUTÉNTICO' : 'Estado: SOSPECHOSO',
                onActivate: () => _tts.speak(widget.isAuthentic ? 'Auténtico' : 'Sospechoso'),
                child: Text(
                  widget.isAuthentic ? '¡AUTÉNTICO!' : '¡SOSPECHOSO!',
                  style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              AccessibleWidget(
                description:
                'Detalles del billete: '
                    'Denominación ${widget.denomination}. '
                    'Moneda $_currencyLabel. '
                    'Confianza ${widget.confidence}. '
                    '${widget.details}',
                onActivate: () => _tts.speak(
                  'Detalles del billete: '
                      'Denominación ${widget.denomination}. '
                      'Moneda $_currencyLabel. '
                      'Confianza ${widget.confidence}. '
                      '${widget.details}',
                ),
                child: Card(
                  color: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _detailRow('Denominación', widget.denomination),
                        const Divider(color: Colors.white24, height: 24),
                        _detailRow('Moneda', _currencyLabel),
                        const Divider(color: Colors.white24, height: 24),
                        _detailRow('Confianza', widget.confidence),
                        const Divider(color: Colors.white24, height: 24),
                        _detailRow(
                          'Estado',
                          widget.isAuthentic ? 'Auténtico ✅' : 'Sospechoso ⚠️',
                        ),
                        if (widget.details.isNotEmpty) ...[
                          const Divider(color: Colors.white24, height: 24),
                          Text(
                            widget.details,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75), fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              AccessibleButton(
                description: 'Botón verificar otro billete. Vuelve a la pantalla de cámara.',
                label: 'Verificar Otro',
                onActivate: () => Navigator.pop(context),
                backgroundColor: Colors.amber,
                textColor: Colors.black,
                icon: Icons.repeat,
                height: 62,
              ),

              const SizedBox(height: 14),

              AccessibleButton(
                description: 'Botón volver al inicio. Regresa a la pantalla principal.',
                label: 'Volver al Inicio',
                onActivate: () => Navigator.popUntil(context, (route) => route.isFirst),
                backgroundColor: Colors.blueAccent,
                textColor: Colors.white,
                height: 62,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8))),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}