import 'dart:math';
import 'package:image/image.dart' as img;

/// Servicio para mejorar imágenes de baja calidad
/// Utiliza técnicas profesionales de procesamiento de imagen
class ImageEnhancementService {

  /// Mejora imagen de forma integral para mejor detección
  static img.Image enhanceForAnalysis(img.Image image) {
    var enhanced = image;

    // Paso 1: Normalizar brillo con percentiles
    enhanced = _normalizeBrightness(enhanced);

    // Paso 2: Mejorar contraste adaptativo (CLAHE)
    enhanced = _adaptiveContrastEnhancement(enhanced);

    // Paso 3: Reducir ruido sin perder detalles
    enhanced = _denoise(enhanced);

    // Paso 4: Mejorar bordes y nitidez
    enhanced = _sharpenEdges(enhanced);

    return enhanced;
  }

  static img.Image _normalizeBrightness(img.Image image) {
    final gray = _toGrayscale(image);
    final sorted = List<int>.from(gray)..sort();

    // Usar percentiles 5-95 para ignorar extremos
    final p5 = sorted[(sorted.length * 0.05).toInt()];
    final p95 = sorted[(sorted.length * 0.95).toInt()];


    final targetMean = 128;
    final adjustment = targetMean - robustMean;

    print('🔆 Normalización: media=$robustMean, ajuste=$adjustment');

    final result = img.Image.from(image);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
      }
    }
    return result;
  }

  /// CLAHE - Contrast Limited Adaptive Histogram Equalization
  /// Mejora contraste local sin crear artefactos
  static img.Image _adaptiveContrastEnhancement(img.Image image) {
    const tileSize = 32;
    const clipLimit = 40;

    final gray = _toGrayscale(image);
    final width = image.width;
    final height = image.height;

    final result = List<int>.from(gray);

    final tilesX = (width / tileSize).ceil();
    final tilesY = (height / tileSize).ceil();

    for (int ty = 0; ty < tilesY; ty++) {
      for (int tx = 0; tx < tilesX; tx++) {
        final x1 = tx * tileSize;
        final y1 = ty * tileSize;
        final x2 = min((tx + 1) * tileSize, width);
        final y2 = min((ty + 1) * tileSize, height);

        // Calcular histograma del tile
        final hist = List<int>.filled(256, 0);
        for (int y = y1; y < y2; y++) {
          for (int x = x1; x < x2; x++) {
            if (y * width + x < gray.length) {
              hist[gray[y * width + x]]++;
            }
          }
        }

        // Aplicar limite de contraste
        final pixelCount = (x2 - x1) * (y2 - y1);
        final clipCount = max(1, (pixelCount * clipLimit / 100).toInt());

        int excess = 0;
        for (int i = 0; i < 256; i++) {
          if (hist[i] > clipCount) {
            excess += hist[i] - clipCount;
            hist[i] = clipCount;
          }
        }

        // Distribuir excess uniformemente
        if (excess > 0) {
          final increment = excess ~/ 256;
          for (int i = 0; i < 256; i++) {
            hist[i] += increment;
          }
        }

        // Crear CDF y aplicar transformación
        final cdf = _computeCDF(hist);
        for (int y = y1; y < y2; y++) {
          for (int x = x1; x < x2; x++) {
            final idx = y * width + x;
            if (idx < gray.length) {
              result[idx] = cdf[gray[idx]];
            }
          }
        }
      }
    }

    return _grayToImage(image, result);
  }

  /// Reducir ruido manteniendo bordes (Bilateral-like)
  static img.Image _denoise(img.Image image) {
    const radius = 2;
    const colorSigma = 30;
    const spaceSigma = 5;

    final gray = _toGrayscale(image);
    final width = image.width;
    final height = image.height;
    final result = List<int>.from(gray);

    for (int y = radius; y < height - radius; y++) {
      for (int x = radius; x < width - radius; x++) {
        final center = gray[y * width + x].toDouble();
        double sumWeighted = 0;
        double sumWeights = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final neighbor = gray[(y + dy) * width + (x + dx)].toDouble();

            // Peso: similaridad de color + distancia espacial
            final colorDiff = (center - neighbor).abs();
            final spatialDist = sqrt(dx * dx + dy * dy.toDouble());

            if (colorDiff < colorSigma) {
              final weight = exp(-(colorDiff * colorDiff) / (2 * colorSigma * colorSigma)) *
                  exp(-(spatialDist * spatialDist) / (2 * spaceSigma * spaceSigma));

              sumWeighted += neighbor * weight;
              sumWeights += weight;
            }
          }
        }

        if (sumWeights > 0) {
          result[y * width + x] = (sumWeighted / sumWeights).toInt().clamp(0, 255);
        }
      }
    }

    return _grayToImage(image, result);
  }

  /// Mejorar nitidez usando unsharp masking
  static img.Image _sharpenEdges(img.Image image) {
    const strength = 1.5;

    final gray = _toGrayscale(image);
    final width = image.width;
    final height = image.height;

    // Crear versión suavizada (Gaussian blur 3x3)
    final blurred = List<int>.from(gray);
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int sum = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final idx = (y + dy) * width + (x + dx);
            if (idx >= 0 && idx < gray.length) {
              sum += gray[idx];
            }
          }
        }
        blurred[y * width + x] = (sum / 9).toInt();
      }
    }

    // Unsharp mask: original + strength * (original - blurred)
    final result = List<int>.from(gray);
    for (int i = 0; i < gray.length; i++) {
      final diff = (gray[i] - blurred[i]) * strength;
      result[i] = (gray[i] + diff).toInt().clamp(0, 255);
    }

    return _grayToImage(image, result);
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Convertir imagen a escala de grises
  static List<int> _toGrayscale(img.Image image) {
    final result = <int>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        final gray = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b).toInt();
        result.add(gray.clamp(0, 255));
      }
    }
    return result;
  }

  /// Convertir array de grises a imagen
  static img.Image _grayToImage(img.Image original, List<int> gray) {
    final result = img.Image.from(original);
    int idx = 0;
    for (int y = 0; y < original.height; y++) {
      for (int x = 0; x < original.width; x++) {
        if (idx < gray.length) {
          final value = gray[idx++].clamp(0, 255);
        }
      }
    }
    return result;
  }

  /// Calcular Cumulative Distribution Function
  static List<int> _computeCDF(List<int> hist) {
    final cdf = List<int>.filled(256, 0);
    cdf[0] = hist[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + hist[i];
    }

    final total = cdf[255];
    if (total == 0) return hist;

    return [
      for (int i = 0; i < 256; i++)
        (cdf[i] * 255 ~/ total).clamp(0, 255)
    ];
  }
}
