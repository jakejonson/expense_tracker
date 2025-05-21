import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/budget.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static sqflite.Database? _database;

  DatabaseHelper._init();

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_tracker.db');
    return _database!;
  }

  Future<sqflite.Database> _initDB(String filePath) async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, filePath);

    // Delete the existing database file if it exists
    await sqflite.deleteDatabase(path);

    return await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(sqflite.Database db, int version) async {
    // Drop existing tables if they exist
    await db.execute('DROP TABLE IF EXISTS transactions');
    await db.execute('DROP TABLE IF EXISTS budgets');

    // Create transactions table with all required columns
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        isExpense INTEGER NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        frequency TEXT,
        originalTransactionId INTEGER,
        nextOccurrence TEXT
      )
    ''');

    // Create budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        hasSurpassed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // Transaction methods
  Future<int> insertTransaction(Transaction transaction) async {
    final db = await instance.database;
    final id = await db.insert('transactions', transaction.toMap());

    // If this is a recurring transaction, schedule the next occurrence
    if (transaction.isRecurring == 1 && transaction.frequency != null) {
      await _scheduleNextTransaction(transaction.toMap(), id);
    }

    return id;
  }

  Future<List<Transaction>> getTransactions() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps =
        await db.query('transactions', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getTransactionsByCategory(String category) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> updateTransactionCategory(int id, String newCategory) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      {'category': newCategory},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTransaction(int id) async {
    final db = await instance.database;
    // Delete the transaction and all its future occurrences
    await db.delete(
      'transactions',
      where: 'id = ? OR originalTransactionId = ?',
      whereArgs: [id, id],
    );
  }

  // Budget methods
  Future<int> insertBudget(Budget budget) async {
    final db = await instance.database;
    return await db.insert('budgets', budget.toMap());
  }

  Future<List<Budget>> getBudgets() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  Future<void> updateBudget(Budget budget) async {
    final db = await instance.database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<void> deleteBudget(int id) async {
    final db = await instance.database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markBudgetAsSurpassed(int id) async {
    final db = await instance.database;
    await db.update(
      'budgets',
      {'hasSurpassed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> _scheduleNextTransaction(
      Map<String, dynamic> originalTransaction, int originalId) async {
    final db = await instance.database;
    final frequency = originalTransaction['frequency'] as String;
    final currentDate = DateTime.parse(originalTransaction['date'] as String);
    DateTime nextDate;

    // Calculate next occurrence based on frequency
    switch (frequency) {
      case 'weekly':
        nextDate = currentDate.add(const Duration(days: 7));
        break;
      case 'biweekly':
        nextDate = currentDate.add(const Duration(days: 14));
        break;
      case 'monthly':
        nextDate =
            DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
        break;
      case 'yearly':
        nextDate =
            DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
        break;
      default:
        return;
    }

    // Only create the next occurrence if it's in the future
    if (nextDate.isBefore(DateTime.now())) {
      // Create the next occurrence
      final nextTransaction = Map<String, dynamic>.from(originalTransaction);
      nextTransaction['date'] = nextDate.toIso8601String();
      nextTransaction['originalTransactionId'] = originalId;
      nextTransaction['nextOccurrence'] = nextDate.toIso8601String();
      nextTransaction['id'] = null; // Remove the id to create a new transaction

      await db.insert('transactions', nextTransaction);
    }
  }
} 