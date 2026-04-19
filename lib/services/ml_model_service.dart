import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Resultado completo del análisis de billete
class BillDetectionResult {
  final bool isBill;
  final bool isAuthentic;
  final String confidence;
  final String denomination;
  final String currency;          // 'USD' | 'ECU' | 'UNKNOWN'
  final String details;
  final List<String> detectedKeywords;

  BillDetectionResult({
    required this.isBill,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
    required this.currency,
    required this.details,
    this.detectedKeywords = const [],
  });
}

/// Histograma de color: 16 bins por canal R, G, B = 48 valores normalizados
typedef ColorHistogram = List<double>;

/// Servicio de detección: OCR (denominación) + histograma vs dataset (autenticidad)
class MLModelService {
  static final MLModelService _instance = MLModelService._internal();
  late TextRecognizer _textRecognizer;
  bool _isInitialized = false;

  // Cache de histogramas de referencia por denominación
  final Map<String, List<ColorHistogram>> _referenceHistograms = {};
  bool _datasetLoaded = false;

  factory MLModelService() => _instance;
  MLModelService._internal();

  // ── Carpetas del dataset por denominación ────────────────────────────────
  static const Map<String, String> _datasetPaths = {
    '1':   'assets/datasets/billetes/USA currency/1 Dollar',
    '2':   'assets/datasets/billetes/USA currency/2 Doolar',
    '5':   'assets/datasets/billetes/USA currency/5 Dollar',
    '10':  'assets/datasets/billetes/USA currency/10 Dollar',
    '50':  'assets/datasets/billetes/USA currency/50 Dollar',
    '100': 'assets/datasets/billetes/USA currency/100 Dollar',
  };

  // Cuántas imágenes de referencia cargar por denominación
  static const int _samplesPerDenomination = 20;

  // ── Palabras clave USD ───────────────────────────────────────────────────
  static const Map<String, List<String>> _usdKeywords = {
    '1':   ['ONE DOLLAR', 'ONE', 'WASHINGTON', 'IN GOD WE TRUST', 'THE UNITED STATES OF AMERICA'],
    '2':   ['TWO DOLLARS', 'TWO', 'JEFFERSON', 'THE UNITED STATES OF AMERICA'],
    '5':   ['FIVE DOLLARS', 'FIVE', 'LINCOLN', 'THE UNITED STATES OF AMERICA'],
    '10':  ['TEN DOLLARS', 'TEN', 'HAMILTON', 'THE UNITED STATES OF AMERICA'],
    '20':  ['TWENTY DOLLARS', 'TWENTY', 'JACKSON', 'THE UNITED STATES OF AMERICA'],
    '50':  ['FIFTY DOLLARS', 'FIFTY', 'GRANT', 'THE UNITED STATES OF AMERICA'],
    '100': ['ONE HUNDRED', 'HUNDRED DOLLARS', 'FRANKLIN', '100', 'THE UNITED STATES OF AMERICA'],
  };

  // ── Palabras clave Ecuador ───────────────────────────────────────────────
  static const Map<String, List<String>> _ecuadorKeywords = {
    '1':   ['UN DÓLAR', 'UN DOLLAR', 'BANCO CENTRAL DEL ECUADOR', 'REPÚBLICA DEL ECUADOR'],
    '5':   ['CINCO DÓLARES', 'CINCO DOLARES', 'BANCO CENTRAL DEL ECUADOR'],
    '10':  ['DIEZ DÓLARES', 'DIEZ DOLARES', 'BANCO CENTRAL DEL ECUADOR'],
    '20':  ['VEINTE DÓLARES', 'VEINTE DOLARES', 'BANCO CENTRAL DEL ECUADOR'],
    '50':  ['CINCUENTA DÓLARES', 'CINCUENTA DOLARES', 'BANCO CENTRAL DEL ECUADOR'],
    '100': ['CIEN DÓLARES', 'CIEN DOLARES', 'BANCO CENTRAL DEL ECUADOR'],
    '5000':  ['CINCO MIL SUCRES', 'BANCO CENTRAL DEL ECUADOR'],
    '10000': ['DIEZ MIL SUCRES', 'BANCO CENTRAL DEL ECUADOR'],
    '50000': ['CINCUENTA MIL SUCRES', 'BANCO CENTRAL DEL ECUADOR'],
  };

