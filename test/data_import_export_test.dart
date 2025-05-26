import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart' as models;
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

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

  group('Data Export Tests', () {
    test('Export transactions to Excel', () async {
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

      // Create Excel file
      final excel = Excel.createExcel();
      final sheet = excel.sheets.values.first;

      // Add headers
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Type'),
        TextCellValue('Note'),
      ]);

      // Get transactions
      final transactions = await db.getTransactions();

      // Add data
      for (var transaction in transactions) {
        sheet.appendRow([
          TextCellValue(transaction.date.toString()),
          TextCellValue(transaction.category),
          TextCellValue(transaction.amount.toString()),
          TextCellValue(transaction.isExpense ? 'Expense' : 'Income'),
          TextCellValue(transaction.note ?? ''),
        ]);
      }

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'test_export.xlsx');
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Verify file exists
        expect(File(filePath).existsSync(), true);

        // Clean up
        File(filePath).deleteSync();
      }
    });

    test('Export budgets to Excel', () async {
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

      // Create Excel file
      final excel = Excel.createExcel();
      final sheet = excel.sheets.values.first;

      // Add headers
      sheet.appendRow([
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Start Date'),
        TextCellValue('End Date'),
        TextCellValue('Has Surpassed'),
      ]);

      // Get budgets
      final budgets = await db.getBudgets();

      // Add data
      for (var budget in budgets) {
        sheet.appendRow([
          TextCellValue(budget.category ?? 'Overall'),
          TextCellValue(budget.amount.toString()),
          TextCellValue(budget.startDate.toString()),
          TextCellValue(budget.endDate.toString()),
          TextCellValue(budget.hasSurpassed ? 'Yes' : 'No'),
        ]);
      }

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'test_budgets_export.xlsx');
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Verify file exists
        expect(File(filePath).existsSync(), true);

        // Clean up
        File(filePath).deleteSync();
      }
    });
  });

  group('Data Import Tests', () {
    test('Import transactions from Excel', () async {
      // Create test Excel file
      final excel = Excel.createExcel();
      final sheet = excel.sheets.values.first;

      // Add headers
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Type'),
        TextCellValue('Note'),
      ]);

      // Add test data
      final now = DateTime.now();
      sheet.appendRow([
        TextCellValue(now.toString()),
        TextCellValue('Food'),
        TextCellValue('100.0'),
        TextCellValue('Expense'),
        TextCellValue('Lunch'),
      ]);
      sheet.appendRow([
        TextCellValue(now.toString()),
        TextCellValue('Transport'),
        TextCellValue('200.0'),
        TextCellValue('Expense'),
        TextCellValue('Bus fare'),
      ]);

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'test_import.xlsx');
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Read the file
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final importedExcel = Excel.decodeBytes(bytes);

        // Get the first sheet
        final importedSheet = importedExcel.sheets.values.first;

        // Skip header row
        for (var i = 1; i < importedSheet.maxRows; i++) {
          final row = importedSheet.row(i);
          if (row.isEmpty) continue;

          final dateStr = row[0]?.value.toString();
          final categoryStr = row[1]?.value.toString();
          final amountStr = row[2]?.value.toString();
          final typeStr = row[3]?.value.toString();
          final noteStr = row[4]?.value.toString();

          if (dateStr == null ||
              categoryStr == null ||
              amountStr == null ||
              typeStr == null) {
            continue;
          }

          final date = DateTime.parse(dateStr);
          final amount = double.parse(amountStr);
          final isExpense = typeStr == 'Expense';

          // Insert into database
          await db.insertTransaction(models.Transaction(
            amount: amount,
            category: categoryStr,
            date: date,
            isExpense: isExpense,
            note: noteStr,
          ));
        }

        // Verify imported data
        final transactions = await db.getTransactions();
        expect(transactions.length, 2);
        expect(transactions[0].category, 'Food');
        expect(transactions[0].amount, 100.0);
        expect(transactions[1].category, 'Transport');
        expect(transactions[1].amount, 200.0);

        // Clean up
        file.deleteSync();
      }
    });

    test('Import budgets from Excel', () async {
      // Create test Excel file
      final excel = Excel.createExcel();
      final sheet = excel.sheets.values.first;

      // Add headers
      sheet.appendRow([
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Start Date'),
        TextCellValue('End Date'),
        TextCellValue('Has Surpassed'),
      ]);

      // Add test data
      final now = DateTime.now();
      sheet.appendRow([
        TextCellValue('Food'),
        TextCellValue('1000.0'),
        TextCellValue(now.toString()),
        TextCellValue(now.add(const Duration(days: 30)).toString()),
        TextCellValue('No'),
      ]);
      sheet.appendRow([
        TextCellValue('Transport'),
        TextCellValue('2000.0'),
        TextCellValue(now.toString()),
        TextCellValue(now.add(const Duration(days: 30)).toString()),
        TextCellValue('No'),
      ]);

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'test_budgets_import.xlsx');
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Read the file
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final importedExcel = Excel.decodeBytes(bytes);

        // Get the first sheet
        final importedSheet = importedExcel.sheets.values.first;

        // Skip header row
        for (var i = 1; i < importedSheet.maxRows; i++) {
          final row = importedSheet.row(i);
          if (row.isEmpty) continue;

          final categoryStr = row[0]?.value.toString();
          final amountStr = row[1]?.value.toString();
          final startDateStr = row[2]?.value.toString();
          final endDateStr = row[3]?.value.toString();
          final hasSurpassedStr = row[4]?.value.toString();

          if (amountStr == null ||
              startDateStr == null ||
              endDateStr == null ||
              hasSurpassedStr == null) {
            continue;
          }

          final amount = double.parse(amountStr);
          final startDate = DateTime.parse(startDateStr);
          final endDate = DateTime.parse(endDateStr);
          final hasSurpassed = hasSurpassedStr == 'Yes';

          // Insert into database
          await db.insertBudget(Budget(
            amount: amount,
            category: categoryStr,
            startDate: startDate,
            endDate: endDate,
            hasSurpassed: hasSurpassed,
          ));
        }

        // Verify imported data
        final budgets = await db.getBudgets();
        expect(budgets.length, 2);
        expect(budgets[0].category, 'Food');
        expect(budgets[0].amount, 1000.0);
        expect(budgets[1].category, 'Transport');
        expect(budgets[1].amount, 2000.0);

        // Clean up
        file.deleteSync();
      }
    });

    test('Handle invalid Excel data', () async {
      // Create test Excel file with invalid data
      final excel = Excel.createExcel();
      final sheet = excel.sheets.values.first;

      // Add headers
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Type'),
        TextCellValue('Note'),
      ]);

      // Add invalid data
      sheet.appendRow([
        TextCellValue('invalid_date'),
        TextCellValue('Food'),
        TextCellValue('not_a_number'),
        TextCellValue('Invalid'),
        TextCellValue('Test'),
      ]);

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final filePath = path.join(tempDir.path, 'test_invalid_import.xlsx');
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Read the file
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final importedExcel = Excel.decodeBytes(bytes);

        // Get the first sheet
        final importedSheet = importedExcel.sheets.values.first;

        // Skip header row
        for (var i = 1; i < importedSheet.maxRows; i++) {
          final row = importedSheet.row(i);
          if (row.isEmpty) continue;

          final dateStr = row[0]?.value.toString();
          final amountStr = row[2]?.value.toString();

          if (dateStr == null || amountStr == null) {
            continue;
          }

          // Try to parse data, should handle errors gracefully
          try {
            final date = DateTime.parse(dateStr);
            final amount = double.parse(amountStr);

            // This should not be reached due to invalid data
            expect(true, false);
          } catch (e) {
            // Expected error
            expect(e, isA<FormatException>());
          }
        }

        // Clean up
        file.deleteSync();
      }
    });
  });
}
