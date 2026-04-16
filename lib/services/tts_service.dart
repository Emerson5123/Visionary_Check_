import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  final FlutterTts _flutterTts = FlutterTts();

  factory TTSService() {
    return _instance;
  }

  TTSService._internal() {
    _initTTS();
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }
}