  // ── Indicadores genéricos de billete ────────────────────────────────────
  static const List<String> _genericBillKeywords = [
    'FEDERAL RESERVE', 'LEGAL TENDER', 'THIS NOTE IS LEGAL',
    'THE UNITED STATES', 'SECRETARY OF THE TREASURY', 'TREASURER',
    'WASHINGTON DC', 'BANCO CENTRAL', 'REPÚBLICA DEL ECUADOR',
    'ECUADOR', 'DOLLARS', 'DÓLARES', 'DOLARES', 'SERIES', 'NOTE',
  ];

  // ════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return;
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _isInitialized = true;
    print('✅ ML Kit OCR inicializado');

    // Cargar histogramas del dataset en background
    _loadDatasetHistograms();
  }

  Future<void> _loadDatasetHistograms() async {
    if (_datasetLoaded) return;
    print('📂 Cargando histogramas del dataset...');

    int totalLoaded = 0;

    for (final entry in _datasetPaths.entries) {
      final denom   = entry.key;
      final dirPath = entry.value;
      _referenceHistograms[denom] = [];

      try {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        final allAssets = _parseAssetManifest(manifestContent);

        final denomAssets = allAssets
            .where((a) => a.startsWith(dirPath) && _isImageFile(a))
            .toList();

        denomAssets.shuffle(Random(42));
        final sample = denomAssets.take(_samplesPerDenomination).toList();

        for (final assetPath in sample) {
          try {
            final bytes   = await rootBundle.load(assetPath);
            final imgData = img.decodeImage(bytes.buffer.asUint8List());
            if (imgData == null) continue;

            final histogram = _computeHistogram(imgData);
            _referenceHistograms[denom]!.add(histogram);
            totalLoaded++;
          } catch (_) {}
        }

        print('  ✅ \$$denom: ${_referenceHistograms[denom]!.length} referencias');
      } catch (e) {
        print('  ⚠️ Error cargando \$$denom: $e');
      }
    }

    _datasetLoaded = true;
    print('📊 Dataset listo: $totalLoaded histogramas cargados');
  }

  List<String> _parseAssetManifest(String manifestJson) {
    try {
      final Map<String, dynamic> decoded =
      json.decode(manifestJson) as Map<String, dynamic>;
      return decoded.keys.toList();
    } catch (e) {
      print('⚠️ Error parseando AssetManifest: $e');
      return [];
    }
  }

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
        lower.endsWith('.png') || lower.endsWith('.webp');
  }

  // ════════════════════════════════════════════════════════════════════════
  // DETECCIÓN PRINCIPAL
  // ════════════════════════════════════════════════════════════════════════

  Future<BillDetectionResult> detectBill(String imagePath) async {
    try {
      await initialize();

      // 1 ── OCR
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _textRecognizer.processImage(inputImage);
      final fullText   = recognized.text.toUpperCase().trim();

      print('📝 Texto OCR:\n$fullText');

      if (fullText.isEmpty) return _noTextResult();

      final List<String> foundKeywords = [];
      final usdMatch     = _matchCurrency(fullText, _usdKeywords, foundKeywords);
      final ecuMatch     = _matchCurrency(fullText, _ecuadorKeywords, foundKeywords);
      final genericScore = _scoreGenericKeywords(fullText, foundKeywords);

      // 2 ── Denominación y moneda
      if (usdMatch != null &&
          (ecuMatch == null || usdMatch['score']! >= ecuMatch['score']!)) {

        final denomKey  = usdMatch['denomination'] as String;
        final ocrScore  = usdMatch['score'] as int;
        final authResult = await _verifyAuthenticity(
          imagePath: imagePath, ocrText: fullText, denomKey: denomKey,
        );
        final confidence = min(50 + ocrScore * 10 + authResult.datasetBonus, 98);

        return BillDetectionResult(
          isBill: true, isAuthentic: authResult.isAuthentic,
          confidence: '$confidence%', denomination: '\$$denomKey',
          currency: 'USD', details: authResult.details,
          detectedKeywords: foundKeywords,
        );

      } else if (ecuMatch != null) {
        final denom      = ecuMatch['denomination'] as String;
        final symbol     = _isHistoricalSucre(denom) ? 'S/.' : '\$';
        final authResult = await _verifyAuthenticity(
          imagePath: imagePath, ocrText: fullText, denomKey: denom,
        );
        final confidence = min(50 + (ecuMatch['score'] as int) * 10 + authResult.datasetBonus, 98);

        return BillDetectionResult(
          isBill: true, isAuthentic: authResult.isAuthentic,
          confidence: '$confidence%', denomination: '$symbol$denom',
          currency: 'ECU', details: authResult.details,
          detectedKeywords: foundKeywords,
        );

      } else if (genericScore > 0) {
        return BillDetectionResult(
          isBill: true,
          isAuthentic: _quickOCRAuthenticity(fullText, imagePath),
          confidence: '${min(50 + genericScore * 8, 72).toInt()}%',
          denomination: 'No identificada',
          currency: _guessCurrencyByColor(imagePath),
          details: 'Billete detectado pero denominación no legible. '
              'Intenta con mejor iluminación.',
          detectedKeywords: foundKeywords,
        );
      } else {
        return _notABillResult();
      }
    } catch (e) {
      print('❌ Error: $e');
      return BillDetectionResult(
        isBill: false, isAuthentic: false, confidence: '0%',
        denomination: 'Error', currency: 'UNKNOWN',
        details: 'Error al procesar la imagen: $e',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VERIFICACIÓN DE AUTENTICIDAD: OCR + DATASET
  // ════════════════════════════════════════════════════════════════════════

  Future<_AuthResult> _verifyAuthenticity({
    required String imagePath,
    required String ocrText,
    required String denomKey,
  }) async {
    final ocrScore   = _scoreOCRAuthenticity(ocrText, imagePath);
    int datasetBonus = 0;
    String datasetDetail = '';

    // ── Comparación con histogramas del dataset ──────────────────────────
    final refs = _referenceHistograms[denomKey];

    if (refs != null && refs.isNotEmpty) {
      final capturedImage = img.decodeImage(File(imagePath).readAsBytesSync());

      if (capturedImage != null) {
        final capturedHist = _computeHistogram(capturedImage);

        double maxSimilarity = 0.0;
        for (final refHist in refs) {
          final sim = _histogramSimilarity(capturedHist, refHist);
          if (sim > maxSimilarity) maxSimilarity = sim;
        }

        final simPct = (maxSimilarity * 100).toStringAsFixed(1);
        print('📊 Similitud dataset \$$denomKey: $simPct%');

        if (maxSimilarity >= 0.80) {
          datasetBonus  = 8;
          datasetDetail = 'Alta similitud con billetes auténticos del dataset ($simPct%).';
        } else if (maxSimilarity >= 0.65) {
          datasetBonus  = 5;
          datasetDetail = 'Similitud moderada con el dataset ($simPct%).';
        } else if (maxSimilarity >= 0.50) {
          datasetBonus  = 2;
          datasetDetail = 'Similitud baja con el dataset ($simPct%). Verifica manualmente.';
        } else {
          datasetBonus  = 0;
          datasetDetail = 'Poca similitud con billetes de referencia ($simPct%). Podría ser falso.';
        }
      }
    } else {
      datasetDetail = 'Dataset no disponible para esta denominación.';
    }

    final totalScore  = ocrScore + datasetBonus;
    final isAuthentic = totalScore >= 7;

    print('🔒 OCR: $ocrScore | Dataset: $datasetBonus | Total: $totalScore');

    return _AuthResult(
      isAuthentic:  isAuthentic,
      datasetBonus: datasetBonus,
      details: isAuthentic
          ? '✅ Billete auténtico. $datasetDetail'
          : '⚠️ Billete sospechoso. $datasetDetail',
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // HISTOGRAMA DE COLOR
  // ════════════════════════════════════════════════════════════════════════

  /// Histograma normalizado de 48 bins (16 bins × 3 canales RGB).
  /// La imagen se escala a 64×64 para uniformidad y velocidad.
  ColorHistogram _computeHistogram(img.Image image) {
    const bins  = 16;
    const size  = 64;
    final resized = img.copyResize(image, width: size, height: size);

    final rBins = List<double>.filled(bins, 0);
    final gBins = List<double>.filled(bins, 0);
    final bBins = List<double>.filled(bins, 0);
    const totalPixels = size * size;

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final px = resized.getPixel(x, y);
        rBins[(px.r.toInt() * bins ~/ 256)]++;
        gBins[(px.g.toInt() * bins ~/ 256)]++;
        bBins[(px.b.toInt() * bins ~/ 256)]++;
      }
    }

    final histogram = <double>[];
    for (int i = 0; i < bins; i++) histogram.add(rBins[i] / totalPixels);
    for (int i = 0; i < bins; i++) histogram.add(gBins[i] / totalPixels);
    for (int i = 0; i < bins; i++) histogram.add(bBins[i] / totalPixels);
    return histogram;
  }

  /// Similitud por intersección de histogramas → 0.0 a 1.0
  double _histogramSimilarity(ColorHistogram h1, ColorHistogram h2) {
    if (h1.length != h2.length) return 0.0;
    double intersection = 0.0, sumH1 = 0.0;
    for (int i = 0; i < h1.length; i++) {
      intersection += min(h1[i], h2[i]);
      sumH1 += h1[i];
    }
    return sumH1 > 0 ? intersection / sumH1 : 0.0;
  }

  // ════════════════════════════════════════════════════════════════════════
  // AUTENTICIDAD POR OCR
  // ════════════════════════════════════════════════════════════════════════

  int _scoreOCRAuthenticity(String ocrText, String imagePath) {
    int score = 0;

    final serialRegex = RegExp(r'[A-Z]{1,2}\d{6,9}[A-Z]?');
    if (serialRegex.hasMatch(ocrText)) score += 3;

    final charCount = ocrText.replaceAll(RegExp(r'\s'), '').length;
    if (charCount > 40)      score += 3;
    else if (charCount > 20) score += 1;

    const securityWords = [
      'LEGAL TENDER', 'THIS NOTE IS LEGAL', 'IN GOD WE TRUST',
      'FEDERAL RESERVE', 'SECRETARY', 'TREASURER',
      'BANCO CENTRAL', 'REPÚBLICA',
    ];
    for (final w in securityWords) {
      if (ocrText.contains(w)) score += 2;
    }

    final file = File(imagePath);
    if (file.existsSync()) {
      final kb = file.lengthSync() / 1024;
      if (kb > 200)     score += 2;
      else if (kb > 80) score += 1;
    }

    return score;
  }

  bool _quickOCRAuthenticity(String ocrText, String imagePath) =>
      _scoreOCRAuthenticity(ocrText, imagePath) >= 5;

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════

  Map<String, dynamic>? _matchCurrency(
      String text,
      Map<String, List<String>> keywordsMap,
      List<String> foundKeywords,
      ) {
    String? bestDenom; int bestScore = 0;
    for (final entry in keywordsMap.entries) {
      int score = 0;
      for (final kw in entry.value) {
        if (text.contains(kw)) {
          score++;
          if (!foundKeywords.contains(kw)) foundKeywords.add(kw);
        }
      }
      if (score > bestScore) { bestScore = score; bestDenom = entry.key; }
    }
    if (bestScore == 0 || bestDenom == null) return null;
    return {'denomination': bestDenom, 'score': bestScore};
  }

  int _scoreGenericKeywords(String text, List<String> foundKeywords) {
    int score = 0;
    for (final kw in _genericBillKeywords) {
      if (text.contains(kw)) {
        score++;
        if (!foundKeywords.contains(kw)) foundKeywords.add(kw);
      }
    }
    return score;
  }

  String _guessCurrencyByColor(String imagePath) {
    try {
      final image = img.decodeImage(File(imagePath).readAsBytesSync());
      if (image == null) return 'UNKNOWN';
      final cx = image.width ~/ 2, cy = image.height ~/ 2;
      int tR = 0, tG = 0, tB = 0, n = 0;
      for (int dy = -30; dy <= 30; dy += 5) {
        for (int dx = -30; dx <= 30; dx += 5) {
          final px = image.getPixel(cx + dx, cy + dy);
          tR += px.r.toInt(); tG += px.g.toInt(); tB += px.b.toInt(); n++;
        }
      }
      if (n == 0) return 'UNKNOWN';
      final aR = tR ~/ n, aG = tG ~/ n;
      if (aG > aR + 15) return 'USD';
      if (aR >= aG - 10) return 'ECU';
      return 'UNKNOWN';
    } catch (_) { return 'UNKNOWN'; }
  }

  BillDetectionResult _noTextResult() => BillDetectionResult(
    isBill: false, isAuthentic: false, confidence: '0%',
    denomination: 'No detectada', currency: 'UNKNOWN',
    details: 'No se pudo leer texto. Asegúrate de que el billete esté '
        'bien iluminado, plano y completamente visible.',
  );

  BillDetectionResult _notABillResult() => BillDetectionResult(
    isBill: false, isAuthentic: false, confidence: '0%',
    denomination: 'No es un billete', currency: 'UNKNOWN',
    details: 'La imagen no parece ser un billete. Enfoca directamente sobre él.',
  );

  bool _isHistoricalSucre(String denom) =>
      ['5000', '10000', '50000'].contains(denom);

  void dispose() {
    if (_isInitialized) {
      _textRecognizer.close();
      _isInitialized = false;
    }
  }
}

/// Resultado interno de autenticidad
class _AuthResult {
  final bool   isAuthentic;
  final int    datasetBonus;
  final String details;
  const _AuthResult({
    required this.isAuthentic,
    required this.datasetBonus,
    required this.details,
  });
}