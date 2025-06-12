import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:expense_tracker/models/transaction.dart' as models;
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/category_mapping.dart';
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
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              category TEXT NOT NULL,
              note TEXT,
              date TEXT NOT NULL,
              isExpense INTEGER NOT NULL,
              isRecurring INTEGER NOT NULL DEFAULT 0,
              frequency TEXT,
              originalTransactionId INTEGER,
              nextOccurrence TEXT,
              creationDate TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE budgets(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              category TEXT,
              startDate TEXT NOT NULL,
              endDate TEXT NOT NULL,
              hasSurpassed INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE category_mappings(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              description TEXT NOT NULL,
              category TEXT NOT NULL,
              UNIQUE(description)
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
      expect(transactions[0].creationDate, isNotNull);
    });

    test('Insert duplicate transaction throws exception', () async {
      final now = DateTime.now();
      final transaction = models.Transaction(
        amount: 100.0,
        category: 'Food',
        date: now,
        isExpense: true,
      );

      await db.insertTransaction(transaction);

      expect(
        () => db.insertTransaction(transaction),
        throwsA(isA<DuplicateTransactionException>()),
      );
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
        date: now.add(const Duration(days: -1)),
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

  group('Category Mapping Tests', () {
    test('Insert category mapping', () async {
      final mapping = CategoryMapping(
        description: 'TEST STORE',
        category: 'Shopping',
      );

      final id = await db.insertCategoryMapping(mapping);
      expect(id, 1);

      final mappings = await db.getCategoryMappings();
      expect(mappings.length, 1);
      expect(mappings[0].description, 'TEST STORE');
      expect(mappings[0].category, 'Shopping');
    });

    test('Get category mapping by description', () async {
      final mapping = CategoryMapping(
        description: 'TEST STORE',
        category: 'Shopping',
      );

      await db.insertCategoryMapping(mapping);

      final foundMapping =
          await db.getCategoryMappingByDescription('TEST STORE');
      expect(foundMapping, isNotNull);
      expect(foundMapping!.description, 'TEST STORE');
      expect(foundMapping.category, 'Shopping');
    });

    test('Delete category mapping', () async {
      final mapping = CategoryMapping(
        description: 'TEST STORE',
        category: 'Shopping',
      );

      final id = await db.insertCategoryMapping(mapping);
      await db.deleteCategoryMapping(id);

      final mappings = await db.getCategoryMappings();
      expect(mappings.length, 0);
    });
  });
}
