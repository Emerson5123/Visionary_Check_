import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'visionary_check.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bill_records (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            imagePath TEXT NOT NULL,
            isAuthentic INTEGER NOT NULL,
            confidence TEXT NOT NULL,
            denomination TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }
}