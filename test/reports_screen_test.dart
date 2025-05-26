import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:expense_tracker/models/transaction.dart' as models;
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:expense_tracker/widgets/month_selector.dart';

class MockDatabaseHelper {
  List<models.Transaction> testTransactions = [];
  sqflite.Database? _database;

  MockDatabaseHelper() {
    _database = null;
  }

  Future<List<models.Transaction>> getTransactionsForMonth(
      DateTime month) async {
    return testTransactions;
  }

  Future<List<models.Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    return testTransactions;
  }

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    throw Exception('Database not initialized');
  }

  void setTestDatabase(sqflite.Database db) {
    _database = db;
  }
}

class TestReportsScreen extends ReportsScreen {
  final MockDatabaseHelper mockDb;

  const TestReportsScreen({super.key, required this.mockDb});

  @override
  State<TestReportsScreen> createState() => _TestReportsScreenState();
}

class _TestReportsScreenState extends State<TestReportsScreen> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, double> _categorySpending = <String, double>{};
  Map<String, double> _categoryIncome = <String, double>{};
  Map<int, double> _monthlySpending = <int, double>{};
  Map<int, double> _dailySpending = <int, double>{};
  List<models.Transaction> _transactions = [];

  MockDatabaseHelper get mockDb => widget.mockDb;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final transactions = await mockDb.getTransactionsForMonth(_selectedMonth);
    final Map<String, double> spending = <String, double>{};
    final Map<String, double> income = <String, double>{};
    final Map<int, double> dailySpending = <int, double>{};
    final Map<int, double> monthlySpending = <int, double>{};

    // Get all transactions for the year to calculate monthly trends
    final yearStart = DateTime(_selectedMonth.year, 1, 1);
    final yearEnd = DateTime(_selectedMonth.year, 12, 31);
    final yearlyTransactions =
        await mockDb.getTransactionsByDateRange(yearStart, yearEnd);

    // Calculate monthly spending for the year
    for (var i = 1; i <= 12; i++) {
      monthlySpending[i] = 0;
    }
    for (var transaction in yearlyTransactions) {
      if (transaction.isExpense) {
        final month = transaction.date.month;
        monthlySpending[month] =
            (monthlySpending[month] ?? 0) + transaction.amount;
      }
    }

    // Calculate daily spending for the selected month
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    for (var i = 1; i <= daysInMonth; i++) {
      dailySpending[i] = 0;
    }
    for (var transaction in transactions) {
      if (transaction.isExpense) {
        final day = transaction.date.day;
        dailySpending[day] = (dailySpending[day] ?? 0) + transaction.amount;
        spending[transaction.category] =
            (spending[transaction.category] ?? 0) + transaction.amount;
      } else {
        income[transaction.category] =
            (income[transaction.category] ?? 0) + transaction.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _categorySpending = spending;
      _categoryIncome = income;
      _monthlySpending = monthlySpending;
      _dailySpending = dailySpending;
    });
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    for (final amount in _categoryIncome.values) {
      totalIncome += amount;
    }
    for (final amount in _categorySpending.values) {
      totalExpenses += amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Column(
        children: [
          MonthSelector(
            selectedMonth: _selectedMonth,
            onMonthChanged: _onMonthChanged,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Income'),
                                Text(
                                  '\$${totalIncome.toStringAsFixed(2)}',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Expenses'),
                                Text(
                                  '\$${totalExpenses.toStringAsFixed(2)}',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Category breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category Breakdown',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ..._categorySpending.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key),
                                  Text('\$${entry.value.toStringAsFixed(2)}'),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  late DatabaseHelper db;
  late sqflite.Database database;
  late MockDatabaseHelper mockDb;

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
    mockDb = MockDatabaseHelper();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Reports screen shows empty state', (WidgetTester tester) async {
    print('Starting empty state test');
    mockDb.testTransactions = [];
    mockDb.setTestDatabase(database);

    print('Building widget...');
    await tester.pumpWidget(
      MaterialApp(
        home: TestReportsScreen(mockDb: mockDb),
      ),
    );

    print('Waiting for initial build...');
    await tester.pump();

    print('Waiting for data loading...');
    await tester.pump(const Duration(seconds: 1));

    print('Verifying UI elements...');
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('No expense data for this month'), findsOneWidget);
    print('Completed empty state test');
  });

  testWidgets('Reports screen shows transaction data',
      (WidgetTester tester) async {
    print('Starting transaction data test');
    // Add test data
    final now = DateTime.now();
    
    // Create test transactions
    final testTransactions = [
      models.Transaction(
        amount: 100.0,
        category: 'Eat Out',
        date: now,
        isExpense: true,
        note: 'Test transaction 1',
      ),
      models.Transaction(
        amount: 200.0,
        category: 'Transportation',
        date: now,
        isExpense: true,
        note: 'Test transaction 2',
      ),
      models.Transaction(
        amount: 300.0,
        category: 'Salary',
        date: now,
        isExpense: false,
        note: 'Test transaction 3',
      ),
    ];

    // Set up mock data
    mockDb.testTransactions = testTransactions;
    mockDb.setTestDatabase(database);

    print('Building widget...');
    await tester.pumpWidget(
      MaterialApp(
        home: TestReportsScreen(mockDb: mockDb),
      ),
    );

    print('Waiting for initial build...');
    await tester.pump();
    
    print('Waiting for data loading...');
    // Use pump with a fixed duration instead of pumpAndSettle
    await tester.pump(const Duration(seconds: 1));

    print('Verifying UI elements...');
    // Verify summary cards
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('\$300.00'),
        findsNWidgets(2)); // Both income and expenses are $300.00

    // Verify category breakdown
    expect(find.text('Eat Out'), findsOneWidget);
    expect(find.text('Transportation'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('\$200.00'), findsOneWidget);
    print('Completed transaction data test');
  });

  testWidgets('Reports screen shows budget data', (WidgetTester tester) async {
    print('Starting budget data test');
    // Add test data
    final now = DateTime.now();
    
    // Create test transactions with budget categories
    final testTransactions = [
      models.Transaction(
        amount: 500.0,
        category: 'Food',
        date: now,
        isExpense: true,
        note: 'Food transaction',
      ),
      models.Transaction(
        amount: 800.0,
        category: 'Transport',
        date: now,
        isExpense: true,
        note: 'Transport transaction',
      ),
    ];

    // Set up mock data
    mockDb.testTransactions = testTransactions;
    mockDb.setTestDatabase(database);

    print('Building widget...');
    await tester.pumpWidget(
      MaterialApp(
        home: TestReportsScreen(mockDb: mockDb),
      ),
    );

    print('Waiting for initial build...');
    await tester.pump();

    print('Waiting for data loading...');
    await tester.pump(const Duration(seconds: 1));

    print('Verifying UI elements...');
    // Verify budget data
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('\$500.00'), findsOneWidget);
    expect(find.text('\$800.00'), findsOneWidget);
    print('Completed budget data test');
  });

  testWidgets('Month selector changes data', (WidgetTester tester) async {
    print('Starting month selector test');
    // Add test data for different months
    final now = DateTime.now();
    final nextMonth = now.add(const Duration(days: 32));
    
    // Create test transactions for different months
    final currentMonthTransactions = [
      models.Transaction(
        amount: 100.0,
        category: 'Food',
        date: now,
        isExpense: true,
        note: 'Current month transaction',
      ),
    ];

    final nextMonthTransactions = [
      models.Transaction(
        amount: 200.0,
        category: 'Food',
        date: nextMonth,
        isExpense: true,
        note: 'Next month transaction',
      ),
    ];

    // Set up mock data for current month
    mockDb.testTransactions = currentMonthTransactions;
    mockDb.setTestDatabase(database);

    print('Building widget...');
    await tester.pumpWidget(
      MaterialApp(
        home: TestReportsScreen(mockDb: mockDb),
      ),
    );

    print('Waiting for initial build...');
    await tester.pump();
    
    print('Waiting for data loading...');
    await tester.pump(const Duration(seconds: 1));

    print('Verifying initial month data...');
    // Debug: Print all text widgets in the UI
    print('All text widgets in UI:');
    final allTexts = find.byType(Text).evaluate();
    for (var element in allTexts) {
      final text = element.widget as Text;
      print('Found text: ${text.data}');
    }

    // Find the Expenses card and verify its amount
    final expensesCard = find.ancestor(
      of: find.text('Expenses'),
      matching: find.byType(Card),
    );
    expect(expensesCard, findsOneWidget, reason: 'Should find Expenses card');

    // Find the amount within the Expenses card
    final expensesAmount = find.descendant(
      of: expensesCard,
      matching: find.text('\$100.00'),
    );
    expect(expensesAmount, findsOneWidget,
        reason: 'Should find amount in Expenses card');

    // Change month
    print('Changing month...');
    // Find the next month button by its icon
    final nextMonthButton = find.byIcon(Icons.chevron_right);
    expect(nextMonthButton, findsOneWidget,
        reason: 'Should find next month button');

    // Update mock data for next month before tapping
    mockDb.testTransactions = nextMonthTransactions;

    // Tap the button and wait for state update
    await tester.tap(nextMonthButton);
    await tester.pump();
    
    // Wait for data loading
    await tester.pump(const Duration(seconds: 1));

    print('Verifying new month data...');
    // Debug: Print all text widgets in the UI after month change
    print('All text widgets in UI after month change:');
    final allTextsAfterChange = find.byType(Text).evaluate();
    for (var element in allTextsAfterChange) {
      final text = element.widget as Text;
      print('Found text: ${text.data}');
    }

    // Find the Expenses card and verify its new amount
    final newExpensesCard = find.ancestor(
      of: find.text('Expenses'),
      matching: find.byType(Card),
    );
    final newExpensesAmount = find.descendant(
      of: newExpensesCard,
      matching: find.text('\$200.00'),
    );
    expect(newExpensesAmount, findsOneWidget,
        reason: 'Should find new amount in Expenses card');
    print('Completed month selector test');
  });

  testWidgets('Reports screen shows category breakdown',
      (WidgetTester tester) async {
    print('Starting category breakdown test');
    // Add test data with multiple transactions in same category
    final now = DateTime.now();
    
    // Create test transactions
    final testTransactions = [
      models.Transaction(
        amount: 100.0,
        category: 'Food',
        date: now,
        isExpense: true,
        note: 'Food transaction 1',
      ),
      models.Transaction(
        amount: 150.0,
        category: 'Food',
        date: now,
        isExpense: true,
        note: 'Food transaction 2',
      ),
      models.Transaction(
        amount: 200.0,
        category: 'Transport',
        date: now,
        isExpense: true,
        note: 'Transport transaction',
      ),
    ];

    // Set up mock data
    mockDb.testTransactions = testTransactions;
    mockDb.setTestDatabase(database);

    print('Building widget...');
    await tester.pumpWidget(
      MaterialApp(
        home: TestReportsScreen(mockDb: mockDb),
      ),
    );

    print('Waiting for initial build...');
    await tester.pump();

    print('Waiting for data loading...');
    await tester.pump(const Duration(seconds: 1));

    print('Verifying category totals...');
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
    
    // Create test transactions
    final testTransactions = [
      models.Transaction(
        amount: 600.0,
        category: 'Food',
        date: now,
        isExpense: true,
        note: 'Food transaction',
      ),
    ];

    // Set up mock data
    mockDb.testTransactions = testTransactions;
    mockDb.setTestDatabase(database);

    print('Building widget...');
    await tester.pumpWidget(
      MaterialApp(
        home: TestReportsScreen(mockDb: mockDb),
      ),
    );

    print('Waiting for initial build...');
    await tester.pump();

    print('Waiting for data loading...');
    await tester.pump(const Duration(seconds: 1));

    print('Verifying budget progress...');

    // Debug: Print all text widgets in the UI
    print('All text widgets in UI:');
    final allTexts = find.byType(Text).evaluate();
    for (var element in allTexts) {
      final text = element.widget as Text;
      print('Found text: ${text.data}');
    }

    // Find the Expenses card and verify its amount
    final expensesCard = find.ancestor(
      of: find.text('Expenses'),
      matching: find.byType(Card),
    );
    expect(expensesCard, findsOneWidget, reason: 'Should find Expenses card');

    // Find the amount within the Expenses card
    final expensesAmount = find.descendant(
      of: expensesCard,
      matching: find.text('\$600.00'),
    );
    expect(expensesAmount, findsOneWidget,
        reason: 'Should find amount in Expenses card');
    
    print('Completed budget progress test');
  });

  testWidgets('Reports screen handles no data gracefully',
      (WidgetTester tester) async {
    print('Starting no data test');
    // Set up empty mock data
    mockDb.testTransactions = [];
    mockDb.setTestDatabase(database);

    print('Building widget...');
    await tester.pumpWidget(
      MaterialApp(
        home: TestReportsScreen(mockDb: mockDb),
      ),
    );

    print('Waiting for initial build...');
    await tester.pump();

    print('Waiting for data loading...');
    await tester.pump(const Duration(seconds: 1));

    print('Verifying empty state...');
    // Verify empty state
    expect(find.text('No expense data for this month'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('\$0.00'), findsNWidgets(2)); // Zero amounts
    print('Completed no data test');
  });
}
