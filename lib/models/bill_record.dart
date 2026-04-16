import 'package:intl/intl.dart';

class BillRecord {
  final String id;
  final DateTime date;
  final String imagePath;
  final bool isAuthentic;
  final String confidence; // Porcentaje de confianza
  final String denomination; // Denominación del billete

  BillRecord({
    required this.id,
    required this.date,
    required this.imagePath,
    required this.isAuthentic,
    required this.confidence,
    required this.denomination,
  });

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(date);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'isAuthentic': isAuthentic ? 1 : 0,
      'confidence': confidence,
      'denomination': denomination,
    };
  }

  factory BillRecord.fromMap(Map<String, dynamic> map) {
    return BillRecord(
      id: map['id'],
      date: DateTime.parse(map['date']),
      imagePath: map['imagePath'],
      isAuthentic: map['isAuthentic'] == 1,
      confidence: map['confidence'],
      denomination: map['denomination'],
    );
  }
}