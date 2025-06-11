import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:expense_tracker/services/rbc_import_service.dart';
import 'package:expense_tracker/services/bmo_import_service.dart';
import 'package:expense_tracker/services/td_import_service.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/screens/category_mapping_screen.dart';

class ImportScreen extends StatefulWidget {
  final String? initialSource;

  const ImportScreen({super.key, this.initialSource});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  String? _selectedSource;
  final List<String> _importSources = [
    'Expense Tracker',
    'RBC Bank',
    'BMO Bank',
    'TD Bank'
  ];
  bool _isImporting = false;
  String? _errorMessage;
  int _importedCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.initialSource;
  }

  Future<void> _importFile() async {
    if (_selectedSource == null) {
      setState(() {
        _errorMessage = 'Please select an import source';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
      _importedCount = 0;
    });

    try {
      final typeGroup = _selectedSource == 'RBC Bank' ||
              _selectedSource == 'BMO Bank' ||
              _selectedSource == 'TD Bank'
          ? const XTypeGroup(
              label: 'CSV Files',
              extensions: ['csv'],
            )
          : const XTypeGroup(
              label: 'Excel Files',
              extensions: ['xlsx', 'xls'],
            );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final filePath = file.path;

      final fileObj = File(filePath);
      List<Transaction> importedTransactions = [];

      if (_selectedSource == 'RBC Bank') {
        final rbcService = RBCImportService(_db);
        final result = await rbcService.importFromCSV(file);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import completed:\n'
              '✓ ${result.processedCount} transactions processed\n'
              '⚠ ${result.skippedCount} transactions skipped\n'
              '✗ ${result.errorCount} errors',
            ),
            duration: const Duration(seconds: 5),
          ),
        );

        setState(() {
          _importedCount = result.processedCount;
        });
      } else if (_selectedSource == 'BMO Bank') {
        final bmoService = BMOImportService(_db);
        final result = await bmoService.importFromCSV(file);
        setState(() {
          _importedCount = result.processedCount;
        });
      } else if (_selectedSource == 'TD Bank') {
        final tdService = TDImportService(_db);
        final result = await tdService.importFromCSV(file);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import completed:\n'
              '✓ ${result.processedCount} transactions processed\n'
              '⚠ ${result.skippedCount} transactions skipped\n'
              '✗ ${result.errorCount} errors',
            ),
            duration: const Duration(seconds: 5),
          ),
        );

        setState(() {
          _importedCount = result.processedCount;
        });
      } else {
        // Handle Expense Tracker Excel import
        final bytes = await fileObj.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.sheets.values.first;

        // Skip header row
        for (var i = 1; i < sheet.maxRows; i++) {
          final row = sheet.row(i);
          if (row.isEmpty) continue;

          try {
            final date = DateTime.parse(row[0]?.value.toString() ?? '');
            final category = row[1]?.value.toString() ?? '';
            final amount = double.parse(row[2]?.value.toString() ?? '0');
            final isExpense = row[3]?.value.toString() == 'Expense';
            final note = row[4]?.value.toString();

            final transaction = Transaction(
              amount: amount,
              category: category,
              date: date,
              isExpense: isExpense,
              note: note,
            );

            try {
              await _db.insertTransaction(transaction);
              importedTransactions.add(transaction);
            } on DuplicateTransactionException catch (e) {
              // Skip duplicate transactions during import
              continue;
            }
          } catch (e) {
            // Skip invalid rows
            continue;
          }
        }
      }

      setState(() {
        _importedCount = importedTransactions.length;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $_importedCount transactions'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSource,
              decoration: const InputDecoration(
                labelText: 'Import Source',
                border: OutlineInputBorder(),
              ),
              items: _importSources.map((source) {
                return DropdownMenuItem(
                  value: source,
                  child: Text(source),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSource = value;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedSource == 'RBC Bank')
              Column(
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RBC Bank Import',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Select your RBC bank statement CSV file\n'
                            '• Transactions will be automatically categorized based on their descriptions\n'
                            '• Any uncategorized transactions will be in the "other" category\n'
                            '• Transfers will be ignored\n',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryMappingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Manage Category Mappings'),
                  ),
                ],
              ),
            if (_selectedSource == 'BMO Bank')
              Column(
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMO Bank Import',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Select your BMO bank statement CSV file\n'
                            '• Transactions will be automatically categorized based on their descriptions\n'
                            '• Any uncategorized transactions will be in the "other" category\n'
                            '• Transfers and Interac payments will be ignored\n',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryMappingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Manage Category Mappings'),
                  ),
                ],
              ),
            if (_selectedSource == 'TD Bank')
              Column(
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TD Bank Import',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Select your TD bank statement CSV file\n'
                            '• Transactions will be automatically categorized based on their descriptions\n'
                            '• Any uncategorized transactions will be in the "other" category\n'
                            '• Transfers and TD Easy Transfer payments will be ignored\n',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryMappingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Manage Category Mappings'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isImporting ? null : _importFile,
              child: _isImporting
                  ? const CircularProgressIndicator()
                  : const Text('Select File'),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_importedCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Imported $_importedCount transactions',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
