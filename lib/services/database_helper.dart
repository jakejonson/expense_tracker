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
      version: 1,
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
    // Handle database upgrades here if needed in the future
    if (oldVersion < 2) {
      // Example of how to add a new column in a future version
      // await db.execute('ALTER TABLE transactions ADD COLUMN new_column TEXT');
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

    final id = await db.insert('transactions', transaction.toMap());

    // If this is a recurring transaction, schedule the next occurrence
    if (transaction.isRecurring == 1 && transaction.frequency != null) {
      await _scheduleNextTransaction(transaction.toMap(), id);
    }

    return id;
  }

  Future<List<Transaction>> getTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('transactions', orderBy: 'date DESC');
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
        final pastTransaction = Map<String, dynamic>.from(originalTransaction);
        pastTransaction['date'] = nextDate.toIso8601String();
        pastTransaction['originalTransactionId'] = originalId;
        pastTransaction['nextOccurrence'] = nextDate.toIso8601String();
        pastTransaction['id'] = null;

        await db.insert('transactions', pastTransaction);
      }
    }

    // Schedule the next future occurrence without creating it
    final nextFutureDate = nextDate;
    final nextTransaction = Map<String, dynamic>.from(originalTransaction);
    nextTransaction['date'] = nextFutureDate.toIso8601String();
    nextTransaction['originalTransactionId'] = originalId;
    nextTransaction['nextOccurrence'] = nextFutureDate.toIso8601String();
    nextTransaction['id'] = null;

    // Do not insert the future transaction
    // await db.insert('transactions', nextTransaction);
  }

  DateTime _calculateNextDate(DateTime currentDate, String frequency) {
    switch (frequency) {
      case 'weekly':
        return currentDate.add(const Duration(days: 7));
      case 'biweekly':
        return currentDate.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(
            currentDate.year, currentDate.month + 1, currentDate.day);
      case 'yearly':
        return DateTime(
            currentDate.year + 1, currentDate.month, currentDate.day);
      default:
        return currentDate;
    }
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
    try {
      await _ensureCategoryMappingTable();
      final db = await database;
      final List<Map<String, dynamic>> maps =
          await db.query('category_mappings');
      return List.generate(
          maps.length, (i) => CategoryMapping.fromMap(maps[i]));
    } catch (e) {
      print('Error getting category mappings: $e');
      return [];
    }
  }

  Future<void> addCategoryMapping(CategoryMapping mapping) async {
    try {
      await _ensureCategoryMappingTable();
      final db = await database;
      await db.insert(
        'category_mappings',
        mapping.toMap(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error adding category mapping: $e');
      rethrow;
    }
  }

  Future<void> deleteCategoryMapping(String description) async {
    try {
      await _ensureCategoryMappingTable();
      final db = await database;
      await db.delete(
        'category_mappings',
        where: 'description = ?',
        whereArgs: [description],
      );
    } catch (e) {
      print('Error deleting category mapping: $e');
      rethrow;
    }
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
    final List<Transaction> createdTransactions = [];
    
    // Get all recurring transactions that have a nextOccurrence in the past
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'isRecurring = ? AND nextOccurrence <= ?',
      whereArgs: [1, now.toIso8601String()],
    );

    for (var map in maps) {
      final transaction = Transaction.fromMap(map);
      if (transaction.frequency != null) {
        // Create the next occurrence
        final nextDate =
            _calculateNextDate(transaction.date, transaction.frequency!);
        
        // Create new transaction
        final nextTransaction = Map<String, dynamic>.from(transaction.toMap());
        nextTransaction['date'] = nextDate.toIso8601String();
        nextTransaction['originalTransactionId'] = transaction.id;
        nextTransaction['nextOccurrence'] = nextDate.toIso8601String();
        nextTransaction['id'] = null;

        final id = await db.insert('transactions', nextTransaction);
        createdTransactions.add(Transaction.fromMap({
          ...nextTransaction,
          'id': id,
        }));
      }
    }

    return createdTransactions;
  }
} 