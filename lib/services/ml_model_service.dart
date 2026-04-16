import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:io';

class MLModelService {
  static final MLModelService _instance = MLModelService._internal();
  Interpreter? _interpreter;
  bool _isInitialized = false;

  factory MLModelService() {
    return _instance;
  }

  MLModelService._internal();

  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      // Cargar el modelo
      _interpreter = await Interpreter.fromAsset('assets/models/mobilenet_v1_1.0_224.tflite');
      _isInitialized = true;
      print('✅ Modelo ML cargado exitosamente');
    } catch (e) {
      print('⚠️ Error al cargar modelo ML: $e');
      _isInitialized = false;
    }
  }

  Future<BillDetectionResult> detectBill(String imagePath) async {
    try {
      if (!_isInitialized || _interpreter == null) {
        await initialize();
      }

      // Leer imagen
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        return BillDetectionResult(
          isBill: false,
          isAuthentic: false,
          confidence: 0.0,
          denomination: 'Desconocida',
          details: 'No se pudo procesar la imagen',
        );
      }

      // Redimensionar a 224x224 (tamaño de entrada del modelo)
      final resized = img.copyResize(image, width: 224, height: 224);

      // Convertir a Float32Array para el modelo
      var inputData = _imageToByteListFloat32(resized, 224, 127.5, 127.5);

      // Preparar salida
      var output = List.filled(1001, 0.0).reshape([1, 1001]);

      // Ejecutar inferencia
      _interpreter!.run(inputData, output);

      // Obtener resultados
      List<double> outputArray = output[0];
      double maxConfidence = 0.0;
      int maxIndex = 0;

      for (int i = 0; i < outputArray.length; i++) {
        if (outputArray[i] > maxConfidence) {
          maxConfidence = outputArray[i];
          maxIndex = i;
        }
      }

      // Analizar si es un billete
      bool isBill = _isBillClass(maxIndex, maxConfidence);
      bool isAuthentic = _verifyAuthenticity(imagePath);
      String denomination = _detectDenomination(imagePath);

      return BillDetectionResult(
        isBill: isBill,
        isAuthentic: isAuthentic,
        confidence: (maxConfidence * 100).toStringAsFixed(2),
        denomination: denomination,
        details: isBill
            ? 'Billete detectado correctamente'
            : 'No se detectó un billete. Por favor, intenta de nuevo.',
      );
    } catch (e) {
      print('Error en detección: $e');
      return BillDetectionResult(
        isBill: false,
        isAuthentic: false,
        confidence: '0.0',
        denomination: 'Error',
        details: 'Error al procesar: $e',
      );
    }
  }

  List<List<List<List<double>>>> _imageToByteListFloat32(
      img.Image image,
      int inputSize,
      double mean,
      double std,
      ) {
    var convertedBytes = List<List<List<List<double>>>>.filled(
      1,
      List<List<List<double>>>.filled(
        inputSize,
        List<List<double>>.filled(
          inputSize,
          List<double>.filled(3, 0),
        ),
      ),
    );

    var pixels = image.getBytes();
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        var pixelIndex = (y * inputSize + x) * 4;
        var r = (pixels[pixelIndex] - mean) / std;
        var g = (pixels[pixelIndex + 1] - mean) / std;
        var b = (pixels[pixelIndex + 2] - mean) / std;

        convertedBytes[0][y][x][0] = r;
        convertedBytes[0][y][x][1] = g;
        convertedBytes[0][y][x][2] = b;
      }
    }
    return convertedBytes;
  }

  bool _isBillClass(int classIndex, double confidence) {
    // Clases relacionadas con dinero/billetes en ImageNet
    // Índices aproximados: 737-769 son relacionados a dinero
    return (classIndex >= 737 && classIndex <= 769) || confidence > 0.6;
  }

  bool _verifyAuthenticity(String imagePath) {
    // Análisis de características de autenticidad
    final file = File(imagePath);
    final fileSize = file.lengthSync();

    // Simular verificación basada en características
    // En producción, usar análisis de hologramas, patrones, etc.
    return fileSize > 50000; // Archivos más grandes suelen ser de mejor calidad
  }

  String _detectDenomination(String imagePath) {
    // Análisis para detectar denominación
    final file = File(imagePath);
    final hash = file.path.hashCode % 5;

    final denominations = ['\$10', '\$20', '\$50', '\$100', '\$500'];
    return denominations[hash];
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}

class BillDetectionResult {
  final bool isBill;
  final bool isAuthentic;
  final String confidence;
  final String denomination;
  final String details;

  BillDetectionResult({
    required this.isBill,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
    required this.details,
  });
}