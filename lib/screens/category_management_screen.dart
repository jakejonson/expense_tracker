import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/database_helper.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<String> _expenseCategories = List.from(Constants.expenseCategories);
  List<String> _incomeCategories = List.from(Constants.incomeCategories);
  final _newCategoryController = TextEditingController();
  bool _isExpense = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _expenseCategories = List.from(Constants.expenseCategories);
      _incomeCategories = List.from(Constants.incomeCategories);
    });
  }

  Future<void> _addCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${_isExpense ? "Expense" : "Income"} Category'),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_newCategoryController.text.isNotEmpty) {
                Navigator.pop(context, _newCategoryController.text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      Constants.addCategory(result, _isExpense);
      if (_isExpense) {
        Constants.categoryToSuperCategory[result] =
            'Wants'; // Default to Wants for new categories
      }
      setState(() {
        if (_isExpense) {
          _expenseCategories = List.from(Constants.expenseCategories);
        } else {
          _incomeCategories = List.from(Constants.incomeCategories);
        }
      });
      _newCategoryController.clear();
    }
  }

  Future<void> _changeSuperCategory(String category) async {
    final currentSuperCategory =
        Constants.categoryToSuperCategory[category] ?? 'Wants';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Super Category'),
        content: DropdownButtonFormField<String>(
          value: currentSuperCategory,
          decoration: const InputDecoration(
            labelText: 'Super Category',
            border: OutlineInputBorder(),
          ),
          items: Constants.superCategories.map((superCategory) {
            return DropdownMenuItem(
              value: superCategory,
              child: Text(superCategory),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              Navigator.pop(context, value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        Constants.categoryToSuperCategory[category] = result;
      });
    }
  }

  Future<void> _deleteCategory(String category) async {
    // Check if there are any transactions in this category
    final transactions =
        await DatabaseHelper.instance.getTransactionsByCategory(category);

    if (transactions.isNotEmpty) {
      // Show dialog to select new category
      final newCategory = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select New Category'),
          content: SizedBox(
            width: double.maxFinite,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'New Category',
                border: OutlineInputBorder(),
              ),
              items: (_isExpense ? _expenseCategories : _incomeCategories)
                  .where((c) => c != category)
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (newCategory != null) {
        // Update all transactions in the old category to the new category
        for (var transaction in transactions) {
          await DatabaseHelper.instance.updateTransactionCategory(
            transaction.id!,
            newCategory,
          );
        }
      } else {
        return; // User cancelled
      }
    }

    Constants.removeCategory(category, _isExpense);
    setState(() {
      if (_isExpense) {
        _expenseCategories = List.from(Constants.expenseCategories);
      } else {
        _incomeCategories = List.from(Constants.incomeCategories);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Expense Categories'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Income Categories'),
                  icon: Icon(Icons.add),
                ),
              ],
              selected: {_isExpense},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _isExpense = newSelection.first;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount:
                  (_isExpense ? _expenseCategories : _incomeCategories).length,
              itemBuilder: (context, index) {
                final category = _isExpense
                    ? _expenseCategories[index]
                    : _incomeCategories[index];
                return ListTile(
                  leading: Icon(_isExpense
                      ? Constants.expenseCategoryIcons[category]
                      : Constants.incomeCategoryIcons[category]),
                  title: Text(category),
                  subtitle: _isExpense
                      ? Text(
                          'Super Category: ${Constants.categoryToSuperCategory[category] ?? "Wants"}',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isExpense)
                        IconButton(
                          icon: const Icon(Icons.category),
                          onPressed: () => _changeSuperCategory(category),
                          tooltip: 'Change Super Category',
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteCategory(category),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }
}
