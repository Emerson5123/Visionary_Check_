import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';

class BillNumberExtractor {
  static Future<BillNumbers> extractNumbers(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      var image = img.decodeImage(imageBytes);

      if (image == null) throw Exception('No se pudo decodificar');

      print('\n🔢 ═══════════════════════════════════════════════════');
      print('🔢 EXTRAYENDO NÚMEROS DEL BILLETE');
      print('🔢 ═══════════════════════════════════════════════════\n');

      // CAPA 1: OCR completo
      print('📝 CAPA 1: OCR completo...');
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await textRecognizer.processImage(inputImage);
      final fullText = recognized.text.toUpperCase();

      print('   ✓ ${fullText.length} caracteres leídos');

      // CAPA 2: Procesamiento de líneas
      print('\n📋 CAPA 2: Análisis de líneas...');
      final lineAnalysis = _analyzeLineByLine(recognized);

      // CAPA 3: Extracción de números
      print('\n🔍 CAPA 3: Extrayendo números...');
      final denomination = _extractDenomination(fullText, lineAnalysis);
      final serialNumber = _extractSerialNumber(fullText, lineAnalysis);
      final seriesYear = _extractSeriesYear(fullText, lineAnalysis);

      // CAPA 4: OCR optimizado para esquinas (donde están los números grandes)
      print('\n📐 CAPA 4: Analizando esquinas...');
      final cornerNumbers = await _extractCornerNumbers(image, imagePath);

      textRecognizer.close();

      print('\n═══════════════════════════════════════════════════');
      print('✅ NÚMEROS EXTRAÍDOS:');
      print('   Denominación: ${denomination.value}');
      print('   Confianza: ${(denomination.confidence * 100).toStringAsFixed(1)}%');
      print('   Número de serie: ${serialNumber.value}');
      print('   Series/Año: ${seriesYear.value}');
      print('   Números en esquinas: $cornerNumbers');
      print('═══════════════════════════════════════════════════\n');

      return BillNumbers(
        denomination: denomination,
        serialNumber: serialNumber,
        seriesYear: seriesYear,
        cornerNumbers: cornerNumbers,
        fullText: fullText,
      );
    } catch (e) {
      print('❌ Error extrayendo números: $e\n');
      return BillNumbers(
        denomination: ExtractedValue('Unknown', 0.0),
        serialNumber: ExtractedValue('', 0.0),
        seriesYear: ExtractedValue('', 0.0),
        cornerNumbers: [],
        fullText: '',
      );
    }
  }

  /// Analiza línea por línea
  static Map<String, LineInfo> _analyzeLineByLine(RecognizedText recognized) {
    final lines = <String, LineInfo>{};

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.toUpperCase();
        final confidence = _calculateLineConfidence(line);

        // Limpiar espacios
        final cleanText = text.replaceAll(RegExp(r'\s+'), '');

        lines[cleanText] = LineInfo(
          originalText: text,
          cleanText: cleanText,
          confidence: confidence,
          boundingBox: line.boundingBox,
        );

        if (confidence > 0.6) {
          print('   ✓ Línea (${(confidence * 100).toStringAsFixed(0)}%): $text');
        }
      }
    }

    return lines;
  }

  static double _calculateLineConfidence(TextLine line) {
    double total = 0.0;
    int count = 0;

    for (final element in line.elements) {
      final conf = element.confidence ?? 0.0;
      total += conf;
      count++;
    }

    return count > 0 ? total / count : 0.0;
  }

  /// Extrae denominación
  static ExtractedValue _extractDenomination(
      String fullText, Map<String, LineInfo> lines) {
    final patterns = [
      (RegExp(r'\b100\b'), '100', 0.95),
      (RegExp(r'\b50\b'), '50', 0.95),
      (RegExp(r'\b20\b'), '20', 0.95),
      (RegExp(r'\b10\b'), '10', 0.95),
      (RegExp(r'\b5\b'), '5', 0.90),
      (RegExp(r'\b2\b'), '2', 0.90),
      (RegExp(r'\b1\b'), '1', 0.85),
      // Con palabras
      (RegExp(r'HUNDRED'), '100', 0.85),
      (RegExp(r'FIFTY'), '50', 0.85),
      (RegExp(r'TWENTY'), '20', 0.85),
      (RegExp(r'TEN'), '10', 0.85),
      (RegExp(r'FIVE'), '5', 0.80),
      (RegExp(r'TWO'), '2', 0.80),
      (RegExp(r'ONE'), '1', 0.75),
    ];

    for (final (pattern, denom, confidence) in patterns) {
      if (pattern.hasMatch(fullText)) {
        print('   🎯 Denominación \$$denom (confianza: ${(confidence * 100).toStringAsFixed(0)}%)');
        return ExtractedValue(denom, confidence);
      }
    }

    return ExtractedValue('Unknown', 0.0);
  }

  /// Extrae número de serie
  static ExtractedValue _extractSerialNumber(
      String fullText, Map<String, LineInfo> lines) {
    // Patrón: Letras + Números + Letra
    // Ejemplo: A12345678B, QF11269052D

    final patterns = [
      RegExp(r'[A-Z]{1,2}\d{6,10}[A-Z]?'),  // Estándar
      RegExp(r'[A-Z]\d{8}[A-Z]'),            // Formato común
      RegExp(r'[A-Z]{2}\d{8}[A-Z]'),         // Dos letras inicio
    ];

    for (final line in lines.values) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line.cleanText);
        if (match != null) {
          final serial = match.group(0) ?? '';
          if (serial.length >= 8) {
            print('   🎯 Número de serie: $serial (confianza: ${(line.confidence * 100).toStringAsFixed(0)}%)');
            return ExtractedValue(serial, line.confidence);
          }
        }
      }
    }

    // Buscar en texto completo
    for (final pattern in patterns) {
      final match = pattern.firstMatch(fullText);
      if (match != null) {
        final serial = match.group(0) ?? '';
        if (serial.length >= 8) {
          print('   🎯 Número de serie: $serial');
          return ExtractedValue(serial, 0.7);
        }
      }
    }

    return ExtractedValue('', 0.0);
  }

  /// Extrae año/serie
  static ExtractedValue _extractSeriesYear(
      String fullText, Map<String, LineInfo> lines) {
    final patterns = [
      RegExp(r'SERIES\s+(\d{3,4})'),      // SERIES 2017
      RegExp(r'SERIES\s+(\d{4})\s+[A-Z]'), // SERIES 2017 A
      RegExp(r'(\d{4})\s+SERIES'),         // 2017 SERIES
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fullText);
      if (match != null) {
        final series = match.group(1) ?? '';
        print('   🎯 Series/Año: $series');
        return ExtractedValue(series, 0.85);
      }
    }

    return ExtractedValue('', 0.0);
  }

  /// Extrae números grandes de las esquinas
  static Future<List<String>> _extractCornerNumbers(
      img.Image image, String imagePath) async {
    final cornerNumbers = <String>[];

    try {
      // Esquinas: arriba-izq, arriba-der, abajo-izq, abajo-der
      final corners = [
        _CornerRegion(0, 0, 'top-left'),
        _CornerRegion(image.width - 100, 0, 'top-right'),
        _CornerRegion(0, image.height - 100, 'bottom-left'),
        _CornerRegion(image.width - 100, image.height - 100, 'bottom-right'),
      ];

      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      for (final corner in corners) {
        try {
          final cropped = img.copyCrop(
            image,
            x: max(0, corner.x),
            y: max(0, corner.y),
            width: min(150, image.width - max(0, corner.x)),
            height: min(150, image.height - max(0, corner.y)),
          );

          // Mejorar contraste
          final enhanced = _enhanceForNumbers(cropped);

          // Guardar temporalmente
          final tempFile = File('${Directory.systemTemp.path}/corner_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(img.encodeJpg(enhanced));

          // OCR
          final inputImage = InputImage.fromFilePath(tempFile.path);
          final recognized = await textRecognizer.processImage(inputImage);
          final text = recognized.text.trim();

          if (text.isNotEmpty) {
            print('   📍 ${corner.name}: $text');
            cornerNumbers.add(text);
          }

          await tempFile.delete();
        } catch (e) {
          print('   ⚠️ Error en esquina ${corner.name}: $e');
        }
      }

      textRecognizer.close();
    } catch (e) {
      print('   ⚠️ Error extrayendo números de esquinas: $e');
    }

    return cornerNumbers;
  }

  /// Mejorar imagen para números grandes
  static img.Image _enhanceForNumbers(img.Image image) {
    // Aumentar contraste
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: image.numChannels,
    );

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);

        // Convertir a escala de grises
        final gray = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b).toInt();

        // Aumentar contraste (threshold)
        final enhanced = gray > 128 ? 255 : 0;

        result.setPixelRgba(x, y, enhanced, enhanced, enhanced, px.a.toInt());
      }
    }

    return result;
  }
}

