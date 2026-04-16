import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TTSService _ttsService = TTSService();
  String _selectedLanguage = 'es-ES';
  double _volume = 1.0;
  double _speechRate = 0.5;
  bool _enableVoice = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Configuración'),
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
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Sección: Voz
            _buildSectionTitle('Configuración de Voz'),
            const SizedBox(height: 16),

            // Toggle: Habilitar voz
            Card(
              color: Colors.white.withOpacity(0.1),
              child: SwitchListTile(
                title: const Text(
                  'Habilitar Retroalimentación de Voz',
                  style: TextStyle(color: Colors.white),
                ),
                value: _enableVoice,
                onChanged: (value) {
                  setState(() => _enableVoice = value);
                  _ttsService.speak(
                    value ? 'Voz habilitada' : 'Voz deshabilitada',
                  );
                },
                activeColor: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),

            // Slider: Volumen
            Card(
              color: Colors.white.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Volumen',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _volume,
                      onChanged: (value) {
                        setState(() => _volume = value);
                        _ttsService.speak('Volumen ajustado');
                      },
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Slider: Velocidad de habla
            Card(
              color: Colors.white.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Velocidad de Habla',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _speechRate,
                      onChanged: (value) {
                        setState(() => _speechRate = value);
                      },
                      min: 0.1,
                      max: 1.0,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sección: Idioma
            _buildSectionTitle('Idioma'),
            const SizedBox(height: 16),

            Card(
              color: Colors.white.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  dropdownColor: Colors.deepPurple.shade700,
                  items: [
                    DropdownMenuItem(
                      value: 'es-ES',
                      child: Row(
                        children: const [
                          Icon(Icons.language, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Español',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'en-US',
                      child: Row(
                        children: const [
                          Icon(Icons.language, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'English',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedLanguage = value);
                      _ttsService.setLanguage(value);
                      _ttsService.speak(
                        value == 'es-ES' ? 'Idioma cambiado a español' : 'Language changed to English',
                      );
                    }
                  },
                  underline: Container(),
                  isExpanded: true,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sección: Sobre
            _buildSectionTitle('Sobre la Aplicación'),
            const SizedBox(height: 16),

            Card(
              color: Colors.white.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Versión', '1.0.0'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Desarrollador', 'Nathalia'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Año', '2026'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}