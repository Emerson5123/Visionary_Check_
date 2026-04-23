import 'dart:math';

class FuzzyMatcherService {
  /// Calcula distancia de Levenshtein
  static int levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    final d = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) d[i][0] = i;
    for (int j = 0; j <= len2; j++) d[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return d[len1][len2];
  }

  /// Calcula similitud (0.0-1.0)
  static double similarity(String s1, String s2) {
    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1.0;
    final distance = levenshteinDistance(s1, s2);
    return 1.0 - (distance / maxLen);
  }

  /// Busca keyword con tolerancia
  static bool fuzzyContains(String text, String keyword,
      {double threshold = 0.70}) {
    final textLower = text.toLowerCase();
    final keywordLower = keyword.toLowerCase();

    // 1. Búsqueda exacta
    if (textLower.contains(keywordLower)) return true;

    // 2. Búsqueda de substring directo (OCR fragmentado)
    if (textLower.contains(keywordLower.substring(0, min(4, keywordLower.length)))) {
      return true;
    }

    // 3. Búsqueda por fragmentos progresivos
    for (int len = max(3, keywordLower.length - 4);
    len <= keywordLower.length;
    len++) {
      for (int i = 0; i <= keywordLower.length - len; i++) {
        final fragment = keywordLower.substring(i, i + len);
        if (textLower.contains(fragment)) {
          // Validar que sea palabra completa (no parte de otra)
          final fragRegex = RegExp(r'\b' + fragment + r'\b');
          if (fragRegex.hasMatch(textLower)) {
            return true;
          }
        }
      }
    }

    // 4. Levenshtein sobre palabras individuales
    final textWords = textLower.split(RegExp(r'\s+|[^\w\dáéíóú]+'))
        .where((w) => w.length > 2)
        .toList();
    final keywordWords = keywordLower.split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();

    for (final textWord in textWords) {
      for (final kwWord in keywordWords) {
        final sim = similarity(textWord, kwWord);
        if (sim >= threshold) {
          print('   [FUZZY] "$textWord" ≈ "$kwWord" (similitud: ${(sim * 100).toStringAsFixed(0)}%)');
          return true;
        }
      }
    }

    // 5. Búsqueda de CUALQUIER palabra del keyword
    for (final kwWord in keywordWords) {
      if (textLower.contains(kwWord)) {
        return true;
      }
    }

    return false;
  }

  /// Extrae números de texto
  static List<String> extractNumbers(String text) {
    final regex = RegExp(r'\d+');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Busca denominación en números
  static String? findDenominationNumber(String text) {
    final denominations = ['100', '50', '20', '10', '5', '2', '1'];
    final numbers = extractNumbers(text);

    for (final denom in denominations) {
      if (numbers.contains(denom)) return denom;
    }

    for (final num in numbers) {
      for (final denom in denominations) {
        if (num.contains(denom)) return denom;
      }
    }

    return null;
  }

  /// Encuentra todas las líneas de texto (por línea OCR)
  static List<String> extractLines(String text) {
    return text.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }
}