import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Datos de ejemplo
    final List<Map<String, dynamic>> history = [
      {
        'denomination': '\$100',
        'date': '15/04/2026 14:30',
        'status': 'Auténtico',
        'confidence': '95%',
        'isAuthentic': true,
      },
      {
        'denomination': '\$50',
        'date': '15/04/2026 13:15',
        'status': 'Falso',
        'confidence': '88%',
        'isAuthentic': false,
      },
      {
        'denomination': '\$20',
        'date': '14/04/2026 10:45',
        'status': 'Auténtico',
        'confidence': '92%',
        'isAuthentic': true,
      },
    ];

    return Scaffold(
      appBar: const CustomAppBar(title: 'Historial de Verificaciones'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade900,
              Colors.deepPurple.shade500,
            ],
          ),
        ),
        child: history.isEmpty
            ? Center(
          child: Text(
            'No hay verificaciones aún',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white.withOpacity(0.1),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item['isAuthentic']
                        ? Colors.green
                        : Colors.red,
                  ),
                  child: Icon(
                    item['isAuthentic']
                        ? Icons.check
                        : Icons.close,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  'Billete ${item['denomination']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['date'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      '${item['status']} (${item['confidence']})',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}