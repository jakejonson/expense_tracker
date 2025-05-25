import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:expense_tracker/models/transaction.dart' as models;
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/services/database_helper.dart';
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
              note TEXT,
              date TEXT NOT NULL,
              isExpense INTEGER NOT NULL,
              isRecurring INTEGER NOT NULL DEFAULT 0,
              frequency TEXT,
              originalTransactionId INTEGER,
              nextOccurrence TEXT
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
        },
      ),
    );

    db = DatabaseHelper.instance;
    db.setTestDatabase(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Reports screen shows empty state', (WidgetTester tester) async {
    print('Starting empty state test');
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );

    // Use pump instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('No expense data for this month'), findsOneWidget);
    print('Completed empty state test');
  });

  testWidgets('Reports screen shows transaction data',
      (WidgetTester tester) async {
    print('Starting transaction data test');
    // Add test data
    final now = DateTime.now();
    await db.insertTransaction(models.Transaction(
      amount: 100.0,
      category: 'Food',
      date: now,
      isExpense: true,
    ));
    await db.insertTransaction(models.Transaction(
      amount: 200.0,
      category: 'Transport',
      date: now,
      isExpense: true,
    ));
    await db.insertTransaction(models.Transaction(
      amount: 300.0,
      category: 'Salary',
      date: now,
      isExpense: false,
    ));

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );

    // Use pump with timeout instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    // Verify summary cards
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('\$300.00'), findsOneWidget); // Income
    expect(find.text('\$300.00'), findsNWidgets(2)); // Expenses

    // Verify category breakdown
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('\$200.00'), findsOneWidget);
    print('Completed transaction data test');
  });

  testWidgets('Reports screen shows budget data', (WidgetTester tester) async {
    print('Starting budget data test');
    // Add test data
    final now = DateTime.now();
    await db.insertBudget(Budget(
      amount: 1000.0,
      category: 'Food',
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
    ));
    await db.insertBudget(Budget(
      amount: 2000.0,
      category: 'Transport',
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
    ));

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );

    // Use pump with timeout instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    // Verify budget data
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('\$1,000.00'), findsOneWidget);
    expect(find.text('\$2,000.00'), findsOneWidget);
    print('Completed budget data test');
  });

  testWidgets('Month selector changes data', (WidgetTester tester) async {
    print('Starting month selector test');
    // Add test data for different months
    final now = DateTime.now();
    final nextMonth = now.add(const Duration(days: 32));

    await db.insertTransaction(models.Transaction(
      amount: 100.0,
      category: 'Food',
      date: now,
      isExpense: true,
    ));
    await db.insertTransaction(models.Transaction(
      amount: 200.0,
      category: 'Food',
      date: nextMonth,
      isExpense: true,
    ));

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );

    // Use pump with timeout instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    // Verify initial month data
    expect(find.text('\$100.00'), findsOneWidget);

    // Change month
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump(const Duration(seconds: 1));

    // Verify new month data
    expect(find.text('\$200.00'), findsOneWidget);
    print('Completed month selector test');
  });

  testWidgets('Reports screen shows category breakdown',
      (WidgetTester tester) async {
    print('Starting category breakdown test');
    // Add test data with multiple transactions in same category
    final now = DateTime.now();
    await db.insertTransaction(models.Transaction(
      amount: 100.0,
      category: 'Food',
      date: now,
      isExpense: true,
    ));
    await db.insertTransaction(models.Transaction(
      amount: 150.0,
      category: 'Food',
      date: now,
      isExpense: true,
    ));
    await db.insertTransaction(models.Transaction(
      amount: 200.0,
      category: 'Transport',
      date: now,
      isExpense: true,
    ));

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );

    // Use pump with timeout instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    // Verify category totals
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('\$250.00'), findsOneWidget); // Food total
    expect(find.text('\$200.00'), findsOneWidget); // Transport total
    print('Completed category breakdown test');
  });

  testWidgets('Reports screen shows budget progress',
      (WidgetTester tester) async {
    print('Starting budget progress test');
    // Add test data with budget and expenses
    final now = DateTime.now();
    await db.insertBudget(Budget(
      amount: 1000.0,
      category: 'Food',
      startDate: now,
      endDate: now.add(const Duration(days: 30)),
    ));
    await db.insertTransaction(models.Transaction(
      amount: 600.0,
      category: 'Food',
      date: now,
      isExpense: true,
    ));

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );

    // Use pump with timeout instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    // Verify budget progress
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('\$1,000.00'), findsOneWidget); // Budget amount
    expect(find.text('\$600.00'), findsOneWidget); // Spent amount
    expect(find.text('60%'), findsOneWidget); // Progress percentage
    print('Completed budget progress test');
  });

  testWidgets('Reports screen handles no data gracefully',
      (WidgetTester tester) async {
    print('Starting no data test');
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );

    // Use pump with timeout instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    // Verify empty state
    expect(find.text('No expense data for this month'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('\$0.00'), findsNWidgets(2)); // Zero amounts
    print('Completed no data test');
  });
}
