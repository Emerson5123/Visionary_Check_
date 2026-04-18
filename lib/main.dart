import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/reference_dataset_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Inicializando Visionary Check...');

  // 1. Inicializar BD
  final dbService = DatabaseService();
  try {
    await dbService.database;
    print('✅ Base de datos inicializada');
  } catch (e) {
    print('❌ Error BD: $e');
  }

  // 2. Indexar dataset de assets
  final refService = ReferenceDatasetService();
  try {
    await refService.indexAssetDataset();
    print('✅ Dataset de referencia indexado');
  } catch (e) {
    print('❌ Error indexando dataset: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visionary Cash Check',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}