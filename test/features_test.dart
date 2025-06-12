import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/models/category_mapping.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
import 'features_test.mocks.dart';

void main() {
  late DatabaseHelper db;

  setUp(() async {
    // Initialize FFI for testing
    sqflite.sqfliteFfiInit();
    sqflite.databaseFactory = sqflite.databaseFactoryFfi;

    // Create in-memory database for testing
    db = DatabaseHelper.instance;
    db.setTestDatabase(await sqflite.databaseFactoryFfi.openDatabase(
      sqflite.inMemoryDatabasePath,
      options: sqflite.OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
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
              nextOccurrence TEXT,
              creationDate TEXT
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
    ));
  });

  tearDown(() async {
    // Clean up the database after each test
    final db = await sqflite.databaseFactoryFfi
        .openDatabase(sqflite.inMemoryDatabasePath);
    await db.close();
  });

  group('Recurring Transactions Tests', () {
    setUp(() async {
      // Clear the transactions table before each test
      final dbInstance = await db.database;
      await dbInstance.delete('transactions');
    });

    test('Create monthly recurring transaction and verify past occurrences',
        () async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - 4, 1);
      final transaction = Transaction(
        amount: 100.0,
        category: 'Rent',
        date: startDate,
        isExpense: true,
        isRecurring: 1,
        frequency: 'monthly',
      );

      await db.insertTransaction(transaction);

      // Verify all past occurrences are created
      final transactions = await db.getTransactions();
      expect(transactions.length, 5); // Jan + Feb + Mar + Apr + May

      // Verify amounts and categories
      for (var t in transactions) {
        expect(t.amount, 100.0);
        expect(t.category, 'Rent');
        expect(t.isExpense, true);
      }

      // Verify dates
      expect(transactions[0].date, DateTime(now.year, now.month - 4, 1));
      expect(transactions[1].date, DateTime(now.year, now.month - 3, 1));
      expect(transactions[2].date, DateTime(now.year, now.month - 2, 1));
      expect(transactions[3].date, DateTime(now.year, now.month - 1, 1));
      expect(transactions[4].date, DateTime(now.year, now.month - 0, 1));
    });

    test('Create weekly recurring transaction', () async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day - 38);
      final transaction = Transaction(
        amount: 50.0,
        category: 'Groceries',
        date: startDate,
        isExpense: true,
        isRecurring: 1,
        frequency: 'weekly',
      );

      await db.insertTransaction(transaction);

      final transactions = await db.getTransactions();
      expect(transactions.length, 6); // 5 weeks in 38 days + day 1 transaction

      // Verify weekly intervals
      for (var i = 1; i < transactions.length; i++) {
        final difference =
            transactions[i].date.difference(transactions[i - 1].date);
        expect(difference.inDays.abs(), 7);
      }
    });
  });

  group('Category Mappings Tests', () {
    test('Add and retrieve category mapping', () async {
      final mapping = CategoryMapping(
        description: 'TEST STORE',
        category: 'Groceries',
      );

      final id = await db.insertCategoryMapping(mapping);
      final mappings = await db.getCategoryMappings();

      expect(mappings.length, 1);
      expect(mappings[0].description, 'TEST STORE');
      expect(mappings[0].category, 'Groceries');
    });

    test('Update category mapping', () async {
      final mapping = CategoryMapping(
        description: 'TEST STORE',
        category: 'Groceries',
      );

      final id = await db.insertCategoryMapping(mapping);

      final updatedMapping = CategoryMapping(
        description: 'TEST STORE',
        category: 'Shopping',
      );

      await db.insertCategoryMapping(updatedMapping);
      final mappings = await db.getCategoryMappings();

      expect(mappings.length, 1);
      expect(mappings[0].category, 'Shopping');
    });

    test('Delete category mapping', () async {
      final mapping = CategoryMapping(
        description: 'TEST STORE',
        category: 'Groceries',
      );

      final id = await db.insertCategoryMapping(mapping);
      await db.deleteCategoryMapping(id);

      final mappings = await db.getCategoryMappings();
      expect(mappings.length, 0);
    });
  });

  group('Search and Sort Tests', () {
    setUp(() async {
      // Add test transactions with unique dates to avoid duplicates
      final transactions = [
        Transaction(
          amount: 100.0,
          category: 'Rent',
          note: 'January rent',
          date: DateTime(2024, 1, 1, 10, 0),
          isExpense: true,
        ),
        Transaction(
          amount: 50.0,
          category: 'Groceries',
          note: 'Weekly groceries',
          date: DateTime(2024, 1, 2, 10, 0),
          isExpense: true,
        ),
        Transaction(
          amount: 2000.0,
          category: 'Salary',
          note: 'Monthly salary',
          date: DateTime(2024, 1, 3, 10, 0),
          isExpense: false,
        ),
      ];

      for (var t in transactions) {
        await db.insertTransaction(t);
      }
    });

    test('Search by amount', () async {
      final transactions = await db.getTransactions();
      final filtered = transactions
          .where((t) => t.amount.toString().contains('100'))
          .toList();

      expect(filtered.length, 1);
      expect(filtered[0].amount, 100.0);
    });

    test('Search by note', () async {
      final transactions = await db.getTransactions();
      final filtered = transactions
          .where((t) => t.note?.toLowerCase().contains('rent') ?? false)
          .toList();

      expect(filtered.length, 1);
      expect(filtered[0].note, 'January rent');
    });

    test('Sort by date', () async {
      final transactions = await db.getTransactions();
      transactions.sort((a, b) => b.date.compareTo(a.date));

      expect(transactions[0].date, DateTime(2024, 1, 3, 10, 0));
      expect(transactions[1].date, DateTime(2024, 1, 2, 10, 0));
      expect(transactions[2].date, DateTime(2024, 1, 1, 10, 0));
    });

    test('Sort by amount', () async {
      final transactions = await db.getTransactions();
      transactions.sort((a, b) => b.amount.compareTo(a.amount));

      expect(transactions[0].amount, 2000.0);
      expect(transactions[1].amount, 100.0);
      expect(transactions[2].amount, 50.0);
    });

    test('Filter by category', () async {
      final transactions = await db.getTransactions();
      final filtered = transactions.where((t) => t.category == 'Rent').toList();

      expect(filtered.length, 1);
      expect(filtered[0].category, 'Rent');
    });

    test('Filter by transaction type', () async {
      final transactions = await db.getTransactions();
      final expenses = transactions.where((t) => t.isExpense).toList();
      final income = transactions.where((t) => !t.isExpense).toList();

      expect(expenses.length, 2);
      expect(income.length, 1);
    });
  });
}
