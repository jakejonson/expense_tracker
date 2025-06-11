import 'package:file_selector/file_selector.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/services/database_helper.dart';

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

class BMOImportService {
  final DatabaseHelper _db;

  BMOImportService(this._db);

  Future<ImportResult> importFromCSV(XFile file) async {
    // Validate file
    if (!file.path.toLowerCase().endsWith('.csv')) {
      throw Exception('File must be a CSV file');
    }

    final content = await file.readAsString();
    final lines = content.split('\n');
    if (lines.isEmpty) {
      throw Exception('File is empty');
    }

    // Validate header
    final header = lines[0].toUpperCase();
    if (!header.contains('DATE') ||
        !header.contains('DESCRIPTION') ||
        !header.contains('AMOUNT')) {
      throw Exception(
          'Invalid BMO CSV format. Please ensure you are using the correct export format.');
    }

    final transactions = <Transaction>[];
    int processedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    // Skip header row
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final fields = _parseCSVLine(line);
        if (fields.length < 3) {
          skippedCount++;
          continue;
        }

        final description = fields[1].trim();

        // Skip ignored transactions
        if (_shouldSkipTransaction(description)) {
          skippedCount++;
          continue;
        }

        final amount = _parseAmount(fields[2].trim());
        if (amount == 0.0) {
          skippedCount++;
          continue;
        }

        final date = _parseDate(fields[0].trim());
        final isExpense = amount < 0;

        // Guess category based on description
        String category = await _getCategoryForDescription(description);

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
        } on DuplicateTransactionException catch (e) {
          // Skip duplicate transactions during import
          skippedCount++;
          continue;
        }
      } catch (e) {
        errorCount++;
        continue;
      }
    }

    if (processedCount == 0) {
      throw Exception('No valid transactions found in the file');
    }

    return ImportResult(
      transactions: transactions,
      processedCount: processedCount,
      skippedCount: skippedCount,
      errorCount: errorCount,
    );
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
      'TRANSFER',
      'E-TRANSFER',
      'TRF',
      'PAYMENT',
      'INTERAC',
    ];

    return skipPatterns
        .any((pattern) => description.toUpperCase().contains(pattern));
  }

  double _parseAmount(String amountStr) {
    // Remove currency symbols and whitespace, but preserve the negative sign
    amountStr = amountStr.replaceAll(RegExp(r'[^\d.-]'), '');
    // Ensure we're not removing the negative sign
    return double.tryParse(amountStr) ?? 0.0;
  }

  DateTime _parseDate(String dateStr) {
    // Handle different date formats
    // Try MM/DD/YYYY format
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
    // Try YYYY-MM-DD format
    return DateTime.parse(dateStr);
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
