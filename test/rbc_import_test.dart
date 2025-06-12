import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:expense_tracker/services/rbc_import_service.dart';
import 'package:expense_tracker/models/category_mapping.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
    importService = RBCImportService(db);
  });

  tearDown(() async {
    await database.close();
  });

  group('RBC Import Tests', () {
    test('Import RBC CSV with category mapping', () async {
      // Add test category mapping
      await db.insertCategoryMapping(CategoryMapping(
        description: 'PAYROLL',
        category: 'Salary',
      ));

      // Create test CSV content
      const csvContent = '''
ACCOUNT TYPE,ACCOUNT NUMBER,TRANSACTION DATE,TRANSACTION TIME,DESCRIPTION 1,DESCRIPTION 2,CAD\$
Chequing,123456789,01/01/2024,12:00:00,PAYROLL,Monthly Salary,1000.00
''';

      // Create temporary file
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/test_rbc.csv');
      await file.writeAsString(csvContent);

      // Create XFile from the temporary file
      final xFile = XFile(file.path);

      // Import the file
      final result = await importService.importFromCSV(xFile);

      // Verify results
      expect(result.processedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.errorCount, 0);
      expect(result.transactions.length, 1);
      expect(result.transactions[0].amount, 1000.0);
      expect(result.transactions[0].category, 'Salary');
      expect(result.transactions[0].isExpense, false);
      expect(result.transactions[0].creationDate, isNotNull);

      // Clean up
      await file.delete();
    });
  });
}
