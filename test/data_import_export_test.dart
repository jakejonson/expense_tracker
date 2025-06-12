import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart' as models;
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/services/database_helper.dart';
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
        TextCellValue('Creation Date'),
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
          TextCellValue(transaction.creationDate?.toString() ?? ''),
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
        TextCellValue('Creation Date'),
      ]);

      // Add test data
      final now = DateTime.now();
      sheet.appendRow([
        TextCellValue(now.toString()),
        TextCellValue('Food'),
        TextCellValue('100.0'),
        TextCellValue('Expense'),
        TextCellValue('Lunch'),
        TextCellValue(now.toString()),
      ]);
      sheet.appendRow([
        TextCellValue(now.toString()),
        TextCellValue('Transport'),
        TextCellValue('200.0'),
        TextCellValue('Expense'),
        TextCellValue('Bus fare'),
        TextCellValue(now.toString()),
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
          final creationDateStr = row[5]?.value.toString();

          if (dateStr == null ||
              categoryStr == null ||
              amountStr == null ||
              typeStr == null) {
            continue;
          }

          final transaction = models.Transaction(
            amount: double.parse(amountStr),
            category: categoryStr,
            note: noteStr,
            date: DateTime.parse(dateStr),
            isExpense: typeStr == 'Expense',
            creationDate: creationDateStr != null
                ? DateTime.parse(creationDateStr)
                : null,
          );

          await db.insertTransaction(transaction);
        }

        // Verify imported data
        final transactions = await db.getTransactions();
        expect(transactions.length, 2);
        expect(transactions[0].category, 'Food');
        expect(transactions[0].amount, 100.0);
        expect(transactions[1].category, 'Transport');
        expect(transactions[1].amount, 200.0);

        // Clean up
        File(filePath).deleteSync();
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

          if (categoryStr == null ||
              amountStr == null ||
              startDateStr == null ||
              endDateStr == null) {
            continue;
          }

          final budget = Budget(
            amount: double.parse(amountStr),
            category: categoryStr,
            startDate: DateTime.parse(startDateStr),
            endDate: DateTime.parse(endDateStr),
            hasSurpassed: hasSurpassedStr == 'Yes',
          );

          await db.insertBudget(budget);
        }

        // Verify imported data
        final budgets = await db.getBudgets();
        expect(budgets.length, 2);
        expect(budgets[0].category, 'Food');
        expect(budgets[0].amount, 1000.0);
        expect(budgets[1].category, 'Transport');
        expect(budgets[1].amount, 2000.0);

        // Clean up
        File(filePath).deleteSync();
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
        TextCellValue('Creation Date'),
      ]);

      // Add invalid data
      sheet.appendRow([
        TextCellValue('invalid date'),
        TextCellValue('Food'),
        TextCellValue('invalid amount'),
        TextCellValue('invalid type'),
        TextCellValue('Lunch'),
        TextCellValue('invalid creation date'),
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
          final categoryStr = row[1]?.value.toString();
          final amountStr = row[2]?.value.toString();
          final typeStr = row[3]?.value.toString();
          final noteStr = row[4]?.value.toString();
          final creationDateStr = row[5]?.value.toString();

          if (dateStr == null ||
              categoryStr == null ||
              amountStr == null ||
              typeStr == null) {
            continue;
          }

          try {
            final transaction = models.Transaction(
              amount: double.parse(amountStr),
              category: categoryStr,
              note: noteStr,
              date: DateTime.parse(dateStr),
              isExpense: typeStr == 'Expense',
              creationDate: creationDateStr != null
                  ? DateTime.parse(creationDateStr)
                  : null,
            );

            await db.insertTransaction(transaction);
          } catch (e) {
            // Invalid data should be skipped
            continue;
          }
        }

        // Verify no data was imported
        final transactions = await db.getTransactions();
        expect(transactions.length, 0);

        // Clean up
        File(filePath).deleteSync();
      }
    });
  });
}
