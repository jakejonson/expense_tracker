import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/category_mapping.dart';

class DuplicateTransactionException implements Exception {
  final List<Transaction> duplicates;
  DuplicateTransactionException(this.duplicates);

  @override
  String toString() =>
      'Duplicate transaction found: ${duplicates.length} similar transactions exist';
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static sqflite.Database? _database;

  DatabaseHelper._init();

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_tracker.db');
    return _database!;
  }

  // For testing purposes
  void setTestDatabase(sqflite.Database db) {
    _database = db;
  }

  Future<sqflite.Database> _initDB(String filePath) async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await sqflite.openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(sqflite.Database db, int version) async {
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
        nextOccurrence TEXT,
        creationDate TEXT
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

    // Create category mappings table
    await db.execute('''
      CREATE TABLE category_mappings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        UNIQUE(description)
      )
    ''');

    // Insert default category mappings
    await _insertDefaultMappings(db);
  }

  Future<void> _insertDefaultMappings(sqflite.Database db) async {
    final defaultMappings = [
      {'description': 'PAYROLL', 'category': 'Salary'},
      {'description': 'HYDRO', 'category': 'Utilities'},
      {'description': 'BILL', 'category': 'Utilities'},
      {'description': 'UTILITY', 'category': 'Utilities'},
      {'description': 'ELECTRIC', 'category': 'Utilities'},
      {'description': 'CARRY TELECOM', 'category': 'Utilities'},
      {'description': 'FIDO', 'category': 'Utilities'},
      {'description': 'FEE', 'category': 'Utilities'},
      {'description': 'PAYRANGE', 'category': 'Utilities'},
      {'description': 'ESSENCE', 'category': 'Car'},
      {'description': 'COSTCO ESSENCE', 'category': 'Car'},
      {'description': 'GAS', 'category': 'Car'},
      {'description': 'PETRO', 'category': 'Car'},
      {'description': 'SHELL', 'category': 'Car'},
      {'description': 'AGENCE DE MOBILITE', 'category': 'Car'},
      {'description': 'PARC INDIGO', 'category': 'Car'},
      {'description': 'ADONIS', 'category': 'Groceries'},
      {'description': 'WALMART', 'category': 'Groceries'},
      {'description': 'WAL-MART', 'category': 'Groceries'},
      {'description': 'EPICERIE', 'category': 'Groceries'},
      {'description': 'MARCHE', 'category': 'Groceries'},
      {'description': 'IGA', 'category': 'Groceries'},
      {'description': 'METRO ETS', 'category': 'Groceries'},
      {'description': 'METRO COTE NEIGES', 'category': 'Groceries'},
      {'description': 'SUPER C', 'category': 'Groceries'},
      {'description': 'COSTCO WHOLESALE', 'category': 'Groceries'},
      {'description': 'MONDOU', 'category': 'Pet'},
      {'description': 'PET', 'category': 'Pet'},
      {'description': 'AFFIRM', 'category': 'Healthcare'},
      {'description': 'PATREON', 'category': 'Saeid'},
      {'description': 'NAMESILOLLC', 'category': 'Saeid'},
      {'description': 'WISE', 'category': 'Travel'},
      {'description': 'COP @', 'category': 'Travel'},
      {'description': 'UDS @', 'category': 'Travel'},
      {'description': 'EUR @', 'category': 'Travel'},
      {'description': 'UDEMY', 'category': 'Education'},
      {'description': 'RESTAURANT', 'category': 'Eating Out'},
      {'description': 'GRILLADES', 'category': 'Eating Out'},
      {'description': 'DELI', 'category': 'Eating Out'},
      {'description': 'CAFE', 'category': 'Eating Out'},
      {'description': 'RESTO', 'category': 'Eating Out'},
      {'description': 'PUB', 'category': 'Eating Out'},
      {'description': 'BAR', 'category': 'Eating Out'},
      {'description': 'TIM HORTONS', 'category': 'Eating Out'},
      {'description': 'MCDONALD', 'category': 'Eating Out'},
      {'description': 'ROCKABERRY', 'category': 'Eating Out'},
      {'description': 'KEBAB', 'category': 'Eating Out'},
      {'description': 'ANTEP', 'category': 'Eating Out'},
      {'description': 'BOUCHERIE', 'category': 'Eating Out'},
      {'description': 'CLASSPASS*', 'category': 'Sports'},
      {'description': 'AMAZON.CA', 'category': 'Shopping'},
      {'description': 'BEST BUY', 'category': 'Shopping'},
      {'description': 'DOLLARAMA', 'category': 'Shopping'},
      {'description': 'IKEA', 'category': 'Shopping'},
      {'description': 'CANADIAN TIRE', 'category': 'Shopping'},
      {'description': 'NETFLIX', 'category': 'Entertainment'},
      {'description': 'SPOTIFY', 'category': 'Entertainment'},
      {'description': 'DISNEY', 'category': 'Entertainment'},
      {'description': 'PLAYSTATION', 'category': 'Entertainment'},
      {'description': 'PRIME', 'category': 'Entertainment'},
      {'description': 'GOOGLE', 'category': 'Entertainment'},
      {'description': 'CANADALAND', 'category': 'Entertainment'},
      {'description': 'WEALTHSIMPLE', 'category': 'Tax'},
      {'description': 'GOUV', 'category': 'Tax Refund'},
      {'description': 'GST', 'category': 'Tax Refund'},
      {'description': 'TAX REFUND', 'category': 'Tax Refund'},
      {'description': 'GOVERNMENT', 'category': 'Tax Refund'},
    ];

    for (final mapping in defaultMappings) {
      await db.insert(
        'category_mappings',
        mapping,
        conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _onUpgrade(
      sqflite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        // Add creationDate column
        await db
            .execute('ALTER TABLE transactions ADD COLUMN creationDate TEXT');

        // Set creationDate to date for existing transactions
        await db.execute('''
          UPDATE transactions 
          SET creationDate = date 
          WHERE creationDate IS NULL
        ''');
      } catch (e) {
        // If upgrade fails, log error but don't crash
        print('Error during database upgrade: $e');
      }
    }
  }

  // Transaction methods
  Future<int> insertTransaction(Transaction transaction) async {
    final db = await database;
    
    // Check for duplicate transactions
    final duplicates = await findDuplicateTransactions(transaction);
    if (duplicates.isNotEmpty) {
      throw DuplicateTransactionException(duplicates);
    }

    // Set creation date for new transactions
    final transactionMap = transaction.toMap();
    if (transaction.creationDate == null) {
      try {
        transactionMap['creationDate'] = DateTime.now().toIso8601String();
      } catch (e) {
        // If setting current time fails, use transaction date as fallback
        transactionMap['creationDate'] = transaction.date.toIso8601String();
      }
    }

    final id = await db.insert('transactions', transactionMap);

    // If this is a recurring transaction, schedule the next occurrence
    if (transaction.isRecurring == 1 && transaction.frequency != null) {
      await _scheduleNextTransaction(transactionMap, id);
    }

    return id;
  }

  Future<List<Transaction>> getTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy:
          'CASE WHEN creationDate IS NULL THEN date ELSE creationDate END DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getTransactionsByCategory(String? category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (category == null) {
      // For overall budget, get all expense transactions
      maps = await db.query(
        'transactions',
        where: 'isExpense = ?',
        whereArgs: [1],
        orderBy: 'date DESC',
      );
    } else {
      // For category-specific budget
      maps = await db.query(
        'transactions',
        where: 'category = ? AND isExpense = ?',
        whereArgs: [category, 1],
        orderBy: 'date DESC',
      );
    }
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getTransactionsForBudget(Budget budget) async {
    final transactions = await getTransactionsByCategory(budget.category);

    // Filter transactions to only include those within the budget's date range
    return transactions
        .where((transaction) =>
            transaction.date
                .isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
            transaction.date
                .isBefore(budget.endDate.add(const Duration(days: 1))))
        .toList();
  }

  Future<int> updateTransaction(Transaction transaction) async {
    final db = await database;
    final result = await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    // Recalculate budgets after transaction update
    await checkAndUpdateBudgets();

    return result;
  }

  Future<void> updateTransactions(List<Transaction> transactions) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var transaction in transactions) {
        await txn.update(
          'transactions',
          transaction.toMap(),
          where: 'id = ?',
          whereArgs: [transaction.id],
        );
      }
    });

    // Recalculate budgets after bulk update
    await checkAndUpdateBudgets();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTransactionCategory(int id, String newCategory) async {
    final db = await database;
    return await db.update(
      'transactions',
      {'category': newCategory},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  // Budget methods
  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return await db.insert('budgets', budget.toMap());
  }

  Future<List<Budget>> getBudgets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  Future<void> updateBudget(Budget budget) async {
    final db = await database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<void> deleteBudget(int id) async {
    final db = await database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markBudgetAsSurpassed(int id) async {
    final db = await database;
    await db.update(
      'budgets',
      {'hasSurpassed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> checkAndUpdateBudgets() async {
    final db = await instance.database;
    final transactions = await getTransactions();
    final budgets = await getBudgets();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // Calculate spending by category
    final Map<String, double> categorySpending = {};
    for (var transaction in transactions) {
      if (transaction.isExpense &&
          transaction.date
              .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          transaction.date.isBefore(endOfMonth.add(const Duration(days: 1)))) {
        categorySpending[transaction.category] =
            (categorySpending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    // Check each budget
    for (var budget in budgets) {
      if (budget.startDate.isBefore(endOfMonth) &&
          budget.endDate.isAfter(startOfMonth)) {
        double spent = 0;
        if (budget.category == null) {
          // Overall budget
          spent = categorySpending.values
              .fold<double>(0.0, (sum, amount) => sum + (amount));
        } else {
          // Category-specific budget
          spent = categorySpending[budget.category!] ?? 0;
        }

        // Update budget status
        if (spent > budget.amount && !budget.hasSurpassed) {
          await markBudgetAsSurpassed(budget.id!);
        } else if (spent <= budget.amount && budget.hasSurpassed) {
          await db.update(
            'budgets',
            {'hasSurpassed': 0},
            where: 'id = ?',
            whereArgs: [budget.id],
          );
        }
      }
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> _scheduleNextTransaction(
      Map<String, dynamic> originalTransaction, int originalId) async {
    final db = await database;
    final frequency = originalTransaction['frequency'] as String;
    final currentDate = DateTime.parse(originalTransaction['date'] as String);
    final now = DateTime.now();
    DateTime nextDate = currentDate;

    // Create all past occurrences up to now
    while (nextDate.isBefore(now)) {
      nextDate = _calculateNextDate(nextDate, frequency);

      // Only create the transaction if it's in the past
      if (nextDate.isBefore(now)) {
        // Check if a transaction already exists for this date
        final existingTransactions = await db.query(
          'transactions',
          where: 'amount = ? AND category = ? AND date = ? AND isExpense = ?',
          whereArgs: [
            originalTransaction['amount'],
            originalTransaction['category'],
            nextDate.toIso8601String(),
            originalTransaction['isExpense'],
          ],
        );

        if (existingTransactions.isEmpty) {
          final pastTransaction =
              Map<String, dynamic>.from(originalTransaction);
          pastTransaction['date'] = nextDate.toIso8601String();
          pastTransaction['originalTransactionId'] = originalId;
          pastTransaction['nextOccurrence'] =
              null; // Past transactions don't need nextOccurrence
          pastTransaction['id'] = null;

          await db.insert('transactions', pastTransaction);
        }
      }
    }

    // Update the original transaction with the next occurrence
    final nextFutureDate = nextDate;
    await db.update(
      'transactions',
      {'nextOccurrence': nextFutureDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [originalId],
    );
  }

  DateTime _calculateNextDate(DateTime currentDate, String frequency) {
    print(
        'Calculating next date from: ${currentDate.toIso8601String()} with frequency: $frequency');
    DateTime nextDate;
    switch (frequency) {
      case 'weekly':
        nextDate = currentDate.add(const Duration(days: 7));
        break;
      case 'biweekly':
        nextDate = currentDate.add(const Duration(days: 14));
        break;
      case 'monthly':
        // Handle month overflow correctly
        if (currentDate.month == 12) {
          nextDate = DateTime(currentDate.year + 1, 1, currentDate.day);
        } else {
          nextDate = DateTime(
              currentDate.year, currentDate.month + 1, currentDate.day);
        }
        break;
      case 'yearly':
        nextDate =
            DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
        break;
      default:
        nextDate = currentDate;
    }
    print('Calculated next date: ${nextDate.toIso8601String()}');
    return nextDate;
  }

  Future<List<Transaction>> getTransactionsForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    return getTransactionsByDateRange(startOfMonth, endOfMonth);
  }

  Future<List<Transaction>> findDuplicateTransactions(
      Transaction transaction) async {
    final db = await database;
    final startOfDay = DateTime(
        transaction.date.year, transaction.date.month, transaction.date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'amount = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        transaction.amount,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String()
      ],
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Budget>> getBudgetsForMonth(DateTime month) async {
    final db = await instance.database;
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'startDate <= ? AND endDate >= ?',
      whereArgs: [endOfMonth.toIso8601String(), startOfMonth.toIso8601String()],
    );

    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  Future<Map<String, double>> getCategorySpendingForMonth(
      DateTime month) async {
    final transactions = await getTransactionsForMonth(month);
    final Map<String, double> spending = {};

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        spending[transaction.category] =
            (spending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    return spending;
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Transaction(
        id: maps[i]['id'],
        amount: maps[i]['amount'],
        category: maps[i]['category'],
        note: maps[i]['note'],
        date: DateTime.parse(maps[i]['date']),
        isExpense: maps[i]['isExpense'] == 1,
        isRecurring: maps[i]['isRecurring'] == 1 ? 1 : 0,
        frequency: maps[i]['frequency'],
      );
    });
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  // Category Mapping Methods
  Future<void> _ensureCategoryMappingTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_mappings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        UNIQUE(description)
      )
    ''');
  }

  Future<List<CategoryMapping>> getCategoryMappings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('category_mappings');
    return List.generate(maps.length, (i) => CategoryMapping.fromMap(maps[i]));
  }

  Future<CategoryMapping?> getCategoryMappingByDescription(
      String description) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'category_mappings',
      where: 'description = ?',
      whereArgs: [description],
    );

    if (maps.isEmpty) return null;
    return CategoryMapping.fromMap(maps.first);
  }

  Future<int> insertCategoryMapping(CategoryMapping mapping) async {
    final db = await database;
    return await db.insert(
      'category_mappings',
      mapping.toMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategoryMapping(int id) async {
    final db = await database;
    await db.delete(
      'category_mappings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCategoryMapping(CategoryMapping mapping) async {
    try {
      await _ensureCategoryMappingTable();
      final db = await database;
      await db.update(
        'category_mappings',
        {'description': mapping.description, 'category': mapping.category},
        where: 'description = ?',
        whereArgs: [mapping.description],
      );
    } catch (e) {
      print('Error updating category mapping: $e');
      rethrow;
    }
  }

  // Add this new method to check and create new recurring transactions
  Future<List<Transaction>> checkAndCreateRecurringTransactions() async {
    final db = await database;
    final now = DateTime.now();
    print('=== Starting recurring transaction check ===');
    print('Current time: ${now.toIso8601String()}');
    final List<Transaction> createdTransactions = [];
    
    // Get all recurring transactions that have a nextOccurrence in the past
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'isRecurring = ? AND nextOccurrence <= ?',
      whereArgs: [1, now.toIso8601String()],
    );

    print('Found ${maps.length} recurring transactions due');
    if (maps.isEmpty) {
      print('No recurring transactions found that are due');
      return [];
    }

    for (var map in maps) {
      print('\nProcessing transaction:');
      print('ID: ${map['id']}');
      print('Amount: ${map['amount']}');
      print('Category: ${map['category']}');
      print('Frequency: ${map['frequency']}');
      print('Next Occurrence: ${map['nextOccurrence']}');
      
      final transaction = Transaction.fromMap(map);
      if (transaction.frequency != null) {
        final nextOccurrence = DateTime.parse(map['nextOccurrence'] as String);

        // Check if a transaction already exists for this nextOccurrence date
        final existingTransactions = await db.query(
          'transactions',
          where: 'amount = ? AND category = ? AND date = ? AND isExpense = ?',
          whereArgs: [
            transaction.amount,
            transaction.category,
            nextOccurrence.toIso8601String(),
            transaction.isExpense ? 1 : 0,
          ],
        );

        if (existingTransactions.isEmpty) {
          // Create new transaction for the nextOccurrence date
          final nextTransaction =
              Map<String, dynamic>.from(transaction.toMap());
          nextTransaction['date'] = nextOccurrence.toIso8601String();
          nextTransaction['originalTransactionId'] = transaction.id;
          nextTransaction['id'] = null;
          nextTransaction['isRecurring'] =
              0; // The created transaction is not recurring

          // Calculate the next occurrence date
          final nextDate =
              _calculateNextDate(nextOccurrence, transaction.frequency!);
          nextTransaction['nextOccurrence'] = nextDate.toIso8601String();

          try {
            final id = await db.insert('transactions', nextTransaction);
            print('Successfully created new transaction with ID: $id');
            createdTransactions.add(Transaction.fromMap({
              ...nextTransaction,
              'id': id,
            }));

            // Update the original transaction's nextOccurrence
            await db.update(
              'transactions',
              {'nextOccurrence': nextDate.toIso8601String()},
              where: 'id = ?',
              whereArgs: [transaction.id],
            );
            print(
                'Updated original transaction with next occurrence: ${nextDate.toIso8601String()}');
          } catch (e) {
            print('Error creating new transaction: $e');
          }
        } else {
          print(
              'Transaction already exists for this date, updating next occurrence');
          // Calculate and update the next occurrence date
          final nextDate =
              _calculateNextDate(nextOccurrence, transaction.frequency!);
          await db.update(
            'transactions',
            {'nextOccurrence': nextDate.toIso8601String()},
            where: 'id = ?',
            whereArgs: [transaction.id],
          );
          print(
              'Updated original transaction with next occurrence: ${nextDate.toIso8601String()}');
        }
      } else {
        print('Transaction has no frequency set, skipping');
      }
    }

    print('=== Completed recurring transaction check ===');
    print('Created ${createdTransactions.length} new transactions');
    return createdTransactions;
  }

  Future<List<Transaction>> getScheduledTransactions() async {
    final db = await database;
    final now = DateTime.now();

    // Only get recurring transactions that:
    // 1. Are marked as recurring
    // 2. Have a nextOccurrence date in the future
    // 3. Don't have a transaction created for that date yet
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'isRecurring = ? AND nextOccurrence > ?',
      whereArgs: [1, now.toIso8601String()],
      orderBy: 'nextOccurrence ASC',
    );

    // Filter out any transactions that already have an occurrence created for their nextOccurrence date
    final List<Transaction> futureTransactions = [];
    for (var map in maps) {
      final transaction = Transaction.fromMap(map);
      final nextOccurrence = DateTime.parse(map['nextOccurrence'] as String);

      // Check if a transaction already exists for this nextOccurrence date
      final existingTransactions = await db.query(
        'transactions',
        where: 'amount = ? AND category = ? AND date = ? AND isExpense = ?',
        whereArgs: [
          transaction.amount,
          transaction.category,
          nextOccurrence.toIso8601String(),
          transaction.isExpense ? 1 : 0,
        ],
      );

      // Only include if no transaction exists for this date
      if (existingTransactions.isEmpty) {
        futureTransactions.add(transaction);
      }
    }

    return futureTransactions;
  }

  Future<void> cleanupDuplicateTransactions() async {
    final db = await database;
    print('=== Cleaning up duplicate transactions ===');

    // Get all recurring transactions
    final List<Map<String, dynamic>> recurringTransactions = await db.query(
      'transactions',
      where: 'isRecurring = ?',
      whereArgs: [1],
    );

    // Group recurring transactions by amount, category, isExpense, and nextOccurrence
    final Map<String, List<Map<String, dynamic>>> groupedTransactions = {};
    for (var transaction in recurringTransactions) {
      // Only group transactions that have the same nextOccurrence date
      final key =
          '${transaction['amount']}_${transaction['category']}_${transaction['isExpense']}_${transaction['nextOccurrence']}';
      if (!groupedTransactions.containsKey(key)) {
        groupedTransactions[key] = [];
      }
      groupedTransactions[key]!.add(transaction);
    }

    // Delete duplicates, keeping the one with the lowest ID
    for (var group in groupedTransactions.values) {
      if (group.length > 1) {
        print(
            'Found ${group.length} duplicate recurring transactions with same next occurrence date');
        // Sort by ID to keep the oldest one
        group.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        // Delete all but the first one
        for (var i = 1; i < group.length; i++) {
          print(
              'Deleting duplicate recurring transaction with ID: ${group[i]['id']}');
          await db.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [group[i]['id']],
          );
        }
      }
    }
    print('=== Cleanup completed ===');
  }
} 