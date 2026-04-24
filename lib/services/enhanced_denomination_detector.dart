import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';
import 'fuzzy_matcher_service.dart';
import 'authenticity_detector_v2.dart';
import 'bill_number_extractor.dart';

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
    print('✅ Denominación detector V3 inicializado');
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
      print('🔍 DETECCIÓN V3.0 - PRIORIDAD EN NÚMEROS');
      print('🔍 ═══════════════════════════════════════════════════\n');

      // CAPA 1: OCR
      print('📝 CAPA 1: OCR...');
      final ocrResults = await _performOCR(imagePath);

      // 🆕 CAPA 2: NÚMEROS - MÁXIMA PRIORIDAD
      print('\n🔢 CAPA 2: EXTRACCIÓN DE NÚMEROS (PRIORIDAD 1)...');
      final numericResult = await _extractNumbersAdvanced(imagePath, ocrResults['text'] as String);

      // CAPA 3: Análisis por línea
      print('\n📋 CAPA 3: Análisis por línea...');
      final lineResult = _analyzeByLines(ocrResults['text'] as String, currency);

      // CAPA 4: Fuzzy Matching
      print('\n🔎 CAPA 4: Fuzzy Matching...');
      final fuzzyResult = _analyzeFuzzyKeywords(ocrResults['text'] as String, currency);

      // CAPA 5: Detección de fotocopia
      print('\n📸 CAPA 5: Detección de fotocopia...');
      final authenticityScore = await AuthenticityDetectorV2.detectPhotocopy(image);

      // FUSIÓN CON NÚMEROS COMO PRIORIDAD
      print('\n🧠 CAPA 6: Fusionando (números prioritarios)...');
      final finalResult = _fuseAllResultsNumbersPriority(
        numericResult: numericResult,
        lineResult: lineResult,
        fuzzyResult: fuzzyResult,
        authenticity: authenticityScore,
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

  /// 🆕 EXTRACCIÓN AVANZADA DE NÚMEROS - CON MÁXIMA PRIORIDAD
  Future<DenominationCandidate> _extractNumbersAdvanced(
      String imagePath,
      String text,
      ) async {
    print('   Analizando números de billete...');

    final candidates = <String, int>{};
    final denominationCounts = <String, List<Map<String, dynamic>>>{};

    // Inicializar conteo para cada denominación
    for (final denom in ['1', '2', '5', '10', '20', '50', '100']) {
      denominationCounts[denom] = [];
    }

    // ESTRATEGIA 1: Búsqueda de números grandes (esquinas)
    print('   📐 Estrategia 1: Números en esquinas...');
    final cornerNumbers = await _extractCornerNumbersAdvanced(imagePath);
    for (final num in cornerNumbers) {
      final cleanNum = num.replaceAll(RegExp(r'[^\d]'), '').trim();
      if (cleanNum.isNotEmpty && cleanNum.length <= 3) {
        print('      ✓ Esquina encontró: $cleanNum');
        if (['1', '2', '5', '10', '20', '50', '100'].contains(cleanNum)) {
          candidates[cleanNum] = (candidates[cleanNum] ?? 0) + 50;
          denominationCounts[cleanNum]!.add({
            'value': cleanNum,
            'location': 'corner',
            'confidence': 0.95
          });
        }
      }
    }

    // ESTRATEGIA 2: Búsqueda de números en patrones WORD
    print('   🔤 Estrategia 2: Palabras numéricas...');
    final wordNumbers = {
      'ONE': '1',
      'TWO': '2',
      'FIVE': '5',
      'TEN': '10',
      'TWENTY': '20',
      'FIFTY': '50',
      'HUNDRED': '100',
    };

    for (final entry in wordNumbers.entries) {
      if (text.contains(entry.key)) {
        print('      ✓ Palabra numérica encontrada: ${entry.key}');
        candidates[entry.value] = (candidates[entry.value] ?? 0) + 40;
        denominationCounts[entry.value]!.add({
          'value': entry.value,
          'location': 'text_word',
          'confidence': 0.85
        });
      }
    }

    // ESTRATEGIA 3: Búsqueda REGEX de números puros
    print('   🔢 Estrategia 3: Números puros (regex)...');
    final patterns = [
      (RegExp(r'\b100\b'), '100', 45),
      (RegExp(r'\b50\b'), '50', 45),
      (RegExp(r'\b20\b'), '20', 45),
      (RegExp(r'\b10\b'), '10', 45),
      (RegExp(r'\b5\b'), '5', 40),
      (RegExp(r'\b2\b'), '2', 40),
      (RegExp(r'\b1\b'), '1', 35),
    ];

    for (final (pattern, denom, score) in patterns) {
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        final count = matches.length;
        print('      ✓ $denom encontrado $count veces');
        candidates[denom] = (candidates[denom] ?? 0) + (score * min(count, 5));
        denominationCounts[denom]!.add({
          'value': denom,
          'location': 'text_number',
          'confidence': 0.80,
          'count': count
        });
      }
    }

    // ESTRATEGIA 4: Búsqueda de números fragmentados
    print('   🔍 Estrategia 4: Números fragmentados...');
    final fragmentPatterns = [
      (RegExp(r'(?:^|\D)100(?:\D|$)'), '100', 35),
      (RegExp(r'(?:^|\D)50(?:\D|$)'), '50', 35),
      (RegExp(r'(?:^|\D)20(?:\D|$)'), '20', 35),
      (RegExp(r'(?:^|\D)10(?:\D|$)'), '10', 35),
    ];

    for (final (pattern, denom, score) in fragmentPatterns) {
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        final count = matches.length;
        print('      ✓ Fragmento $denom encontrado $count veces');
        candidates[denom] = (candidates[denom] ?? 0) + (score * min(count, 3));
      }
    }

    // RESULTADO FINAL
    if (candidates.isEmpty) {
      print('   ✗ No números detectados');
      return DenominationCandidate(
        denomination: 'Unknown',
        confidence: 0.0,
        method: 'numeric_advanced',
        allCandidates: {},
      );
    }

    String bestDenom = candidates.keys.first;
    int bestScore = candidates[bestDenom]!;

    candidates.forEach((d, s) {
      print('   📊 \$$d: score = $s');
      if (s > bestScore) {
        bestScore = s;
        bestDenom = d;
      }
    });

    final confidence = min((bestScore / 500).toDouble(), 1.0);

    print('   🎯 MEJOR NÚMERO: \$$bestDenom (score: $bestScore, confianza: ${(confidence * 100).toStringAsFixed(1)}%)');

    return DenominationCandidate(
      denomination: bestDenom,
      confidence: confidence,
      method: 'numeric_advanced',
      allCandidates: {
        for (final e in candidates.entries)
          e.key: min((e.value / 500).toDouble(), 1.0)
      },
    );
  }

  /// 🆕 Extrae números de esquinas con mejor procesamiento
  Future<List<String>> _extractCornerNumbersAdvanced(String imagePath) async {
    final cornerNumbers = <String>[];

    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      var image = img.decodeImage(imageBytes);

      if (image == null) return cornerNumbers;

      final corners = [
        _CornerRegion(0, 0, 'top-left'),
        _CornerRegion(image.width - 200, 0, 'top-right'),
        _CornerRegion(0, image.height - 200, 'bottom-left'),
        _CornerRegion(image.width - 200, image.height - 200, 'bottom-right'),
      ];

      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      for (final corner in corners) {
        try {
          final x = max(0, corner.x);
          final y = max(0, corner.y);
          final w = min(200, image.width - x);
          final h = min(200, image.height - y);

          var cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);

          // Mejorar para números grandes
          cropped = _enhanceForLargeNumbers(cropped);

          // Guardar temporalmente
          final tempFile = File(
            '${Directory.systemTemp.path}/corner_adv_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await tempFile.writeAsBytes(img.encodeJpg(cropped, quality: 95));

          final inputImage = InputImage.fromFilePath(tempFile.path);
          final recognized = await textRecognizer.processImage(inputImage);
          final text = recognized.text.trim();

          if (text.isNotEmpty) {
            print('      📍 ${corner.name}: "$text"');
            cornerNumbers.add(text);
          }

          await tempFile.delete();
        } catch (e) {
          // Silenciar
        }
      }

      textRecognizer.close();
    } catch (e) {
      print('   ⚠️ Error en esquinas: $e');
    }

    return cornerNumbers;
  }

  /// Mejorar imagen para números grandes
  static img.Image _enhanceForLargeNumbers(img.Image image) {
    // Aumentar contraste significativamente para números
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: image.numChannels,
    );

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        final gray = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b).toInt();

        // Threshold adaptativo para números
        final enhanced = gray > 120 ? 255 : 0;

        result.setPixelRgba(x, y, enhanced, enhanced, enhanced, px.a.toInt());
      }
    }

    return result;
  }

  DenominationCandidate _analyzeByLines(String text, String currency) {
    final lines = FuzzyMatcherService.extractLines(text);
    final candidates = <String, int>{};

    print('   Analizando ${lines.length} líneas...');

    for (final line in lines) {
      // Buscar números directamente en líneas
      final lineNumbers = FuzzyMatcherService.extractNumbers(line);
      for (final num in lineNumbers) {
        if (num == '100') {
          candidates['100'] = (candidates['100'] ?? 0) + 30;
          print('   ✓ \$100: número encontrado en línea');
        } else if (num == '50') {
          candidates['50'] = (candidates['50'] ?? 0) + 30;
          print('   ✓ \$50: número encontrado en línea');
        } else if (num == '20') {
          candidates['20'] = (candidates['20'] ?? 0) + 30;
          print('   ✓ \$20: número encontrado en línea');
        } else if (num == '10') {
          candidates['10'] = (candidates['10'] ?? 0) + 30;
          print('   ✓ \$10: número encontrado en línea');
        } else if (num == '5') {
          candidates['5'] = (candidates['5'] ?? 0) + 25;
          print('   ✓ \$5: número encontrado en línea');
        }
      }

      // Palabras de denominación
      if (line.contains('JACKSON') || line.contains('ACKSON') ||
          line.contains('TWENTY')) {
        candidates['20'] = (candidates['20'] ?? 0) + 15;
      }
      if (line.contains('HAMILTON') || line.contains('AMILTON') ||
          line.contains('TEN')) {
        candidates['10'] = (candidates['10'] ?? 0) + 15;
      }
      if (line.contains('LINCOLN') || line.contains('INCOLN') ||
          line.contains('FIVE')) {
        candidates['5'] = (candidates['5'] ?? 0) + 15;
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
      confidence: min((bestScore / 60).toDouble(), 1.0),
      method: 'lines',
      allCandidates: {
        for (final e in candidates.entries)
          e.key: min((e.value / 60).toDouble(), 1.0)
      },
    );
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
        if (FuzzyMatcherService.fuzzyContains(text, keyword, threshold: 0.70)) {
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

  /// 🆕 FUSIÓN CON NÚMEROS COMO PRIORIDAD ABSOLUTA
  DenominationDetectionResult _fuseAllResultsNumbersPriority({
    required DenominationCandidate numericResult,
    required DenominationCandidate lineResult,
    required DenominationCandidate fuzzyResult,
    required AuthenticityScore authenticity,
    required String currency,
  }) {
    // 🆕 PESOS CON MÁXIMA PRIORIDAD A NÚMEROS
    const weights = {
      'numeric_advanced': 0.70,  // ⭐⭐⭐ MÁXIMA PRIORIDAD
      'lines': 0.20,
      'fuzzy': 0.10,
    };

    final all = <String, double>{};

    _addWeighted(all, numericResult, weights['numeric_advanced']!);
    _addWeighted(all, lineResult, weights['lines']!);
    _addWeighted(all, fuzzyResult, weights['fuzzy']!);

    if (all.isEmpty) {
      return DenominationDetectionResult(
        denomination: 'No detectada',
        confidence: 0.0,
        method: 'fusion_numbers_priority',
        allCandidates: all,
        reasoning: 'No se detectó',
      );
    }

    print('\n   SCORES FINALES (números prioritarios):');
    String best = all.keys.first;
    double bestScore = all[best]!;

    all.forEach((d, s) {
      print('   \$$d: ${(s * 100).toStringAsFixed(1)}%');
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    });

    // Penalizar si fotocopia
    if (authenticity.isLikelyPhotocopy) {
      final negativeFlagsCount = authenticity.indicators
          .where((ind) => ind.startsWith('⚠️'))
          .length;

      if (negativeFlagsCount >= 3) {
        bestScore *= 0.5;
        print('\n   ⚠️ Múltiples indicadores de fotocopia (-50%)');
      } else if (negativeFlagsCount >= 2) {
        bestScore *= 0.8;
        print('\n   ⚠️ Algunos indicadores sospechosos (-20%)');
      }
    }

    bestScore = bestScore.clamp(0.0, 1.0);

    return DenominationDetectionResult(
      denomination: best,
      confidence: bestScore,
      method: 'fusion_numbers_priority',
      allCandidates: all,
      reasoning:
      '🔢 NÚMEROS PRIORITARIOS\n\$$best (${(bestScore * 100).toStringAsFixed(1)}%)',
    );
  }

  void _addWeighted(Map<String, double> acc, DenominationCandidate cand,
      double w) {
    cand.allCandidates.forEach((d, s) {
      acc[d] = (acc[d] ?? 0) + (s * w);
    });
  }

  Map<String, List<String>> _getUSDKeywords() {
    return {
      '1': [
        'ONE',
        'DOLLAR',
        'WASHINGTON',
        'MOUNT',
        'VERNON',
        'SEAL',
        'SINGLE'
      ],
      '5': ['FIVE', 'LINCOLN', 'MEMORIAL', 'EMANCIPATION'],
      '10': ['TEN', 'HAMILTON', 'TREASURY', 'SECRETARY'],
      '20': ['TWENTY', 'JACKSON', 'WHITE', 'HOUSE'],
      '50': ['FIFTY', 'GRANT', 'CAPITOL'],
      '100': ['HUNDRED', 'FRANKLIN', 'INDEPENDENCE', 'HALL'],
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

class _CornerRegion {
  final int x;
  final int y;
  final String name;

  _CornerRegion(this.x, this.y, this.name);
}