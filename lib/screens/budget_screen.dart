import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/budget.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Budget> _budgets = [];
  Map<String, double> _categorySpending = {};

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final budgets = await DatabaseHelper.instance.getBudgets();
    final transactions = await DatabaseHelper.instance.getTransactions();
    final Map<String, double> spending = {};

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        final category = transaction.category;
        spending[category] = (spending[category] ?? 0) + transaction.amount;
      }
    }

    setState(() {
      _budgets = budgets;
      _categorySpending = spending;
    });
  }

  double _getBudgetProgress(Budget budget) {
    if (budget.category == null) {
      // Overall budget
      final totalSpent =
          _categorySpending.values.fold(0.0, (sum, amount) => sum + amount);
      return totalSpent / budget.amount;
    }
    // Category-specific budget
    final spent = _categorySpending[budget.category!] ?? 0;
    return spent / budget.amount;
  }

  Future<void> _showAddBudgetDialog() async {
    final amountController = TextEditingController();
    String? selectedCategory;
    DateTimeRange selectedDateRange = DateTimeRange(
      start: DateTime.now(),
      end: DateTime.now().add(const Duration(days: 30)),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Budget'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Budget Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Overall Budget'),
                  ),
                  ...Constants.expenseCategories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: (value) {
                  selectedCategory = value;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date Range'),
                subtitle: Text(
                  '${DateFormat.yMMMd().format(selectedDateRange.start)} - ${DateFormat.yMMMd().format(selectedDateRange.end)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: selectedDateRange,
                  );
                  if (picked != null) {
                    selectedDateRange = picked;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'amount': double.parse(amountController.text),
                  'category': selectedCategory,
                  'startDate': selectedDateRange.start.toIso8601String(),
                  'endDate': selectedDateRange.end.toIso8601String(),
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final budget = Budget(
        amount: result['amount'],
        category: result['category'],
        startDate: DateTime.parse(result['startDate']),
        endDate: DateTime.parse(result['endDate']),
      );

      await DatabaseHelper.instance.insertBudget(budget);
      _loadBudgets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Budget of \$${budget.amount.toStringAsFixed(2)} added successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _editBudget(Budget budget) async {
    final amountController = TextEditingController(
      text: budget.amount.toString(),
    );
    String? selectedCategory = budget.category;
    DateTimeRange selectedDateRange = DateTimeRange(
      start: budget.startDate,
      end: budget.endDate,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Budget for ${budget.category ?? 'Overall'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Budget Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Overall Budget'),
                  ),
                  ...Constants.expenseCategories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: (value) {
                  selectedCategory = value;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date Range'),
                subtitle: Text(
                  '${DateFormat.yMMMd().format(selectedDateRange.start)} - ${DateFormat.yMMMd().format(selectedDateRange.end)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: selectedDateRange,
                  );
                  if (picked != null) {
                    selectedDateRange = picked;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'id': budget.id,
                  'amount': double.parse(amountController.text),
                  'category': selectedCategory,
                  'startDate': selectedDateRange.start.toIso8601String(),
                  'endDate': selectedDateRange.end.toIso8601String(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedBudget = Budget(
        id: result['id'],
        amount: result['amount'],
        category: result['category'],
        startDate: DateTime.parse(result['startDate']),
        endDate: DateTime.parse(result['endDate']),
      );
      await DatabaseHelper.instance.updateBudget(updatedBudget);
      _loadBudgets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Budget updated to \$ ${updatedBudget.amount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text(
          'Are you sure you want to delete the budget for ${budget.category ?? 'Overall'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteBudget(budget.id!);
      _loadBudgets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Budget for ${budget.category ?? 'Overall'} deleted successfully',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
      ),
      body: _budgets.isEmpty
          ? const Center(
              child: Text('No budgets set'),
            )
          : ListView.builder(
              itemCount: _budgets.length,
              itemBuilder: (context, index) {
                final budget = _budgets[index];
                final progress = _getBudgetProgress(budget);
                final spent = budget.category == null
                    ? _categorySpending.values
                        .fold(0.0, (sum, amount) => sum + amount)
                    : _categorySpending[budget.category!] ?? 0;

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              budget.category ?? 'Overall Budget',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editBudget(budget),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteBudget(budget),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 1.0 ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spent: \$${spent.toStringAsFixed(2)}',
                              style: TextStyle(
                                color:
                                    progress > 1.0 ? Colors.red : Colors.green,
                              ),
                            ),
                            Text(
                              'Budget: \$${budget.amount.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat.yMMMd().format(budget.startDate)} - ${DateFormat.yMMMd().format(budget.endDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 