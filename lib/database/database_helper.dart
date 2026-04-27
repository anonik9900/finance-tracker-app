import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final path = join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  amount REAL,
  category TEXT,
  type TEXT,
  date TEXT
)
''');

    await db.execute('''
CREATE TABLE budgets (
  category TEXT PRIMARY KEY,
  amount REAL
)
''');
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return await db.query('transactions', orderBy: 'id DESC');
  }

  Future<void> insertTransaction(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('transactions', row);
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertOrUpdateBudget(String cat, double amount) async {
    final db = await database;
    await db.insert(
      'budgets',
      {'category': cat, 'amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, double>> getBudgets() async {
    final db = await database;
    final result = await db.query('budgets');

    return {
      for (var row in result)
        row['category'] as String: row['amount'] as double
    };
  }
}