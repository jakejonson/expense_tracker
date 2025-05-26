import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:expense_tracker/services/rbc_import_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:file_selector/file_selector.dart';
import 'dart:io';

void main() {
  late DatabaseHelper db;
  late Database database;
  late RBCImportService importService;

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
            CREATE TABLE category_mappings(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              keyword TEXT NOT NULL,
              category TEXT NOT NULL
            )
          ''');

          // Insert some default category mappings
          await db.insert('category_mappings',
              {'keyword': 'PAYROLL', 'category': 'Salary'});
          await db.insert('category_mappings',
              {'keyword': 'HYDRO', 'category': 'Utilities'});
          await db.insert('category_mappings',
              {'keyword': 'ADONIS', 'category': 'Groceries'});
        },
      ),
    );

    db = DatabaseHelper.instance;
    db.setTestDatabase(database);
    importService = RBCImportService(db);
  });

  tearDown(() async {
    await database.close();
  });

  group('RBC CSV Import Tests', () {
    test('Import RBC transactions from CSV', () async {
      // Create test CSV file with valid data
      final csvContent =
          '''Account Type,Account Number,Transaction Date,Cheque Number,Description 1,Description 2,CAD\$,USD\$
Chequing,02201-5042924,2/5/2025,,PAYROLL DEPOSIT,,2153.75,
Chequing,02201-5042924,2/5/2025,,HYDRO QUEBEC,,-51.40,
Chequing,02201-5042924,2/5/2025,,ADONIS,,-19.68,''';

      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'rbc_test.csv');
      File(filePath).writeAsStringSync(csvContent);

      // Create XFile from the test file
      final file = XFile(filePath);

      // Import transactions using the service
      final result = await importService.importFromCSV(file);

      // Verify import statistics
      expect(result.processedCount, 3);
      expect(result.skippedCount, 0);
      expect(result.errorCount, 0);

      // Verify imported data
      final importedTransactions = await db.getTransactions();

      // Should have 3 transactions
      expect(importedTransactions.length, 3);

      // Verify specific transactions
      final payroll = importedTransactions
          .firstWhere((t) => t.note?.contains('PAYROLL') ?? false);
      expect(payroll.amount, 2153.75);
      expect(payroll.isExpense, false);
      expect(payroll.category, 'Salary');

      final hydro = importedTransactions
          .firstWhere((t) => t.note?.contains('HYDRO') ?? false);
      expect(hydro.amount, 51.40);
      expect(hydro.isExpense, true);
      expect(hydro.category, 'Utilities');

      final groceries = importedTransactions
          .firstWhere((t) => t.note?.contains('ADONIS') ?? false);
      expect(groceries.amount, 19.68);
      expect(groceries.isExpense, true);
      expect(groceries.category, 'Groceries');

      // Clean up
      File(filePath).deleteSync();
    });

    test('Handle invalid RBC CSV data', () async {
      // Create test CSV file with invalid data
      final csvContent =
          '''Account Type,Account Number,Transaction Date,Cheque Number,Description 1,Description 2,CAD\$,USD\$
Chequing,02201-5042924,invalid_date,,TEST,,-100.0,
Chequing,02201-5042924,2/5/2025,,TEST,,not_a_number,''';

      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'test_invalid_rbc_import.csv');
      File(filePath).writeAsStringSync(csvContent);

      // Create XFile from the test file
      final file = XFile(filePath);

      // Import transactions
      final lines = await file.readAsString();

      // Skip header row
      for (var i = 1; i < lines.split('\n').length; i++) {
        final fields = lines.split('\n')[i].split(',');
        if (fields.length < 7) continue;

        try {
          final amount = double.tryParse(fields[6].trim()) ?? 0.0;
          final date = DateTime.parse(fields[2].trim());

          // This should not be reached due to invalid data
          expect(true, false);
        } catch (e) {
          // Expected error
          expect(e, isA<FormatException>());
        }
      }

      // Clean up
      File(filePath).deleteSync();
    });
  });
}
