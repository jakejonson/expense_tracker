import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:expense_tracker/models/transaction.dart' as models;
import 'package:expense_tracker/models/budget.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper db;
  late Database database;

  setUp(() async {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Create in-memory database for testing
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              category TEXT NOT NULL,
              date TEXT NOT NULL,
              isExpense INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE budgets(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              category TEXT,
              startDate TEXT NOT NULL,
              endDate TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    db = DatabaseHelper.instance;
    db.setTestDatabase(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Transaction Tests', () {
    test('Insert transaction', () async {
      final transaction = models.Transaction(
        amount: 100.0,
        category: 'Food',
        date: DateTime.now(),
        isExpense: true,
      );

      final id = await db.insertTransaction(transaction);
      expect(id, 1);

      final transactions = await db.getTransactionsForMonth(DateTime.now());
      expect(transactions.length, 1);
      expect(transactions[0].amount, 100.0);
      expect(transactions[0].category, 'Food');
      expect(transactions[0].isExpense, true);
    });

    test('Get transactions for month', () async {
      final now = DateTime.now();
      final transaction1 = models.Transaction(
        amount: 100.0,
        category: 'Food',
        date: now,
        isExpense: true,
      );
      final transaction2 = models.Transaction(
        amount: 200.0,
        category: 'Transport',
        date: now.add(const Duration(days: 1)),
        isExpense: true,
      );
      final transaction3 = models.Transaction(
        amount: 300.0,
        category: 'Food',
        date: now.add(const Duration(days: 32)),
        isExpense: true,
      );

      await db.insertTransaction(transaction1);
      await db.insertTransaction(transaction2);
      await db.insertTransaction(transaction3);

      final transactions = await db.getTransactionsForMonth(now);
      expect(transactions.length, 2);
    });

    test('Get transactions by date range', () async {
      final now = DateTime.now();
      final transaction1 = models.Transaction(
        amount: 100.0,
        category: 'Food',
        date: now,
        isExpense: true,
      );
      final transaction2 = models.Transaction(
        amount: 200.0,
        category: 'Transport',
        date: now.add(const Duration(days: 1)),
        isExpense: true,
      );

      await db.insertTransaction(transaction1);
      await db.insertTransaction(transaction2);

      final transactions = await db.getTransactionsByDateRange(
        now,
        now.add(const Duration(days: 1)),
      );
      expect(transactions.length, 2);
    });

    test('Delete transaction', () async {
      final transaction = models.Transaction(
        amount: 100.0,
        category: 'Food',
        date: DateTime.now(),
        isExpense: true,
      );

      final id = await db.insertTransaction(transaction);
      await db.deleteTransaction(id);

      final transactions = await db.getTransactionsForMonth(DateTime.now());
      expect(transactions.length, 0);
    });
  });

  group('Budget Tests', () {
    test('Insert budget', () async {
      final budget = Budget(
        amount: 1000.0,
        category: 'Food',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );

      final id = await db.insertBudget(budget);
      expect(id, 1);

      final budgets = await db.getBudgetsForMonth(DateTime.now());
      expect(budgets.length, 1);
      expect(budgets[0].amount, 1000.0);
      expect(budgets[0].category, 'Food');
    });

    test('Get budgets for month', () async {
      final now = DateTime.now();
      final budget1 = Budget(
        amount: 1000.0,
        category: 'Food',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
      );
      final budget2 = Budget(
        amount: 2000.0,
        category: 'Transport',
        startDate: now.add(const Duration(days: 31)),
        endDate: now.add(const Duration(days: 61)),
      );

      await db.insertBudget(budget1);
      await db.insertBudget(budget2);

      final budgets = await db.getBudgetsForMonth(now);
      expect(budgets.length, 1);
    });

    test('Delete budget', () async {
      final budget = Budget(
        amount: 1000.0,
        category: 'Food',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );

      final id = await db.insertBudget(budget);
      await db.deleteBudget(id);

      final budgets = await db.getBudgetsForMonth(DateTime.now());
      expect(budgets.length, 0);
    });
  });
}
