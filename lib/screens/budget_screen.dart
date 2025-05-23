import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/budget.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'budget_details_screen.dart';
import '../widgets/month_selector.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Budget> _budgets = [];
  Map<String, double> _categorySpending = {};
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final budgets =
        await DatabaseHelper.instance.getBudgetsForMonth(_selectedMonth);
    final spending = await DatabaseHelper.instance
        .getCategorySpendingForMonth(_selectedMonth);

    setState(() {
      _budgets = budgets;
      _categorySpending = spending;
    });
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadBudgets();
  }

  double _getBudgetProgress(Budget budget) {
    if (budget.category == null) {
      // Overall budget
      final totalSpent = _categorySpending.values
          .fold<double>(0.0, (sum, amount) => sum + (amount as double));
      return totalSpent / budget.amount;
    }
    // Category-specific budget
    final spent = _categorySpending[budget.category!] ?? 0;
    return spent / budget.amount;
  }

  Future<DateTime?> _showMonthPicker(
      BuildContext context, DateTime initialDate) async {
    final now = DateTime.now();
    final firstDate = DateTime(2000);
    final lastDate = DateTime(now.year + 1, 12, 31);

    return showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Year selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      Navigator.pop(context,
                          DateTime(initialDate.year - 1, initialDate.month, 1));
                    },
                  ),
                  Text(
                    initialDate.year.toString(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      Navigator.pop(context,
                          DateTime(initialDate.year + 1, initialDate.month, 1));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Month grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == initialDate.month;
                  final isEnabled = DateTime(initialDate.year, month, 1)
                          .isAfter(
                              firstDate.subtract(const Duration(days: 1))) &&
                      DateTime(initialDate.year, month, 1)
                          .isBefore(lastDate.add(const Duration(days: 1)));

                  return InkWell(
                    onTap: isEnabled
                        ? () {
                            Navigator.pop(
                                context, DateTime(initialDate.year, month, 1));
                          }
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Theme.of(context).primaryColor : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM').format(DateTime(2000, month, 1)),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isEnabled
                                    ? null
                                    : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
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
        ],
      ),
    );
  }

  Future<void> _showAddBudgetDialog() async {
    final amountController = TextEditingController();
    String? selectedCategory;
    DateTime selectedMonth = DateTime.now();

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
                  labelText: 'Monthly Budget Amount',
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
                title: const Text('Month'),
                subtitle: Text(
                  DateFormat.yMMMM().format(selectedMonth),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await _showMonthPicker(context, selectedMonth);
                  if (picked != null) {
                    selectedMonth = picked;
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
                final startDate =
                    DateTime(selectedMonth.year, selectedMonth.month, 1);
                final endDate =
                    DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
                Navigator.pop(context, {
                  'amount': double.parse(amountController.text),
                  'category': selectedCategory,
                  'startDate': startDate.toIso8601String(),
                  'endDate': endDate.toIso8601String(),
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
              'Monthly budget of \$${budget.amount.toStringAsFixed(2)} added successfully',
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
              'Budget updated to \$${updatedBudget.amount.toStringAsFixed(2)}',
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

  Future<void> _showCopyBudgetDialog() async {
    // Get all months that have budgets
    final allBudgets = await DatabaseHelper.instance.getAllBudgets();
    final monthsWithBudgets = <DateTime>{};

    for (var budget in allBudgets) {
      final month = DateTime(budget.startDate.year, budget.startDate.month, 1);
      monthsWithBudgets.add(month);
    }

    if (!mounted) return;

    // Show month selection dialog
    final selectedMonth = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: monthsWithBudgets.length,
            itemBuilder: (context, index) {
              final month = monthsWithBudgets.elementAt(index);
              return ListTile(
                title: Text(DateFormat.yMMMM().format(month)),
                onTap: () => Navigator.pop(context, month),
              );
            },
          ),
        ),
      ),
    );

    if (selectedMonth == null || !mounted) return;

    // Get budgets for selected month
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final monthBudgets = allBudgets
        .where((budget) =>
            budget.startDate
                .isBefore(endOfMonth.add(const Duration(days: 1))) &&
            budget.endDate
                .isAfter(startOfMonth.subtract(const Duration(days: 1))))
        .toList();

    if (!mounted) return;

    // Show budget selection dialog
    final selectedBudget = await showDialog<Budget>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Select Budget from ${DateFormat.yMMMM().format(selectedMonth)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: monthBudgets.length,
            itemBuilder: (context, index) {
              final budget = monthBudgets[index];
              return ListTile(
                title: Text(budget.category ?? 'Overall Budget'),
                subtitle: Text('\$${budget.amount.toStringAsFixed(2)}'),
                onTap: () => Navigator.pop(context, budget),
              );
            },
          ),
        ),
      ),
    );

    if (selectedBudget == null || !mounted) return;

    // Create new budget for current month
    final now = DateTime.now();
    final startOfCurrentMonth = DateTime(now.year, now.month, 1);
    final endOfCurrentMonth = DateTime(now.year, now.month + 1, 0);

    final newBudget = Budget(
      amount: selectedBudget.amount,
      category: selectedBudget.category,
      startDate: startOfCurrentMonth,
      endDate: endOfCurrentMonth,
      hasSurpassed: false,
    );

    await DatabaseHelper.instance.insertBudget(newBudget);
    await _loadBudgets();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget copied successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Budget from Previous Month',
            onPressed: _showCopyBudgetDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          MonthSelector(
            selectedMonth: _selectedMonth,
            onMonthChanged: _onMonthChanged,
          ),
          Expanded(
            child: _budgets.isEmpty
                ? const Center(
                    child: Text('No budgets set for this month'),
                  )
                : ListView.builder(
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      final budget = _budgets[index];
                      final progress = _getBudgetProgress(budget);
                      final spent = budget.category == null
                          ? _categorySpending.values.fold<double>(
                              0.0, (sum, amount) => sum + (amount as double))
                          : _categorySpending[budget.category!] ?? 0;

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    BudgetDetailsScreen(budget: budget),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      budget.category ?? 'Overall Budget',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editBudget(budget),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              _deleteBudget(budget),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Spent: \$${spent.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: progress > 1.0
                                            ? Colors.red
                                            : Colors.green,
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 