class BillNumbers {
  final ExtractedValue denomination;
  final ExtractedValue serialNumber;
  final ExtractedValue seriesYear;
  final List<String> cornerNumbers;
  final String fullText;

  BillNumbers({
    required this.denomination,
    required this.serialNumber,
    required this.seriesYear,
    required this.cornerNumbers,
    required this.fullText,
  });

  String get formattedDenomination => denomination.value;
  String get formattedSerialNumber => serialNumber.value;
  String get formattedSeriesYear => seriesYear.value;

  String get summary {
    return '''
╔════════════════════════════════════════╗
║       INFORMACIÓN DEL BILLETE          ║
╠════════════════════════════════════════╣
║ Denominación: \$${denomination.value}
║ Confianza: ${(denomination.confidence * 100).toStringAsFixed(1)}%
║
║ Número de Serie: ${serialNumber.value}
║ Confianza: ${(serialNumber.confidence * 100).toStringAsFixed(1)}%
║
║ Series/Año: ${seriesYear.value}
║
║ Números en Esquinas:
${cornerNumbers.map((n) => '║ • $n').join('\n')}
║
╚════════════════════════════════════════╝
    ''';
  }
}

class ExtractedValue {
  final String value;
  final double confidence;

  ExtractedValue(this.value, this.confidence);
}

class LineInfo {
  final String originalText;
  final String cleanText;
  final double confidence;
  final dynamic boundingBox;

  LineInfo({
    required this.originalText,
    required this.cleanText,
    required this.confidence,
    required this.boundingBox,
  });
}

class _CornerRegion {
  final int x;
  final int y;
  final String name;

  _CornerRegion(this.x, this.y, this.name);
}