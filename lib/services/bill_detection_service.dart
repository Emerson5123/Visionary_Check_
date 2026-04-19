import 'ml_model_service.dart';

class BillAnalysis {
  final bool hasBilletFeatures;
  final bool isAuthentic;
  final double confidence;
  final String denomination;
  final String currency;      // 'USD' | 'ECU' | 'UNKNOWN'
  final String details;
  final List<String> detectedKeywords;

  BillAnalysis({
    required this.hasBilletFeatures,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
    required this.currency,
    required this.details,
    this.detectedKeywords = const [],
  });

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(0)}%';

  String get currencyLabel {
    switch (currency) {
      case 'USD': return 'USD 🇺🇸';
      case 'ECU': return 'Ecuador 🇪🇨';
      default:    return 'Desconocida';
    }
  }
}

class BillDetectionService {
  static final BillDetectionService _instance = BillDetectionService._internal();
  late MLModelService _mlService;

  factory BillDetectionService() => _instance;

  BillDetectionService._internal() {
    _mlService = MLModelService();
    _mlService.initialize();
  }

  Future<BillAnalysis> analyzeBill(String imagePath) async {
    try {
      final result = await _mlService.detectBill(imagePath);

      final confStr    = result.confidence.replaceAll('%', '');
      final confDouble = (double.tryParse(confStr) ?? 0.0) / 100.0;

      return BillAnalysis(
        hasBilletFeatures: result.isBill,
        isAuthentic:       result.isAuthentic,
        confidence:        confDouble,
        denomination:      result.denomination,
        currency:          result.currency,
        details:           result.details,
        detectedKeywords:  result.detectedKeywords,
      );
    } catch (e) {
      print('Error en BillDetectionService: $e');
      return BillAnalysis(
        hasBilletFeatures: false, isAuthentic: false,
        confidence: 0.0, denomination: 'Error',
        currency: 'UNKNOWN', details: 'Error al procesar la imagen: $e',
      );
    }
  }

  void dispose() => _mlService.dispose();
}