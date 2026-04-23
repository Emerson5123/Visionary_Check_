import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ml_model_service.dart';
import 'enhanced_denomination_detector.dart';

class BillAnalysis {
  final bool hasBilletFeatures;
  final bool isAuthentic;
  final double confidence;
  final String denomination;
  final String currency;
  final String details;
  final List<String> detectedKeywords;
  final List<String> detectedFeatures;
  final List<String> suspiciousIndicators;

  BillAnalysis({
    required this.hasBilletFeatures,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
    required this.currency,
    required this.details,
    this.detectedKeywords = const [],
    this.detectedFeatures = const [],
    this.suspiciousIndicators = const [],
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
  late EnhancedDenominationDetector _denomDetector;
  late TextRecognizer _textRecognizer;
  bool _authInitialized = false;

  factory BillDetectionService() => _instance;

  BillDetectionService._internal() {
    _mlService = MLModelService();
    _mlService.initialize();
    _denomDetector = EnhancedDenominationDetector();
  }

  /// Analiza un billete usando OCR + autenticación mejorada
  Future<BillAnalysis> analyzeBill(String imagePath) async {
    try {
      print('🔍 ════════════════════════════════════════════════');
      print('🔍 INICIANDO ANÁLISIS DE BILLETE');
      print('🔍 Archivo: $imagePath');
      print('🔍 ════════════════════════════════════════════════\n');

      // 1. Verificar que archivo existe
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        throw Exception('Archivo no existe: $imagePath');
      }
      print('✅ Archivo encontrado\n');

      // 2. Decodificar imagen
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }
      print('✅ Imagen decodificada: ${image.width}x${image.height}\n');

      // 3. Detectar moneda por color
      final currency = _guessCurrencyByColor(image);
      print('💱 Moneda detectada: $currency\n');

      // 4. OCR DIRECTO (para debug)
      print('📝 ═══════════════════════════════════════════════');
      print('📝 INICIANDO OCR DIRECTO');
      print('📝 ═══════════════════════════════════════════════\n');

      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _getTextRecognizer().processImage(inputImage);
      final fullText = recognizedText.text.toUpperCase();

      print('📄 TEXTO OCR COMPLETO:');
      print('─────────────────────────────────────────────────');
      print(fullText.isNotEmpty ? fullText : '(vacío)');
      print('─────────────────────────────────────────────────\n');

      print('📊 ESTADÍSTICAS OCR:');
      print('   • Longitud: ${fullText.length} caracteres');
      print('   • Bloques detectados: ${recognizedText.blocks.length}');
      print('   • Confianza promedio: ${_calculateOCRConfidence(recognizedText)}');
      print('');

      // 5. Usar nuevo detector de denominación
      print('🔢 Detectando denominación...\n');
      final denomResult = await _denomDetector.detectDenomination(
        imagePath,
        currency,
      );

      print('\n✅ Denominación: ${denomResult.denomination}');
      print('   Confianza: ${(denomResult.confidence * 100).toStringAsFixed(1)}%\n');

      // 6. Análisis de autenticidad
      if (denomResult.confidence > 0.3) {
        print('🔐 Iniciando análisis de autenticidad...\n');

        final result = await _mlService.detectBill(imagePath);

        if (result.isBill) {
          final advancedAnalysis = await _performAdvancedAuthentication(
            imagePath: imagePath,
            basicResult: result,
            denomination: denomResult.denomination,
            currency: currency,
          );
          return advancedAnalysis;
        }

        return BillAnalysis(
          hasBilletFeatures: result.isBill,
          isAuthentic: result.isAuthentic,
          confidence: denomResult.confidence,
          denomination: denomResult.denomination,
          currency: currency,
          details: denomResult.reasoning,
          detectedKeywords: result.detectedKeywords,
        );
      }

      // Sin denominación
      return BillAnalysis(
        hasBilletFeatures: false,
        isAuthentic: false,
        confidence: 0.0,
        denomination: 'No detectada',
        currency: currency,
        details: 'No se pudo identificar la denominación del billete.\n\nAsegúrate de:\n✓ Tomar foto en luz natural\n✓ Billete completamente visible\n✓ Ángulo frontal\n✓ Foto clara y enfocada',
      );
    } catch (e) {
      print('❌ ERROR: $e\n');
      return BillAnalysis(
        hasBilletFeatures: false,
        isAuthentic: false,
        confidence: 0.0,
        denomination: 'Error',
        currency: 'UNKNOWN',
        details: 'Error: $e',
      );
    }
  }

