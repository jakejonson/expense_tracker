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

class RBCImportService {
  final DatabaseHelper _db;

  RBCImportService(this._db);

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
    if (!header.contains('ACCOUNT TYPE') ||
        !header.contains('TRANSACTION DATE') ||
        !header.contains('DESCRIPTION 1') ||
        !header.contains('DESCRIPTION 2') ||
        !header.contains('CAD\$')) {
      throw Exception(
          'Invalid RBC CSV format. Please ensure you are using the correct export format.');
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
        if (fields.length < 7) {
          skippedCount++;
          continue;
        }

        final description1 = fields[4].trim();
        final description2 = fields[5].trim();

        // Skip ignored transactions
        if (_shouldSkipTransaction(description1, description2)) {
          skippedCount++;
          continue;
        }

        final amount = _parseAmount(fields[6].trim());
        if (amount == 0.0) {
          skippedCount++;
          continue;
        }

        final date = _parseDate(fields[2].trim());
        final isExpense = amount < 0;
        final note = _formatNote(description1, description2);

        // Guess category based on description
        String category = await _guessCategory(description1, description2);

        final transaction = Transaction(
          amount: amount.abs(),
          category: category,
          date: date,
          isExpense: isExpense,
          note: note,
        );

        await _db.insertTransaction(transaction);
        transactions.add(transaction);
        processedCount++;
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

  bool _shouldSkipTransaction(String description1, String description2) {
    final skipPatterns = [
      'PAYMENT - THANK YOU / PAIEMENT - MERCI',
      'WWW TRANSFER - 1008',
      'PAYMENT RECEIVED',
      'PAYMENT SENT',
    ];

    return skipPatterns.any((pattern) =>
        description1.toUpperCase().contains(pattern) ||
        description2.toUpperCase().contains(pattern));
  }

  double _parseAmount(String amountStr) {
    // Remove currency symbols and whitespace, but preserve the negative sign
    amountStr = amountStr.replaceAll(RegExp(r'[^\d.-]'), '');
    // Ensure we're not removing the negative sign
    return double.tryParse(amountStr) ?? 0.0;
  }

  DateTime _parseDate(String dateStr) {
    // Handle different date formats
    try {
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
    } catch (e) {
      throw Exception('Invalid date format: $dateStr');
    }
  }

  String _formatNote(String description1, String description2) {
    final parts = [description1, description2]
        .where((s) => s.isNotEmpty)
        .map((s) => s.trim())
        .toList();
    return parts.join(' - ');
  }

  Future<String> _guessCategory(
      String description1, String description2) async {
    final desc = (description1 + ' ' + description2).toUpperCase();

    // Get all category mappings from database
    final mappings = await _db.getCategoryMappings();

    // Check each mapping
    for (final mapping in mappings) {
      if (desc.contains(mapping.keyword)) {
        return mapping.category;
      }
    }

    // If no mapping found, try to guess based on common patterns
    if (desc.contains('PAYROLL')) {
      return 'Salary';
    } else if (desc.contains('HYDRO') ||
        desc.contains('BILL') ||
        desc.contains('UTILITY') ||
        desc.contains('ELECTRIC') ||
        desc.contains('CARRY TELECOM') ||
        desc.contains('MONTHLY FEE') ||
        desc.contains('FIDO')) {
      return 'Utilities';
    } else if (desc.contains('ESSENCE') ||
        desc.contains('GAS') ||
        desc.contains('PETRO') ||
        desc.contains('AGENCE DE MOBILITE') ||
        desc.contains('SHELL')) {
      return 'Car';
    } else if (desc.contains('ADONIS') ||
        desc.contains('MARCHE') ||
        desc.contains('IGA') ||
        desc.contains('METRO COTE NEIGES') ||
        desc.contains('METRO ETS') ||
        desc.contains('SUPER C') ||
        desc.contains('EPICERIE') ||
        desc.contains('WALMART')) {
      return 'Groceries';
    } else if (desc.contains('AFFIRM')) {
      return 'Healthcare';
    } else if (desc.contains('MONDOU') || desc.contains('PET')) {
      return 'Pet';
    } else if (desc.contains('WISE') ||
        desc.contains('COP @') ||
        desc.contains('USD @') ||
        desc.contains('EUR @')) {
      return 'Travel';
    } else if (desc.contains('RESTAURANT') ||
        desc.contains('CAFE') ||
        desc.contains('RESTO') ||
        desc.contains('TIM HORTONS') ||
        desc.contains('McDonalds') ||
        desc.contains('ROCKABERRY') ||
        desc.contains('KEBAB') ||
        desc.contains('ANTEP') ||
        desc.contains('PUB') ||
        desc.contains('BAR') ||
        desc.contains('MCDONALD')) {
      return 'Eating Out';
    } else if (desc.contains('AMZN') ||
        desc.contains('COSTCO WHOLESALE') ||
        desc.contains('CANADIAN TIRE')) {
      return 'Shopping';
    } else if (desc.contains('Patreon') || desc.contains('NAMESILOLLC')) {
      return 'Saeid';
    } else if (desc.contains('NETFLIX') ||
        desc.contains('SPOTIFY') ||
        desc.contains('DISNEY') ||
        desc.contains('PRIME') ||
        desc.contains('CANADALAND') ||
        desc.contains('GOOGLE')) {
      return 'Entertainment';
    } else if (desc.contains('WEALTHSIMPLE TAX')) {
      return 'Tax';
    } else if (desc.contains('GOUV') || desc.contains('GOVERNMENT')) {
      return 'Tax Refund';
    }

    return 'Other';
  }
}
