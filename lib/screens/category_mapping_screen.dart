import 'package:flutter/material.dart';
import 'package:expense_tracker/models/category_mapping.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:expense_tracker/utils/constants.dart';
import '../widgets/category_selection_dialog.dart';
import '../widgets/app_drawer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';

class CategoryMappingScreen extends StatefulWidget {
  const CategoryMappingScreen({super.key});

  @override
  State<CategoryMappingScreen> createState() => _CategoryMappingScreenState();
}

class _CategoryMappingScreenState extends State<CategoryMappingScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<CategoryMapping> _mappings = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _keywordController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadMappings();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadMappings() async {
    try {
      final mappings = await _db.getCategoryMappings();
      setState(() {
        _mappings = mappings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading mappings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _addMapping() async {
    if (_keywordController.text.isEmpty || _selectedCategory == null) {
      return;
    }

    final keyword = _keywordController.text;
    final category = _selectedCategory!;

    final mapping = CategoryMapping(description: keyword, category: category);
    await _db.insertCategoryMapping(mapping);

    _keywordController.clear();
    setState(() {
      _selectedCategory = null;
    });
    _loadMappings();
  }

  Future<void> _deleteMapping(String description) async {
    final mapping = await _db.getCategoryMappingByDescription(description);
    if (mapping != null) {
      await _db.deleteCategoryMapping(mapping.id!);
    }
    _loadMappings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Mapping'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: AppDrawer(
        onExport: () async {
          try {
            final transactions =
                await DatabaseHelper.instance.getTransactions();
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

            // Get the temporary directory
            final directory = await getTemporaryDirectory();
            final filePath = '${directory.path}/expense_tracker_export.xlsx';

            // Save the file
            final fileBytes = excel.encode();
            if (fileBytes != null) {
              final file = File(filePath);
              await file.writeAsBytes(fileBytes);

              // Share the file
              await Share.shareXFiles([XFile(filePath)]);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error exporting data: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _keywordController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => CategorySelectionDialog(
                                    isExpense: true,
                                    selectedCategory: _selectedCategory,
                                    onCategorySelected: (category) {
                                      setState(() {
                                        _selectedCategory = category;
                                      });
                                    },
                                  ),
                                );
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.arrow_drop_down),
                                ),
                                child: Row(
                                  children: [
                                    if (_selectedCategory != null) ...[
                                      Icon(
                                        Constants.expenseCategoryIcons[
                                            _selectedCategory],
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                        _selectedCategory ?? 'Cat.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _addMapping,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _mappings.length,
                        itemBuilder: (context, index) {
                          final mapping = _mappings[index];
                          return ListTile(
                            title: Text(mapping.description),
                            subtitle: Text(mapping.category),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  _deleteMapping(mapping.description),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