  TextRecognizer _getTextRecognizer() {
    if (!_authInitialized) {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _authInitialized = true;
    }
    return _textRecognizer;
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

  /// Detecta moneda por color dominante
  String _guessCurrencyByColor(img.Image image) {
    try {
      final cx = image.width ~/ 2;
      final cy = image.height ~/ 2;
      int tR = 0, tG = 0, tB = 0, n = 0;

      // Muestrear centro de la imagen
      for (int dy = -30; dy <= 30; dy += 5) {
        for (int dx = -30; dx <= 30; dx += 5) {
          final x = cx + dx;
          final y = cy + dy;

          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final px = image.getPixel(x, y);
            tR += px.r.toInt();
            tG += px.g.toInt();
            tB += px.b.toInt();
            n++;
          }
        }
      }

      if (n == 0) return 'UNKNOWN';

      final aR = tR ~/ n;
      final aG = tG ~/ n;
      final aB = tB ~/ n;

      // USD = más verde
      // ECU = más rojo/naranja
      if (aG > aR + 15) {
        return 'USD';
      } else if (aR >= aG - 10) {
        return 'ECU';
      }

      return 'UNKNOWN';
    } catch (e) {
      print('⚠️ Error detectando color: $e');
      return 'USD'; // Default
    }
  }

