import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';
import 'fuzzy_matcher_service.dart';
import 'authenticity_detector_v2.dart';

class EnhancedDenominationDetector {
  static final EnhancedDenominationDetector _instance =
  EnhancedDenominationDetector._internal();

  late TextRecognizer _textRecognizer;
  bool _isInitialized = false;

  factory EnhancedDenominationDetector() => _instance;

  EnhancedDenominationDetector._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _isInitialized = true;
    print('✅ Denominación detector V2 inicializado');
  }

  Future<DenominationDetectionResult> detectDenomination(
      String imagePath,
      String currency,
      ) async {
    try {
      await initialize();

      final image = img.decodeImage(File(imagePath).readAsBytesSync());
      if (image == null) throw Exception('No se pudo decodificar');

      print('\n🔍 ═══════════════════════════════════════════════════');
      print('🔍 DETECCIÓN V2.0 - MEJORADA');
      print('🔍 ═══════════════════════════════════════════════════\n');

      // CAPA 1: OCR
      print('📝 CAPA 1: OCR...');
      final ocrResults = await _performOCR(imagePath);

      // CAPA 2: Análisis de Fuzzy Matching
      print('🔎 CAPA 2: Fuzzy Matching (Levenshtein)...');
      final fuzzyResult = _analyzeFuzzyKeywords(ocrResults['text'] as String, currency);

      // CAPA 3: Búsqueda de números directo
      print('🔢 CAPA 3: Búsqueda de números...');
      final numericResult = _analyzeNumbers(ocrResults['text'] as String);

      // CAPA 4: Análisis de líneas individuales
      print('📋 CAPA 4: Análisis por línea...');
      final lineResult = _analyzeByLines(ocrResults['text'] as String, currency);

      // CAPA 5: Detección de fotocopia
      print('📸 CAPA 5: Detección de fotocopia...');
      final authenticityScore = await AuthenticityDetectorV2.detectPhotocopy(image);

      // FUSIÓN
      print('🧠 CAPA 6: Fusionando...');
      final finalResult = _fuseAllResults(
        fuzzyResult: fuzzyResult,
        numericResult: numericResult,
        lineResult: lineResult,
        authenticity: authenticityScore,
        currency: currency,
      );

      print('═══════════════════════════════════════════════════');
      print('✅ RESULTADO: ${finalResult.denomination}');
      print('   Confianza: ${(finalResult.confidence * 100).toStringAsFixed(1)}%');
      print('═══════════════════════════════════════════════════\n');

      return finalResult;
    } catch (e) {
      print('❌ Error: $e\n');
      return DenominationDetectionResult(
        denomination: 'Error',
        confidence: 0.0,
        method: 'error',
        allCandidates: {},
        reasoning: 'Error: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _performOCR(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text.toUpperCase();

      print('   ✓ ${text.length} caracteres detectados');

      return {
        'text': text,
        'blocks': recognized.blocks,
        'confidence': _calculateOCRConfidence(recognized),
      };
    } catch (e) {
      print('   ⚠️ Error OCR: $e');
      return {
        'text': '',
        'blocks': [],
        'confidence': 0.0,
      };
    }
  }

  double _calculateOCRConfidence(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) return 0.0;

    double total = 0.0;
    int count = 0;

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final conf = element.confidence ?? 0.0;
          total += conf;
          count++;
        }
      }
    }

    return count > 0 ? (total / count).clamp(0.0, 1.0) : 0.0;
  }

  DenominationCandidate _analyzeFuzzyKeywords(
      String text,
      String currency,
      ) {
    final candidates = <String, int>{};
    final keywordMap =
    currency == 'USD' ? _getUSDKeywords() : _getEcuadorKeywords();

    print('   Buscando en ${keywordMap.length} denominaciones...');

    for (final entry in keywordMap.entries) {
      final denom = entry.key;
      final keywords = entry.value;

      int matchCount = 0;

      for (final keyword in keywords) {
        if (FuzzyMatcherService.fuzzyContains(text, keyword,
            threshold: 0.70)) {
          matchCount++;
        }
      }

      if (matchCount > 0) {
        candidates[denom] = matchCount;
        print('   ✓ \$$denom: $matchCount coincidencias');
      }
    }

    if (candidates.isEmpty) {
      return DenominationCandidate(
        denomination: 'Unknown',
        confidence: 0.0,
        method: 'fuzzy',
        allCandidates: {},
      );
    }

    String best = candidates.keys.first;
    int bestScore = candidates[best]!;

    candidates.forEach((d, s) {
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    });

    final totalKeywords = keywordMap.values.first.length;
    final confidence = (bestScore / totalKeywords).clamp(0.0, 1.0);

    return DenominationCandidate(
      denomination: best,
      confidence: confidence,
      method: 'fuzzy',
      allCandidates: {
        for (final e in candidates.entries)
          e.key: (e.value / totalKeywords).clamp(0.0, 1.0)
      },
    );
  }

  DenominationCandidate _analyzeNumbers(String text) {
    final denom = FuzzyMatcherService.findDenominationNumber(text);

    if (denom != null) {
      print('   ✓ Número encontrado: \$$denom');
      return DenominationCandidate(
        denomination: denom,
        confidence: 0.8,
        method: 'numeric',
        allCandidates: {denom: 0.8},
      );
    }

    print('   ✗ Sin números detectados');
    return DenominationCandidate(
      denomination: 'Unknown',
      confidence: 0.0,
      method: 'numeric',
      allCandidates: {},
    );
  }

  DenominationCandidate _analyzeByLines(String text, String currency) {
    final lines = FuzzyMatcherService.extractLines(text);
    final candidates = <String, int>{};

    print('   Analizando ${lines.length} líneas...');

    for (final line in lines) {
      // Denominación $20
      if (line.contains('JACKSON') || line.contains('ACKSON') ||
          line.contains('WHITE') || line.contains('HOUSE') ||
          line.contains('TWENTY')) {
        candidates['20'] = (candidates['20'] ?? 0) + 5;
        print('   ✓ Línea contiene palabras de \$20');
      }

      // Denominación $10
      if (line.contains('HAMILTON') || line.contains('AMILTON') ||
          line.contains('HAMILTON') || line.contains('TREASURY') ||
          line.contains('SECRETARY') || line.contains('TEN')) {
        candidates['10'] = (candidates['10'] ?? 0) + 5;
        print('   ✓ Línea contiene palabras de \$10');
      }

      // Denominación $5
      if (line.contains('LINCOLN') || line.contains('INCOLN') ||
          line.contains('MEMORIAL') || line.contains('EMORIAL') ||
          line.contains('FIVE') || line.contains('LOG CABIN')) {
        candidates['5'] = (candidates['5'] ?? 0) + 5;
        print('   ✓ Línea contiene palabras de \$5');
      }

      // Denominación $1
      if (line.contains('WASHINGTON') || line.contains('ASHINGTON') ||
          line.contains('VERNON') || line.contains('ONE DOLL') ||
          line.contains('SEAL')) {
        candidates['1'] = (candidates['1'] ?? 0) + 5;
        print('   ✓ Línea contiene palabras de \$1');
      }

      // Denominación $50
      if (line.contains('GRANT') || line.contains('CAPITOL') ||
          line.contains('APITOL') || line.contains('FIFTY') ||
          line.contains('CIVIL WAR')) {
        candidates['50'] = (candidates['50'] ?? 0) + 5;
        print('   ✓ Línea contiene palabras de \$50');
      }

      // Denominación $100
      if (line.contains('FRANKLIN') || line.contains('RANKLIN') ||
          line.contains('INDEPENDENCE') || line.contains('HALL') ||
          line.contains('HUNDRED')) {
        candidates['100'] = (candidates['100'] ?? 0) + 5;
        print('   ✓ Línea contiene palabras de \$100');
      }

      // Detectar números directos en la línea
      final lineNumbers = FuzzyMatcherService.extractNumbers(line);
      for (final num in lineNumbers) {
        final denominations = ['1', '2', '5', '10', '20', '50', '100'];
        if (denominations.contains(num)) {
          candidates[num] = (candidates[num] ?? 0) + 4;
          print('   ✓ Número \$$num detectado en línea');
        }
      }
    }

    if (candidates.isEmpty) {
      return DenominationCandidate(
        denomination: 'Unknown',
        confidence: 0.0,
        method: 'lines',
        allCandidates: {},
      );
    }

    String best = candidates.keys.first;
    int bestScore = candidates[best]!;

    candidates.forEach((d, s) {
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    });

    return DenominationCandidate(
      denomination: best,
      confidence: (bestScore / 9).clamp(0.0, 1.0),
      method: 'lines',
      allCandidates: {for (final e in candidates.entries) e.key: (e.value / 9).clamp(0.0, 1.0)},
    );
  }

  DenominationDetectionResult _fuseAllResults({
    required DenominationCandidate fuzzyResult,
    required DenominationCandidate numericResult,
    required DenominationCandidate lineResult,
    required AuthenticityScore authenticity,
    required String currency,
  }) {
    const weights = {
      'fuzzy': 0.40,
      'numeric': 0.35,
      'lines': 0.25,
    };

    final all = <String, double>{};

    _addWeighted(all, fuzzyResult, weights['fuzzy']!);
    _addWeighted(all, numericResult, weights['numeric']!);
    _addWeighted(all, lineResult, weights['lines']!);

    if (all.isEmpty) {
      return DenominationDetectionResult(
        denomination: 'No detectada',
        confidence: 0.0,
        method: 'fusion',
        allCandidates: all,
        reasoning: 'No se detectó',
      );
    }

    print('\n   Scores finales:');
    String best = all.keys.first;
    double bestScore = all[best]!;

    all.forEach((d, s) {
      print('   \$$d: ${(s * 100).toStringAsFixed(1)}%');
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    });

    // Penalizar si es fotocopia
    if (authenticity.isLikelyPhotocopy) {
      bestScore *= 0.5;
      print('\n   ⚠️ FOTOCOPIA DETECTADA - Score reducido 50%');
    }

    bestScore = bestScore.clamp(0.0, 1.0);

    return DenominationDetectionResult(
      denomination: best,
      confidence: bestScore,
      method: 'fusion_v2',
      allCandidates: all,
      reasoning:
      '\$$best (${(bestScore * 100).toStringAsFixed(1)}%)\n${authenticity.indicators.join('\n')}',
    );
  }

  void _addWeighted(Map<String, double> acc, DenominationCandidate cand, double w) {
    cand.allCandidates.forEach((d, s) {
      acc[d] = (acc[d] ?? 0) + (s * w);
    });
  }

  Map<String, List<String>> _getUSDKeywords() {
    return {
      '1': [
        'ONE', 'DOLLAR', 'WASHINGTON', 'MOUNT', 'VERNON', 'SEAL',
        'GREAT', 'SINGLE', 'UNITED STATES', 'FEDERAL', 'RESERVE',
        'TREASURY', 'NOTE', 'LEGAL TENDER', 'IN GOD WE TRUST'
      ],
      '5': [
        'FIVE', 'LINCOLN', 'MEMORIAL', 'PRESIDENT', 'EMANCIPATION',
        'LOG CABIN', 'UNITED STATES', 'FEDERAL', 'RESERVE', 'TREASURY',
        'NOTE', 'LEGAL TENDER', 'IN GOD WE TRUST', 'PENNY'
      ],
      '10': [
        'TEN', 'HAMILTON', 'TREASURY', 'SECRETARY', 'ALEXANDER',
        'BUILDING', 'FINANCE', 'FEDERAL', 'RESERVE', 'UNITED STATES',
        'NOTE', 'LEGAL TENDER', 'IN GOD WE TRUST', 'GOVERNMENT'
      ],
      '20': [
        'TWENTY', 'JACKSON', 'WHITE', 'HOUSE', 'DEMOCRAT', 'ANDREW',
        'REMOVE', 'NATIVE AMERICAN', 'FEDERAL', 'RESERVE', 'TREASURY',
        'NOTE', 'LEGAL TENDER', 'IN GOD WE TRUST', 'UNITED STATES'
      ],
      '50': [
        'FIFTY', 'GRANT', 'CAPITOL', 'BUILDING', 'ULYSSES', 'CIVIL WAR',
        'GENERAL', 'FEDERAL', 'RESERVE', 'TREASURY', 'NOTE',
        'LEGAL TENDER', 'IN GOD WE TRUST', 'UNITED STATES'
      ],
      '100': [
        'HUNDRED', 'FRANKLIN', 'INDEPENDENCE', 'HALL', 'PHILADELPHIA',
        'BENJAMIN', 'SCIENTIST', 'INVENTOR', 'FEDERAL', 'RESERVE',
        'TREASURY', 'NOTE', 'LEGAL TENDER', 'IN GOD WE TRUST',
        'UNITED STATES', 'LIBERTY'
      ],
    };
  }

  Map<String, List<String>> _getEcuadorKeywords() {
    return {
      '1': ['UN', 'DÓLAR', 'ECUADOR'],
      '5': ['CINCO', 'DÓLAR'],
      '10': ['DIEZ', 'DÓLAR'],
      '20': ['VEINTE', 'DÓLAR'],
      '50': ['CINCUENTA', 'DÓLAR'],
      '100': ['CIEN', 'DÓLAR'],
    };
  }

  void dispose() {
    if (_isInitialized) {
      _textRecognizer.close();
      _isInitialized = false;
    }
  }
}

class DenominationCandidate {
  final String denomination;
  final double confidence;
  final String method;
  final Map<String, double> allCandidates;

  DenominationCandidate({
    required this.denomination,
    required this.confidence,
    required this.method,
    required this.allCandidates,
  });
}

class DenominationDetectionResult {
  final String denomination;
  final double confidence;
  final String method;
  final Map<String, double> allCandidates;
  final String reasoning;

  DenominationDetectionResult({
    required this.denomination,
    required this.confidence,
    required this.method,
    required this.allCandidates,
    required this.reasoning,
  });
}

class DenominationProfile {
  final String denomination;
  final String currency;
  final List<int> dominantColor;
  final List<String> keywords;
  final List<String> portraitNames;

  DenominationProfile({
    required this.denomination,
    required this.currency,
    required this.dominantColor,
    required this.keywords,
    required this.portraitNames,
  });
}