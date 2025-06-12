import 'package:file_selector/file_selector.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'dart:math';
import 'dart:convert';

class ImportResult {
  final List<Transaction> transactions;
  final int processedCount;
  final int skippedCount;
  final int errorCount;

  ImportResult({
    required this.transactions,
    required this.processedCount,
    required this.skippedCount,
    required this.errorCount,
  });
}

class TDImportService {
  final DatabaseHelper _db;

  TDImportService(this._db);

  Future<ImportResult> importFromCSV(XFile file) async {
    try {
      print('Starting TD import for file: ${file.path}');

      // Validate file
      if (!file.path.toLowerCase().endsWith('.csv')) {
        throw Exception('File must be a CSV file');
      }

      // Read file as bytes first to check encoding
      final bytes = await file.readAsBytes();
      print('File size in bytes: ${bytes.length}');

      // Check if file starts with ZIP signature
      if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        throw Exception(
            'File appears to be a ZIP file. Please extract the CSV file first.');
      }

      // Try different encodings
      String content;
      try {
        // Try UTF-8 first
        content = utf8.decode(bytes);
      } catch (e) {
        try {
          // Try Windows-1252 (common for CSV files)
          content = latin1.decode(bytes);
        } catch (e) {
          throw Exception(
              'Could not read file. Please ensure it is a valid CSV file.');
        }
      }

      print('File content length: ${content.length}');
      print(
          'First 100 characters: ${content.substring(0, min(100, content.length))}');

      final lines = content.split('\n');
      print('Number of lines in file: ${lines.length}');

      if (lines.isEmpty) {
        throw Exception('File is empty');
      }

      // Print first few lines for debugging
      print('First 3 lines of file:');
      for (var i = 0; i < min(3, lines.length); i++) {
        print('Line $i: ${lines[i]}');
      }

      final transactions = <Transaction>[];
      int processedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;

      // Process each line (no header to skip)
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          print('\nProcessing line $i: $line');

          final fields = _parseCSVLine(line);
          print('Parsed fields: $fields');

          if (fields.length < 4) {
            print('Skipping line $i: insufficient fields (${fields.length})');
            skippedCount++;
            continue;
          }

          final description = fields[1].trim();
          print('Description: $description');

          // Skip ignored transactions
          if (_shouldSkipTransaction(description)) {
            skippedCount++;
            continue;
          }

          // Calculate amount from debit and credit columns
          final debit = _parseAmount(fields[2].trim());
          final credit = _parseAmount(fields[3].trim());
          final amount = credit > 0 ? credit : -debit;
          print(
              'Amount calculation - Debit: $debit, Credit: $credit, Final: $amount');

          if (amount == 0.0) {
            print('Skipping line $i: zero amount');
            skippedCount++;
            continue;
          }

          final date = _parseDate(fields[0].trim());
          print('Date: $date');

          final isExpense = amount < 0;

          // Guess category based on description
          String category = await _getCategoryForDescription(description);
          print('Category: $category');

          final transaction = Transaction(
            amount: amount.abs(),
            category: category,
            date: date,
            isExpense: isExpense,
            note: description,
          );

          try {
            await _db.insertTransaction(transaction);
            transactions.add(transaction);
            processedCount++;
            print(
                'Successfully processed transaction: ${transaction.note} (${transaction.amount})');
          } on DuplicateTransactionException {
            print('Skipping duplicate transaction: ${transaction.note}');
            skippedCount++;
            continue;
          }
        } catch (e) {
          print('Error processing line $i: $e');
          errorCount++;
          continue;
        }
      }

      print('\nImport summary:');
      print('Processed: $processedCount');
      print('Skipped: $skippedCount');
      print('Errors: $errorCount');

      if (processedCount == 0) {
        throw Exception('No valid transactions found in the file');
      }

      return ImportResult(
        transactions: transactions,
        processedCount: processedCount,
        skippedCount: skippedCount,
        errorCount: errorCount,
      );
    } catch (e) {
      print('Error in TD import: $e');
      rethrow;
    }
  }

  List<String> _parseCSVLine(String line) {
    final fields = <String>[];
    var currentField = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(currentField);
        currentField = '';
      } else {
        currentField += char;
      }
    }
    fields.add(currentField); // Add the last field

    return fields;
  }

  bool _shouldSkipTransaction(String description) {
    final skipPatterns = [
      'TD EASY TRANSFER',
      'TRANSFER TO',
      'TRANSFER FROM',
      'INTERAC E-TRANSFER',
      'INTERAC TRANSFER',
    ];

    final shouldSkip = skipPatterns.any(
        (pattern) => description.toUpperCase().contains(pattern.toUpperCase()));

    if (shouldSkip) {
      print('Skipping transaction with description: $description');
    }

    return shouldSkip;
  }

  double _parseAmount(String amountStr) {
    print('Parsing amount string: $amountStr');
    // Remove currency symbols and whitespace, but preserve the negative sign
    amountStr = amountStr.replaceAll(RegExp(r'[^\d.-]'), '');
    print('Cleaned amount string: $amountStr');
    // Ensure we're not removing the negative sign
    final amount = double.tryParse(amountStr) ?? 0.0;
    print('Parsed amount: $amount');
    return amount;
  }

  DateTime _parseDate(String dateStr) {
    print('Parsing date string: $dateStr');
    // Handle different date formats
    // Try MM/DD/YYYY format
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      final date = DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      print('Parsed date (MM/DD/YYYY): $date');
      return date;
    }
    // Try YYYY-MM-DD format
    final date = DateTime.parse(dateStr);
    print('Parsed date (YYYY-MM-DD): $date');
    return date;
  }

  Future<String> _getCategoryForDescription(String desc) async {
    final mappings = await _db.getCategoryMappings();
    final upperDesc = desc.toUpperCase();

    for (final mapping in mappings) {
      if (upperDesc.contains(mapping.description.toUpperCase())) {
        return mapping.category;
      }
    }
    return 'Other';
  }
}