  /// Análisis avanzado de autenticidad (5 detectores)
  Future<BillAnalysis> _performAdvancedAuthentication({
    required String imagePath,
    required dynamic basicResult,
    required String denomination,
    required String currency,
  }) async {
    try {
      final file = File(imagePath);
      final imageBytes = file.readAsBytesSync();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      final detectorScores = <String, double>{};
      final detectedFeatures = <String>[];
      final suspiciousIndicators = <String>[];

      print('🔍 Iniciando análisis avanzado con 5 detectores...');

      // DETECTOR 1: Características de Seguridad
      print('  Detector 1: Características de Seguridad...');
      final (sec, feat1, susp1) = await _detectSecurityFeatures(image, imagePath);
      detectorScores['security'] = sec;
      detectedFeatures.addAll(feat1);
      suspiciousIndicators.addAll(susp1);

      // DETECTOR 2: Análisis de Textura
      print('  Detector 2: Análisis de Textura...');
      final (tex, feat2, susp2) = _analyzeTexturePatterns(image);
      detectorScores['texture'] = tex;
      detectedFeatures.addAll(feat2);
      suspiciousIndicators.addAll(susp2);

      // DETECTOR 3: Validación de Perspectiva
      print('  Detector 3: Validación de Perspectiva...');
      final (per, feat3, susp3) = _validatePerspective(image);
      detectorScores['perspective'] = per;
      detectedFeatures.addAll(feat3);
      suspiciousIndicators.addAll(susp3);

      // DETECTOR 4: Histograma Avanzado
      print('  Detector 4: Histograma Avanzado...');
      final (hist, feat4, susp4) = _analyzeAdvancedHistogram(image, currency);
      detectorScores['histogram'] = hist;
      detectedFeatures.addAll(feat4);
      suspiciousIndicators.addAll(susp4);

      // DETECTOR 5: OCR + Seguridad
      print('  Detector 5: OCR + Validación...');
      final (ocr, feat5, susp5) = await _validateOCRAndSecurity(imagePath, currency);
      detectorScores['ocr'] = ocr;
      detectedFeatures.addAll(feat5);
      suspiciousIndicators.addAll(susp5);

      // SCORING BAYESIANO PONDERADO
      final weights = {
        'security': 0.30,
        'texture': 0.20,
        'perspective': 0.15,
        'histogram': 0.20,
        'ocr': 0.15,
      };

      double weightedScore = 0.0;
      detectorScores.forEach((detector, score) {
        final weight = weights[detector] ?? 0.0;
        weightedScore += score * weight;
        print('    $detector: ${(score * 100).toStringAsFixed(1)}% (peso: ${(weight * 100).toInt()}%)');
      });

      final isAuthentic = weightedScore >= 0.65;

      print('════════════════════════════════════════════════════════════');
      print('✨ RESULTADO FINAL DEL ANÁLISIS AVANZADO');
      print('════════════════════════════════════════════════════════════');
      print('🎯 Score Ponderado: ${(weightedScore * 100).toStringAsFixed(1)}%');
      print('🔐 Autenticidad: ${isAuthentic ? '✅ AUTÉNTICO' : '⚠️ SOSPECHOSO'}');
      print('📋 Características detectadas: ${detectedFeatures.length}');
      print('⚠️ Indicadores sospechosos: ${suspiciousIndicators.length}');

      final reasoning = _generateReasoning(
        weightedScore,
        detectorScores,
        detectedFeatures,
        suspiciousIndicators,
        isAuthentic,
      );

      return BillAnalysis(
        hasBilletFeatures: true,
        isAuthentic: isAuthentic,
        confidence: weightedScore,
        denomination: denomination,
        currency: currency,
        details: reasoning,
        detectedKeywords: basicResult.detectedKeywords ?? [],
        detectedFeatures: detectedFeatures,
        suspiciousIndicators: suspiciousIndicators,
      );
    } catch (e) {
      print('❌ Error en análisis avanzado: $e');
      return BillAnalysis(
        hasBilletFeatures: true,
        isAuthentic: false,
        confidence: 0.0,
        denomination: denomination,
        currency: currency,
        details: 'Error en análisis avanzado: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DETECTOR 1: Características de Seguridad
  // ═══════════════════════════════════════════════════════════════

  Future<(double, List<String>, List<String>)> _detectSecurityFeatures(
      img.Image image,
      String imagePath,
      ) async {
    final features = <String>[];
    final suspicious = <String>[];
    double score = 0.0;

    try {
      final hasMicroprint = _detectMicroprint(image);
      if (hasMicroprint) {
        features.add('Microimpresión detectada');
        score += 0.15;
      }

      final hasBands = _detectSecurityBands(image);
      if (hasBands) {
        features.add('Franjas de seguridad detectadas');
        score += 0.15;
      }

      final hasColorVar = _detectColorVariation(image);
      if (hasColorVar) {
        features.add('Variación de color consistente');
        score += 0.10;
      }

      final hasSmooth = _detectSmoothGradients(image);
      if (hasSmooth) {
        features.add('Gradientes suaves detectados');
        score += 0.10;
      }

      final (brightOk, contrastOk) = _validateBrightnessContrast(image);
      if (brightOk) {
        features.add('Brillo dentro de rango normal');
        score += 0.05;
      } else {
        suspicious.add('Brillo fuera de rango (posible falsificación)');
      }

      if (contrastOk) {
        features.add('Contraste normal');
        score += 0.05;
      } else {
        suspicious.add('Contraste anormal');
      }

      final fileSize = File(imagePath).lengthSync();
      if (fileSize > 500000) {
        features.add('Resolución de imagen alta');
        score += 0.10;
      } else if (fileSize < 50000) {
        suspicious.add('Resolución muy baja (posible escaneo de baja calidad)');
      }

      return (min(score, 1.0), features, suspicious);
    } catch (e) {
      print('⚠️ Error en _detectSecurityFeatures: $e');
      return (0.0, features, suspicious);
    }
  }

  bool _detectMicroprint(img.Image image) {
    final laplacian = _computeLaplacian(image);
    int highFreqCount = 0;
    for (final val in laplacian) {
      if (val > 50) highFreqCount++;
    }
    return (highFreqCount / laplacian.length) > 0.05;
  }

  List<double> _computeLaplacian(img.Image image) {
    const kernel = [
      [0, -1, 0],
      [-1, 4, -1],
      [0, -1, 0]
    ];

    final gray = _toGrayscale(image);
    final result = <double>[];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double sum = 0;
        for (int ky = 0; ky < 3; ky++) {
          for (int kx = 0; kx < 3; kx++) {
            final px = gray[(y - 1 + ky) * image.width + (x - 1 + kx)];
            sum += kernel[ky][kx] * px;
          }
        }
        result.add(sum.abs());
      }
    }
    return result;
  }

  List<int> _toGrayscale(img.Image image) {
    final result = <int>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        final gray = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b).toInt();
        result.add(gray);
      }
    }
    return result;
  }

  bool _detectSecurityBands(img.Image image) {
    final hist = _computeEdgeHistogram(image);
    final sorted = List<int>.from(hist)..sort();
    final median = sorted[sorted.length ~/ 2];
    final peaks = hist.where((v) => v > median * 1.5).length;
    return peaks > 5;
  }

  List<int> _computeEdgeHistogram(img.Image image) {
    final gray = _toGrayscale(image);
    final hist = List<int>.filled(360, 0);

    for (int i = 0; i < gray.length - image.width; i++) {
      final dy = (gray[i + image.width] - gray[i]).abs();
      if (dy > 20) {
        final bin = (atan2(dy.toDouble(), 1) * 180 / pi).toInt() % 360;
        hist[bin]++;
      }
    }
    return hist;
  }

  bool _detectColorVariation(img.Image image) {
    const sampleSize = 10;
    final step = image.width ~/ sampleSize;

    double prevR = 0, prevG = 0, prevB = 0;
    int transitions = 0;

    for (int i = 0; i < sampleSize; i++) {
      final x = i * step;
      final px = image.getPixel(x, image.height ~/ 2);

      if (i > 0) {
        final dR = (px.r - prevR).abs();
        final dG = (px.g - prevG).abs();
        final dB = (px.b - prevB).abs();

        if (dR + dG + dB > 10 && dR + dG + dB < 100) {
          transitions++;
        }
      }
      prevR = px.r.toDouble();
      prevG = px.g.toDouble();
      prevB = px.b.toDouble();
    }

    return transitions >= 3;
  }

  bool _detectSmoothGradients(img.Image image) {
    final gray = _toGrayscale(image);
    int smoothPixels = 0;

    for (int i = 1; i < gray.length - 1; i++) {
      final diff = (gray[i] - gray[i - 1]).abs();
      if (diff < 20) smoothPixels++;
    }

    return (smoothPixels / gray.length) > 0.80;
  }

  (bool, bool) _validateBrightnessContrast(img.Image image) {
    final gray = _toGrayscale(image);
    gray.sort();

    final mean = gray.reduce((a, b) => a + b) ~/ gray.length;
    final min = gray.first;
    final max = gray.last;

    final brightOk = mean >= 80 && mean <= 180;
    final contrastOk = (max - min) > 80;

    return (brightOk, contrastOk);
  }

  // ═══════════════════════════════════════════════════════════════
  // DETECTOR 2: Análisis de Textura
  // ═══════════════════════════════════════════════════════════════

  (double, List<String>, List<String>) _analyzeTexturePatterns(
      img.Image image,
      ) {
    final features = <String>[];
    final suspicious = <String>[];
    double score = 0.0;

    try {
      final lbpHist = _computeLBPHistogram(image);
      final expectedPattern = _getExpectedLBPPattern();
      final similarity = _histogramDistance(lbpHist, expectedPattern);

      if (similarity < 0.3) {
        features.add('Patrón de textura característico');
        score += 0.25;
      } else {
        suspicious.add('Patrón de textura atípico (posible fotocopia)');
      }

      final entropy = _computeEntropy(lbpHist);
      if (entropy > 4.0 && entropy < 7.5) {
        features.add('Textura con entropía normal');
        score += 0.15;
      } else {
        suspicious.add('Textura demasiado regular o caótica');
      }

      final hasPeriodicity = _detectPeriodicity(image);
      if (!hasPeriodicity) {
        features.add('Sin patrones periódicos (no es fotocopia)');
        score += 0.20;
      } else {
        suspicious.add('Patrones periódicos detectados (posible fotocopia)');
      }

      return (min(score, 1.0), features, suspicious);
    } catch (e) {
      print('⚠️ Error en _analyzeTexturePatterns: $e');
      return (0.0, features, suspicious);
    }
  }

  List<int> _computeLBPHistogram(img.Image image) {
    final gray = _toGrayscale(image);
    final hist = List<int>.filled(256, 0);

    const step = 8;
    for (int y = 1; y < image.height - 1; y += step) {
      for (int x = 1; x < image.width - 1; x += step) {
        final idx = y * image.width + x;
        final center = gray[idx];

        int lbp = 0;
        for (int i = 0; i < 8; i++) {
          final angle = i * pi / 4;
          final nx = (x + cos(angle)).toInt();
          final ny = (y + sin(angle)).toInt();

          if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
            final neighbor = gray[ny * image.width + nx];
            if (neighbor >= center) lbp |= (1 << i);
          }
        }

        hist[lbp]++;
      }
    }

    return hist;
  }

  List<double> _getExpectedLBPPattern() {
    return List<double>.filled(256, 0.004)..[128] = 0.15..[64] = 0.12..[192] = 0.10;
  }

  double _histogramDistance(List<int> h1, List<double> h2) {
    double distance = 0.0;
    final total = h1.fold<int>(0, (a, b) => a + b);
    final normalized = h1.map((x) => x / (total + 1)).toList();

    for (int i = 0; i < h1.length; i++) {
      distance += (normalized[i] - h2[i]).abs();
    }
    return distance / h1.length;
  }

  double _computeEntropy(List<int> hist) {
    final total = hist.fold<int>(0, (a, b) => a + b);
    double entropy = 0.0;

    for (final count in hist) {
      if (count > 0) {
        final p = count / total;
        entropy -= p * log(p);
      }
    }
    return entropy;
  }

  bool _detectPeriodicity(img.Image image) {
    final gray = _toGrayscale(image);

    int periodCount = 0;
    for (int period = 10; period < 200; period += 10) {
      int matches = 0;
      for (int i = 0; i < gray.length - period; i++) {
        if ((gray[i] - gray[i + period]).abs() < 10) matches++;
      }
      if (matches > gray.length * 0.6) periodCount++;
    }

    return periodCount > 3;
  }

  // ═══════════════════��═══════════════════════════════════════════
  // DETECTOR 3: Validación de Perspectiva
  // ═══════════════════════════════════════════════════════════════

  (double, List<String>, List<String>) _validatePerspective(
      img.Image image,
      ) {
    final features = <String>[];
    final suspicious = <String>[];
    double score = 0.5;

    try {
      final edges = _detectEdges(image);
      if (edges.isNotEmpty) {
        features.add('Perspectiva rectangular válida');
        score += 0.30;
      } else {
        suspicious.add('No se detectaron bordes claros del billete');
      }

      return (max(0.0, min(score, 1.0)), features, suspicious);
    } catch (e) {
      print('⚠️ Error en _validatePerspective: $e');
      return (0.5, features, suspicious);
    }
  }

  List<int> _detectEdges(img.Image image) {
    final gray = _toGrayscale(image);
    final edges = <int>[];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        int gx = 0, gy = 0;

        gx -= gray[(y - 1) * image.width + (x - 1)];
        gx -= 2 * gray[y * image.width + (x - 1)];
        gx -= gray[(y + 1) * image.width + (x - 1)];
        gx += gray[(y - 1) * image.width + (x + 1)];
        gx += 2 * gray[y * image.width + (x + 1)];
        gx += gray[(y + 1) * image.width + (x + 1)];

        gy -= gray[(y - 1) * image.width + (x - 1)];
        gy -= 2 * gray[(y - 1) * image.width + x];
        gy -= gray[(y - 1) * image.width + (x + 1)];
        gy += gray[(y + 1) * image.width + (x - 1)];
        gy += 2 * gray[(y + 1) * image.width + x];
        gy += gray[(y + 1) * image.width + (x + 1)];

        edges.add((sqrt((gx * gx + gy * gy).toDouble())).toInt());
      }
    }
    return edges;
  }

  // ═══════════════════════════════════════════════════════════════
  // DETECTOR 4: Histograma Avanzado
  // ═══════════════════════════════════════════════════════════════

  (double, List<String>, List<String>) _analyzeAdvancedHistogram(
      img.Image image,
      String currency,
      ) {
    final features = <String>[];
    final suspicious = <String>[];
    double score = 0.0;

    try {
      final rgbHist = _computeRGBHistogram(image);
      final rgbScore = _scoreRGBHistogram(rgbHist, currency);
      score += rgbScore * 0.5;

      if (rgbScore > 0.7) {
        features.add('Distribución RGB dentro de rangos esperados');
      } else {
        suspicious.add('Distribución RGB atípica');
      }

      final hsvHist = _computeHSVHistogram(image);
      final hsvScore = _scoreHSVHistogram(hsvHist, currency);
      score += hsvScore * 0.5;

      if (hsvScore > 0.7) {
        features.add('Distribución HSV característica');
      } else {
        suspicious.add('Saturación de color anómala');
      }

      return (min(score, 1.0), features, suspicious);
    } catch (e) {
      print('⚠️ Error en _analyzeAdvancedHistogram: $e');
      return (0.0, features, suspicious);
    }
  }

  List<int> _computeRGBHistogram(img.Image image) {
    final hist = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        final gray = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b).toInt();
        hist[gray]++;
      }
    }
    return hist;
  }

  double _scoreRGBHistogram(List<int> hist, String currency) {
    final target = currency == 'USD' ? 125 : 115;
    final tolerance = 30;

    int inRange = 0;
    final total = hist.fold<int>(0, (a, b) => a + b);

    for (int i = target - tolerance; i < target + tolerance; i++) {
      if (i >= 0 && i < 256) inRange += hist[i];
    }

    return inRange / (total + 1);
  }

  List<int> _computeHSVHistogram(img.Image image) {
    final hist = List<int>.filled(360, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        final hue = _rgbToHue(px.r.toInt(), px.g.toInt(), px.b.toInt());
        hist[hue]++;
      }
    }
    return hist;
  }

  int _rgbToHue(int r, int g, int b) {
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);

    double hue = 0;
    if (max == r) {
      hue = (60 * ((g - b) / (max - min + 1)) + 360) % 360;
    } else if (max == g) {
      hue = (60 * ((b - r) / (max - min + 1)) + 120) % 360;
    } else {
      hue = (60 * ((r - g) / (max - min + 1)) + 240) % 360;
    }

    return hue.toInt();
  }

  double _scoreHSVHistogram(List<int> hist, String currency) {
    final range = currency == 'USD' ? (90, 180) : (0, 360);

    int inRange = 0;
    final total = hist.fold<int>(0, (a, b) => a + b);

    for (int i = range.$1; i < range.$2; i++) {
      inRange += hist[i];
    }

    return inRange / (total + 1);
  }

  // ═══════════════════════════════════════════════════════════════
  // DETECTOR 5: OCR + Seguridad
  // ═══════════════════════════════════════════════════════════════

  Future<(double, List<String>, List<String>)> _validateOCRAndSecurity(
      String imagePath,
      String currency,
      ) async {
    final features = <String>[];
    final suspicious = <String>[];
    double score = 0.0;

    try {
      if (!_authInitialized) {
        _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        _authInitialized = true;
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.toUpperCase();

      if (text.isEmpty) {
        suspicious.add('No se pudo leer texto (posible baja calidad)');
        return (0.0, features, suspicious);
      }

      final securityKeywords = currency == 'USD'
          ? [
        'FEDERAL RESERVE NOTE',
        'IN GOD WE TRUST',
        'LEGAL TENDER',
        'SECRETARY OF THE TREASURY'
      ]
          : [
        'BANCO CENTRAL DEL ECUADOR',
        'REPÚBLICA DEL ECUADOR',
        'DÓLAR',
        'SERIE'
      ];

      int keywordsFound = 0;
      for (final keyword in securityKeywords) {
        if (text.contains(keyword)) {
          keywordsFound++;
          features.add('Detectado: $keyword');
        }
      }

      score = (keywordsFound / securityKeywords.length).clamp(0.0, 1.0);

      final serialMatch = RegExp(r'[A-Z]{1,2}\d{6,9}[A-Z]?').hasMatch(text);
      if (serialMatch) {
        features.add('Número de serie detectado');
        score += 0.15;
      } else {
        suspicious.add('Número de serie no legible');
      }

      final hasCopyArtifacts = text.contains('COPY') ||
          text.contains('КОПИЯ') ||
          text.contains('COPIA');
      if (hasCopyArtifacts) {
        suspicious.add('Marcas de fotocopia detectadas');
        score -= 0.50;
      }

      return (max(0.0, min(score, 1.0)), features, suspicious);
    } catch (e) {
      print('⚠️ Error en _validateOCRAndSecurity: $e');
      return (0.0, features, suspicious);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════

  String _generateReasoning(
      double weightedScore,
      Map<String, double> detectorScores,
      List<String> detectedFeatures,
      List<String> suspiciousIndicators,
      bool isAuthentic,
      ) {
    final buffer = StringBuffer();

    buffer.writeln('ANÁLISIS DETALLADO DE AUTENTICIDAD');
    buffer.writeln('═' * 50);

    buffer.writeln('\n✅ CARACTERÍSTICAS POSITIVAS:');
    if (detectedFeatures.isEmpty) {
      buffer.writeln('  - Ninguna característica positiva detectada');
    } else {
      for (final feat in detectedFeatures) {
        buffer.writeln('  ✓ $feat');
      }
    }

    buffer.writeln('\n⚠️ INDICADORES SOSPECHOSOS:');
    if (suspiciousIndicators.isEmpty) {
      buffer.writeln('  - Ningún indicador sospechoso detectado');
    } else {
      for (final ind in suspiciousIndicators) {
        buffer.writeln('  ⚠ $ind');
      }
    }

    buffer.writeln('\n📊 SCORES POR DETECTOR:');
    detectorScores.forEach((detector, score) {
      buffer.writeln('  $detector: ${(score * 100).toStringAsFixed(1)}%');
    });

    buffer.writeln('\n🔐 CONCLUSIÓN:');
    if (isAuthentic) {
      buffer.writeln(
          'Este billete tiene características consistentes con un billete auténtico.');
      buffer.writeln('Recomendación: ✅ ACEPTAR');
    } else {
      buffer.writeln(
          'Este billete presenta indicadores que sugieren que podría ser falso.');
      buffer.writeln('Recomendación: ⚠️ VERIFICAR MANUALMENTE');
    }

    return buffer.toString();
  }

  void dispose() {
    _mlService.dispose();
    _denomDetector.dispose();
    if (_authInitialized) {
      try {
        _textRecognizer.close();
      } catch (_) {}
    }
  }
}