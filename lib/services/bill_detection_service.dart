import 'dart:io';
import 'ml_model_service.dart';

class BillDetectionService {
  static final BillDetectionService _instance = BillDetectionService._internal();
  late MLModelService _mlService;

  factory BillDetectionService() {
    return _instance;
  }

  BillDetectionService._internal() {
    _mlService = MLModelService();
    _initialize();
  }

  void _initialize() async {
    await _mlService.initialize();
  }

  Future<BillAnalysis> analyzeBill(String imagePath) async {
    try {
      final result = await _mlService.detectBill(imagePath);

      return BillAnalysis(
        hasBilletFeatures: result.isBill,
        isAuthentic: result.isAuthentic,
        confidence: double.parse(result.confidence) / 100,
        denomination: result.denomination,
        details: result.details,
      );
    } catch (e) {
      print('Error en análisis: $e');
      return BillAnalysis(
        hasBilletFeatures: false,
        isAuthentic: false,
        confidence: 0.0,
        denomination: 'Error',
        details: 'Error al procesar la imagen: $e',
      );
    }
  }

  void dispose() {
    _mlService.dispose();
  }
}

class BillAnalysis {
  final bool hasBilletFeatures;
  final bool isAuthentic;
  final double confidence;
  final String denomination;
  final String details;

  BillAnalysis({
    required this.hasBilletFeatures,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
    required this.details,
  });

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(0)}%';
}