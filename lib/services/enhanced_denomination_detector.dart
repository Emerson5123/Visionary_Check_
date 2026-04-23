import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';

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
    print('✅ Denominación detector inicializado');
  }

  Future<DenominationDetectionResult> detectDenomination(
      String imagePath,
      String currency,
      ) async {
    try {
      await initialize();

      final image = img.decodeImage(File(imagePath).readAsBytesSync());
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      print('\n🔍 ═══════════════════════════════════════════════════');
      print('🔍 INICIANDO DETECCIÓN DE DENOMINACIÓN (MEJORADO)');
      print('🔍 ═══════════════════════════════════════════════════\n');

      // CAPA 1: OCR
      print('📝 CAPA 1: Realizando OCR...');
      final ocrResults = await _performOCR(imagePath);
      print('   ✓ Texto detectado: ${ocrResults['text'].substring(0, min(100, (ocrResults['text'] as String).length))}...\n');

      // CAPA 2: Búsqueda FUZZY de números
      print('🔢 CAPA 2: Búsqueda FUZZY de números...');
      final numericResult = _analyzeFuzzyNumeric(ocrResults['text'] as String, currency);
      print('   Resultado: ${numericResult.denomination} (${(numericResult.confidence * 100).toStringAsFixed(0)}%)\n');

      // CAPA 3: Búsqueda FUZZY de palabras clave
      print('📚 CAPA 3: Búsqueda FUZZY de palabras clave...');
      final keywordResult = _analyzeFuzzyKeywords(ocrResults['text'] as String, currency);
      print('   Resultado: ${keywordResult.denomination} (${(keywordResult.confidence * 100).toStringAsFixed(0)}%)\n');

      // CAPA 4: Análisis de fragmentos clave
      print('🔍 CAPA 4: Análisis de fragmentos clave...');
      final fragmentResult = _analyzeKeyFragments(ocrResults['text'] as String, currency);
      print('   Resultado: ${fragmentResult.denomination} (${(fragmentResult.confidence * 100).toStringAsFixed(0)}%)\n');

      // CAPA 5: Análisis de color
      print('🎨 CAPA 5: Análisis de color...');
      final colorResult = _analyzeColorProfile(image, currency);
      print('   Resultado: ${colorResult.denomination} (${(colorResult.confidence * 100).toStringAsFixed(0)}%)\n');

      // FUSIÓN
      print('🧠 CAPA 6: Fusionando resultados...');
      final finalResult = _fuseResults(
        numericResult: numericResult,
        keywordResult: keywordResult,
        fragmentResult: fragmentResult,
        colorResult: colorResult,
        currency: currency,
      );

      print('═══════════════════════════════════════════════════');
      print('✅ RESULTADO FINAL: ${finalResult.denomination}');
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

  /// OCR
  Future<Map<String, dynamic>> _performOCR(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text.toUpperCase();

      return {
        'text': text,
        'confidence': _calculateOCRConfidence(recognized),
      };
    } catch (e) {
      print('   ⚠️ Error: $e');
      return {'text': '', 'confidence': 0.0};
    }
  }

  double _calculateOCRConfidence(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    int elementCount = 0;

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final conf = element.confidence ?? 0.0;
          totalConfidence += conf;
          elementCount++;
        }
      }
    }

    if (elementCount == 0) return 0.0;
    return (totalConfidence / elementCount).clamp(0.0, 1.0);
  }

  /// ═══════════════════════════════════════════════════════════════
  /// CAPA 2: BÚSQUEDA FUZZY DE NÚMEROS
  /// ═══════════════════════════════════════════════════════════════

  DenominationCandidate _analyzeFuzzyNumeric(
      String text,
      String currency,
      ) {
    final candidates = <String, int>{};

    // Patrones más flexibles
    final patterns = [
      (r'(?:^|\D)(1)(?:\D|$)', '1', 5),
      (r'(?:^|\D)(2)(?:\D|$)', '2', 5),
      (r'(?:^|\D)(5)(?:\D|$)', '5', 6),
      (r'(?:^|\D)(10)(?:\D|$)', '10', 7),
      (r'(?:^|\D)(20)(?:\D|$)', '20', 7),
      (r'(?:^|\D)(50)(?:\D|$)', '50', 7),
      (r'(?:^|\D)(100)(?:\D|$)', '100', 7),
    ];

    for (final (pattern, denom, score) in patterns) {
      final matches = RegExp(pattern).allMatches(text);
      if (matches.isNotEmpty) {
        final count = min(matches.length, 5);
        candidates[denom] = (candidates[denom] ?? 0) + (score * count);
        print('   ✓ Número "$denom" encontrado $count veces');
      }
    }

    if (candidates.isEmpty) {
      print('   ✗ No números detectados');
      return DenominationCandidate(
        denomination: 'Unknown',
        confidence: 0.0,
        method: 'numeric',
        allCandidates: {},
      );
    }

    String bestDenom = candidates.keys.first;
    int bestScore = candidates[bestDenom]!;

    candidates.forEach((d, s) {
      if (s > bestScore) {
        bestScore = s;
        bestDenom = d;
      }
    });

    final confidence = min((bestScore / 35).toDouble(), 1.0);
    return DenominationCandidate(
      denomination: bestDenom,
      confidence: confidence,
      method: 'numeric',
      allCandidates: {for (final e in candidates.entries) e.key: min((e.value / 35).toDouble(), 1.0)},
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// CAPA 3: BÚSQUEDA FUZZY DE PALABRAS CLAVE
  /// ═══════════════════════════════════════════════════════════════

  DenominationCandidate _analyzeFuzzyKeywords(String text, String currency) {
    final candidates = <String, int>{};

    final keywordMap = currency == 'USD'
        ? _getUSDKeywords()
        : _getEcuadorKeywords();

    print('   Buscando en ${keywordMap.length} denominaciones...');

    for (final entry in keywordMap.entries) {
      final denom = entry.key;
      final keywords = entry.value;

      int matchCount = 0;

      for (final keyword in keywords) {
        // Búsqueda FUZZY: substring de al menos 4 caracteres
        if (_fuzzyMatch(text, keyword)) {
          matchCount++;
        }
      }

      if (matchCount > 0) {
        candidates[denom] = matchCount;
        print('   ✓ \$$denom: $matchCount coincidencias');
      }
    }

    if (candidates.isEmpty) {
      print('   ✗ No palabras clave encontradas');
      return DenominationCandidate(
        denomination: 'Unknown',
        confidence: 0.0,
        method: 'keywords',
        allCandidates: {},
      );
    }

    String bestDenom = candidates.keys.first;
    int bestScore = candidates[bestDenom]!;

    candidates.forEach((d, s) {
      if (s > bestScore) {
        bestScore = s;
        bestDenom = d;
      }
    });

    final totalKeywords = keywordMap.values.first.length;
    final confidence = (bestScore / totalKeywords).clamp(0.0, 1.0);

    print('   ✓ Mejor: \$$bestDenom (${bestScore}/${totalKeywords})');

    return DenominationCandidate(
      denomination: bestDenom,
      confidence: confidence,
      method: 'keywords',
      allCandidates: {
        for (final e in candidates.entries) e.key: (e.value / totalKeywords).clamp(0.0, 1.0)
      },
    );
  }

  /// Fuzzy match: permite diferencias pequeñas
  bool _fuzzyMatch(String text, String keyword) {
    // Si el keyword es muy corto, búsqueda exacta
    if (keyword.length < 3) {
      return text.contains(keyword);
    }

    // Para keywords largos, buscar substring similar
    final keywordLower = keyword.toLowerCase();
    final textLower = text.toLowerCase();

    // Búsqueda directa
    if (textLower.contains(keywordLower)) {
      return true;
    }

    // Búsqueda por fragmentos (primeros 4+ caracteres)
    for (int i = 4; i <= keywordLower.length; i++) {
      final fragment = keywordLower.substring(0, i);
      if (textLower.contains(fragment)) {
        return true;
      }
    }

    return false;
  }

  /// ═══════════════════════════════════════════════════════════════
  /// CAPA 4: ANÁLISIS DE FRAGMENTOS CLAVE
  /// ═══════════════════════════════════════════════════════════════

  DenominationCandidate _analyzeKeyFragments(String text, String currency) {
    final candidates = <String, int>{};

    // Fragmentos muy específicos que aparecen en billetes
    final fragmentMap = {
      '1': ['WASHINGTON', 'MOUNT VERNON', 'ONE DOLL', 'SEAL'],
      '5': ['LINCOLN', 'MEMORIAL', 'FIVE'],
      '10': ['HAMILTON', 'TREASURY', 'TEN'],
      '20': ['JACKSON', 'WHITE HOUSE', 'TWENTY'],
      '50': ['GRANT', 'CAPITOL', 'FIFTY'],
      '100': ['FRANKLIN', 'INDEPENDENCE', 'HUNDRED'],
    };

    print('   Analizando fragmentos clave...');

    for (final entry in fragmentMap.entries) {
      final denom = entry.key;
      final fragments = entry.value;

      int matchCount = 0;

      for (final fragment in fragments) {
        if (text.contains(fragment)) {
          matchCount++;
          print('   ✓ \$$denom: encontrado "$fragment"');
        }
      }

      if (matchCount > 0) {
        candidates[denom] = matchCount * 3; // Mayor peso
      }
    }

    if (candidates.isEmpty) {
      print('   ✗ No fragmentos detectados');
      return DenominationCandidate(
        denomination: 'Unknown',
        confidence: 0.0,
        method: 'fragments',
        allCandidates: {},
      );
    }

    String bestDenom = candidates.keys.first;
    int bestScore = candidates[bestDenom]!;

    candidates.forEach((d, s) {
      if (s > bestScore) {
        bestScore = s;
        bestDenom = d;
      }
    });

    final confidence = min((bestScore / 12).toDouble(), 1.0);

    return DenominationCandidate(
      denomination: bestDenom,
      confidence: confidence,
      method: 'fragments',
      allCandidates: {for (final e in candidates.entries) e.key: min((e.value / 12).toDouble(), 1.0)},
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// CAPA 5: ANÁLISIS DE COLOR
  /// ═══════════════════════════════════════════════════════════════

  DenominationCandidate _analyzeColorProfile(img.Image image, String currency) {
    final dominantColor = _getDominantColor(image);
    final candidates = <String, double>{};

    print('   Color: RGB${dominantColor}');

    if (currency == 'USD') {
      final usdColors = {
        '1': (142, 110, 48),
        '5': (76, 149, 109),
        '10': (255, 165, 0),
        '20': (0, 102, 204),
        '50': (204, 0, 0),
        '100': (0, 51, 102),
      };

      for (final entry in usdColors.entries) {
        final distance = _colorDistance(dominantColor, entry.value);
        final similarity = 1.0 - min(distance / 500, 1.0);
        candidates[entry.key] = similarity;

        if (similarity > 0.4) {
          print('   ✓ \$${entry.key}: ${(similarity * 100).toStringAsFixed(0)}%');
        }
      }
    }

    if (candidates.isEmpty) {
      return DenominationCandidate(
        denomination: 'Unknown',
        confidence: 0.0,
        method: 'color',
        allCandidates: candidates,
      );
    }

    String bestDenom = candidates.keys.first;
    double bestScore = candidates[bestDenom]!;

    candidates.forEach((d, s) {
      if (s > bestScore) {
        bestScore = s;
        bestDenom = d;
      }
    });

    return DenominationCandidate(
      denomination: bestDenom,
      confidence: bestScore,
      method: 'color',
      allCandidates: candidates,
    );
  }

  (int, int, int) _getDominantColor(img.Image image) {
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final sampleSize = min(image.width, image.height) ~/ 4;

    int r = 0, g = 0, b = 0, count = 0;

    for (int y = centerY - sampleSize; y < centerY + sampleSize; y++) {
      for (int x = centerX - sampleSize; x < centerX + sampleSize; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final px = image.getPixel(x, y);
          r += px.r.toInt();
          g += px.g.toInt();
          b += px.b.toInt();
          count++;
        }
      }
    }

    if (count == 0) return (128, 128, 128);
    return (r ~/ count, g ~/ count, b ~/ count);
  }

  double _colorDistance((int, int, int) c1, (int, int, int) c2) {
    final dr = c1.$1 - c2.$1;
    final dg = c1.$2 - c2.$2;
    final db = c1.$3 - c2.$3;
    return sqrt((dr * dr + dg * dg + db * db).toDouble());
  }

  /// ═══════════════════════════════════════════════════════════════
  /// FUSIÓN FINAL
  /// ═══════════════════════════════════════════════════════════════

  DenominationDetectionResult _fuseResults({
    required DenominationCandidate numericResult,
    required DenominationCandidate keywordResult,
    required DenominationCandidate fragmentResult,
    required DenominationCandidate colorResult,
    required String currency,
  }) {
    // Pesos optimizados
    const weights = {
      'numeric': 0.25,
      'keywords': 0.25,
      'fragments': 0.35,  // Mayor peso
      'color': 0.15,
    };

    final allDenominations = <String, double>{};

    _addWeightedScores(allDenominations, numericResult, weights['numeric']!);
    _addWeightedScores(allDenominations, keywordResult, weights['keywords']!);
    _addWeightedScores(allDenominations, fragmentResult, weights['fragments']!);
    _addWeightedScores(allDenominations, colorResult, weights['color']!);

    if (allDenominations.isEmpty) {
      return DenominationDetectionResult(
        denomination: 'No detectada',
        confidence: 0.0,
        method: 'fusion',
        allCandidates: allDenominations,
        reasoning: 'No se pudo identificar',
      );
    }

    print('\n   Scores finales:');
    String bestDenom = allDenominations.keys.first;
    double bestScore = allDenominations[bestDenom]!;

    allDenominations.forEach((d, s) {
      print('   \$$d: ${(s * 100).toStringAsFixed(1)}%');
      if (s > bestScore) {
        bestScore = s;
        bestDenom = d;
      }
    });

    bestScore = bestScore.clamp(0.0, 1.0);

    return DenominationDetectionResult(
      denomination: bestDenom,
      confidence: bestScore,
      method: 'fusion',
      allCandidates: allDenominations,
      reasoning: '\$$bestDenom (${(bestScore * 100).toStringAsFixed(1)}%)',
    );
  }

  void _addWeightedScores(
      Map<String, double> accumulated,
      DenominationCandidate candidate,
      double weight,
      ) {
    candidate.allCandidates.forEach((denom, score) {
      accumulated[denom] = (accumulated[denom] ?? 0) + (score * weight);
    });
  }

  Map<String, List<String>> _getUSDKeywords() {
    return {
      '1': ['ONE', 'DOLLAR', 'WASHINGTON', 'MOUNT', 'VERNON', 'FEDERAL', 'RESERVE'],
      '5': ['FIVE', 'LINCOLN', 'MEMORIAL', 'FEDERAL', 'RESERVE'],
      '10': ['TEN', 'HAMILTON', 'TREASURY', 'FEDERAL', 'RESERVE'],
      '20': ['TWENTY', 'JACKSON', 'WHITE', 'HOUSE', 'FEDERAL', 'RESERVE'],
      '50': ['FIFTY', 'GRANT', 'CAPITOL', 'FEDERAL', 'RESERVE'],
      '100': ['HUNDRED', 'FRANKLIN', 'INDEPENDENCE', 'HALL', 'FEDERAL', 'RESERVE'],
    };
  }

  Map<String, List<String>> _getEcuadorKeywords() {
    return {
      '1': ['UN', 'DÓLAR', 'ECUADOR', 'BANCO', 'CENTRAL'],
      '5': ['CINCO', 'DÓLAR', 'ECUADOR', 'BANCO'],
      '10': ['DIEZ', 'DÓLAR', 'ECUADOR', 'BANCO'],
      '20': ['VEINTE', 'DÓLAR', 'ECUADOR', 'BANCO'],
      '50': ['CINCUENTA', 'DÓLAR', 'ECUADOR', 'BANCO'],
      '100': ['CIEN', 'DÓLAR', 'ECUADOR', 'BANCO'],
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