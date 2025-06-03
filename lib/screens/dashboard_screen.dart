import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'category_management_screen.dart';
import '../widgets/month_selector.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'import_screen.dart';
import '../widgets/category_grid.dart';
import '../widgets/category_selection_dialog.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isExpense = true;
  bool _isRecurring = false;
  String _selectedFrequency = 'weekly';
  String _selectedCategory = Constants.expenseCategories.first;
  DateTime _selectedDate = DateTime.now();
  List<Transaction> _transactions = [];
  List<Transaction> _scheduledTransactions = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  Map<String, double> _categorySpending = {};
  List<Budget> _budgets = [];
  double _totalBudget = 0;
  double _totalSpent = 0;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedCategory = Constants.expenseCategories.first;
    _loadData();
    // Check for recurring transactions when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRecurringTransactions();
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTransactions(),
      _loadBudgets(),
      _loadScheduledTransactions(),
    ]);
  }

  Future<void> _loadTransactions() async {
    final transactions =
        await DatabaseHelper.instance.getTransactionsForMonth(_selectedMonth);
    double income = 0;
    double expense = 0;
    final Map<String, double> spending = {};

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        expense += transaction.amount;
        final category = transaction.category;
        spending[category] = (spending[category] ?? 0) + transaction.amount;
      } else {
        income += transaction.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _totalIncome = income;
      _totalExpense = expense;
      _categorySpending = spending;
    });
    _calculateSpending();
  }

  Future<void> _loadBudgets() async {
    final budgets =
        await DatabaseHelper.instance.getBudgetsForMonth(_selectedMonth);
    setState(() {
      _budgets = budgets.where((budget) => budget.category == null).toList();
      _totalBudget = _budgets.fold(0, (sum, budget) => sum + budget.amount);
    });
    _calculateSpending();
  }

  Future<void> _loadScheduledTransactions() async {
    print('Loading scheduled transactions...');
    final transactions =
        await DatabaseHelper.instance.getScheduledTransactions();
    print('Found ${transactions.length} scheduled transactions');
    setState(() {
      _scheduledTransactions = transactions;
    });
  }

  Future<void> _checkRecurringTransactions() async {
    print('Manually checking recurring transactions...');
    final createdTransactions =
        await DatabaseHelper.instance.checkAndCreateRecurringTransactions();
    print('Created ${createdTransactions.length} new transactions');

    if (createdTransactions.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Created ${createdTransactions.length} new recurring transaction(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    // Reload all data
    await _loadData();
  }

  void _calculateSpending() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    _totalSpent = _transactions
        .where((t) =>
            t.isExpense &&
            t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .fold(0, (sum, t) => sum + t.amount);
  }

  Future<void> _navigateToCategoryManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryManagementScreen(),
      ),
    );
    // Refresh the screen when returning from category management
    setState(() {
      _selectedCategory = _isExpense
          ? Constants.expenseCategories.first
          : Constants.incomeCategories.first;
    });
  }

  Future<void> _checkBudgetSurpassed(double amount) async {
    final budgets = await DatabaseHelper.instance.getBudgets();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    for (var budget in budgets) {
      if (budget.startDate.isBefore(endOfMonth) &&
          budget.endDate.isAfter(startOfMonth)) {
        double spent = 0;
        if (budget.category == null) {
          // Overall budget
          spent =
              _categorySpending.values.fold(0.0, (sum, amount) => sum + amount);
        } else {
          // Category-specific budget
          spent = _categorySpending[budget.category!] ?? 0;
        }

        if (spent > budget.amount && !budget.hasSurpassed) {
          if (!mounted) return;

          final shouldMark = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Budget Surpassed'),
              content: Text(
                'You have exceeded your ${budget.category ?? 'overall'} budget of \$${budget.amount.toStringAsFixed(2)}.\n\nCurrent spending: \$${spent.toStringAsFixed(2)}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('OK'),
                ),
              ],
            ),
          );

          if (shouldMark == true && mounted) {
            await DatabaseHelper.instance.markBudgetAsSurpassed(budget.id!);
          }
        }
      }
    }
  }

  Future<void> _cancelScheduledTransaction(Transaction transaction,
      {bool cancelAll = false}) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cancelAll
            ? 'Cancel All Scheduled Transactions'
            : 'Cancel Scheduled Transaction'),
        content: Text(
          cancelAll
              ? 'Are you sure you want to cancel all scheduled ${transaction.isExpense ? "expenses" : "incomes"} of \$${transaction.amount.toStringAsFixed(2)} for ${transaction.category}?'
              : 'Are you sure you want to cancel the scheduled ${transaction.isExpense ? "expense" : "income"} of \$${transaction.amount.toStringAsFixed(2)} for ${transaction.category}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      if (cancelAll) {
        // Delete all recurring transactions with the same category, amount, and expense type
        final db = await DatabaseHelper.instance.database;
        await db.delete(
          'transactions',
          where:
              'category = ? AND amount = ? AND isExpense = ? AND isRecurring = ?',
          whereArgs: [
            transaction.category,
            transaction.amount,
            transaction.isExpense ? 1 : 0,
            1
          ],
        );
      } else {
        // Delete only the original recurring transaction
        await DatabaseHelper.instance.deleteTransaction(transaction.id!);
      }

      await _loadScheduledTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cancelAll
                ? 'All scheduled transactions cancelled'
                : 'Scheduled transaction cancelled'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editScheduledTransaction(Transaction transaction) async {
    final Map<String, dynamic> editResult = {};
    final noteController = TextEditingController(text: transaction.note);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Scheduled Transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: transaction.amount.toString(),
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onSaved: (value) => editResult['amount'] = double.parse(value!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => CategorySelectionDialog(
                      isExpense: _isExpense,
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
                      Icon(
                        _isExpense
                            ? Constants.expenseCategoryIcons[_selectedCategory]
                            : Constants.incomeCategoryIcons[_selectedCategory],
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_selectedCategory ?? 'Select Category'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: transaction.frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (value) => editResult['frequency'] = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'Add a note to this transaction',
                ),
                maxLines: 2,
                onChanged: (value) => editResult['note'] = value,
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
              editResult['note'] =
                  noteController.text.isEmpty ? null : noteController.text;
              Navigator.pop(context, editResult);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedTransaction = Transaction(
        id: transaction.id,
        amount: result['amount'] ?? transaction.amount,
        category: result['category'] ?? transaction.category,
        note: result['note'],
        date: transaction.date,
        isExpense: transaction.isExpense,
        isRecurring: 1,
        frequency: result['frequency'] ?? transaction.frequency,
        nextOccurrence: transaction.nextOccurrence,
      );

      await DatabaseHelper.instance.updateTransaction(updatedTransaction);
      await _loadScheduledTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheduled transaction updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildGaugeChart() {
    if (_totalBudget == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No budget set for this month'),
          ),
        ),
      );
    }

    final percentage = (_totalSpent / _totalBudget) * 100;
    final remaining = _totalBudget - _totalSpent;
    final color = percentage <= 50
        ? Colors.green
        : percentage <= 80
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Budget Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[800],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  // Progress arc
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      strokeWidth: 20,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          NumberFormat.currency(symbol: '\$').format(remaining),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBudgetInfo(
                  'Total Budget',
                  _totalBudget,
                  Colors.blue,
                ),
                _buildBudgetInfo(
                  'Spent',
                  _totalSpent,
                  color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetInfo(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          NumberFormat.currency(symbol: '\$').format(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Transaction',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Expense'),
                    icon: Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Income'),
                    icon: Icon(Icons.add),
                  ),
                ],
                selected: {_isExpense},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isExpense = newSelection.first;
                    _selectedCategory = _isExpense
                        ? Constants.expenseCategories.first
                        : Constants.incomeCategories.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => CategorySelectionDialog(
                      isExpense: _isExpense,
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
                      Icon(
                        _isExpense
                            ? Constants.expenseCategoryIcons[_selectedCategory]
                            : Constants.incomeCategoryIcons[_selectedCategory],
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_selectedCategory ?? 'Select Category'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Recurring Transaction'),
                value: _isRecurring,
                onChanged: (value) {
                  setState(() {
                    _isRecurring = value;
                  });
                },
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Weekly'),
                    ),
                    DropdownMenuItem(
                      value: 'biweekly',
                      child: Text('Bi-weekly'),
                    ),
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text('Monthly'),
                    ),
                    DropdownMenuItem(
                      value: 'yearly',
                      child: Text('Yearly'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFrequency = value;
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: _isRecurring ? DateTime(2100) : DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Theme.of(context).primaryColor,
                            onPrimary: Colors.white,
                            surface: Theme.of(context).cardColor,
                            onSurface:
                                Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.black,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final transaction = Transaction(
                      amount: double.parse(_amountController.text),
                      category: _selectedCategory,
                      note: _noteController.text.isEmpty
                          ? null
                          : _noteController.text,
                      date: _selectedDate,
                      isExpense: _isExpense,
                      isRecurring: _isRecurring ? 1 : 0,
                      frequency: _isRecurring ? _selectedFrequency : null,
                    );

                    try {
                      await DatabaseHelper.instance.insertTransaction(transaction);
                      _amountController.clear();
                      _noteController.clear();
                      await _loadData();

                      // Check if any budgets are surpassed after adding the transaction
                      if (_isExpense) {
                        await _checkBudgetSurpassed(transaction.amount);
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_isExpense ? "Expense" : "Income"} of \$${transaction.amount.toStringAsFixed(2)} added successfully',
                            ),
                            backgroundColor:
                                _isExpense ? Colors.red : Colors.green,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    } on DuplicateTransactionException catch (e) {
                      if (mounted) {
                        final shouldProceed = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Duplicate Transaction'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A transaction with the same amount (${transaction.amount.toStringAsFixed(2)}) exists on ${DateFormat('MMM d, y').format(transaction.date)}.',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Found ${e.duplicates.length} similar transaction${e.duplicates.length > 1 ? 's' : ''}:',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...e.duplicates.map((t) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• ${t.category} - ${DateFormat.yMMMd().format(t.date)}${t.note != null ? ' (${t.note})' : ''}',
                                      ),
                                    )),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, 'cancel'),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'edit'),
                                child: const Text('Edit Original'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'add'),
                                child: const Text('Add Anyway'),
                              ),
                            ],
                          ),
                        );

                        if (shouldProceed == 'add') {
                          // Force insert the transaction
                          final db = await DatabaseHelper.instance.database;
                          await db.insert('transactions', transaction.toMap());
                          _amountController.clear();
                          _noteController.clear();
                          await _loadData();
                        } else if (shouldProceed == 'edit' &&
                            e.duplicates.isNotEmpty) {
                          // Edit the first duplicate transaction
                          final originalTransaction = e.duplicates.first;
                          await _editTransaction(originalTransaction);
                        }
                      }
                    }
                  }
                },
                child: const Text('Save Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTransaction(Transaction transaction) async {
    _amountController.text = transaction.amount.toString();
    _noteController.text = transaction.note ?? '';
    _selectedCategory = transaction.category;
    _selectedDate = transaction.date;
    _isExpense = transaction.isExpense;
    _isRecurring = transaction.isRecurring == 1;
    _selectedFrequency = transaction.frequency ?? 'weekly';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => CategorySelectionDialog(
                        isExpense: _isExpense,
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
                        Icon(
                          _isExpense
                              ? Constants
                                  .expenseCategoryIcons[_selectedCategory]
                              : Constants
                                  .incomeCategoryIcons[_selectedCategory],
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(_selectedCategory),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Expense'),
                      icon: Icon(Icons.remove),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Income'),
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
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Recurring Transaction'),
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value;
                      if (!value) {
                        _selectedFrequency = 'weekly';
                      }
                    });
                  },
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: 'biweekly',
                        child: Text('Bi-weekly'),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: 'yearly',
                        child: Text('Yearly'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFrequency = value;
                        });
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_amountController.text.isNotEmpty &&
                    double.tryParse(_amountController.text) != null) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final updatedTransaction = Transaction(
        id: transaction.id,
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        date: _selectedDate,
        isExpense: _isExpense,
        isRecurring: _isRecurring ? 1 : 0,
        frequency: _isRecurring ? _selectedFrequency : null,
      );

      await DatabaseHelper.instance.updateTransaction(updatedTransaction);
      await _loadData();
    }
  }

  Widget _buildScheduledTransactions() {
    // Group transactions by category and amount
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in _scheduledTransactions) {
      final key =
          '${transaction.category}_${transaction.amount}_${transaction.isExpense}';
      if (!groupedTransactions.containsKey(key)) {
        groupedTransactions[key] = [];
      }
      groupedTransactions[key]!.add(transaction);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scheduled Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    // Show loading indicator
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checking for new transactions...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }

                    // Check for new recurring transactions
                    await _checkRecurringTransactions();

                    // Refresh the list
                    await _loadScheduledTransactions();
                  },
                  tooltip: 'Refresh & Check',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_scheduledTransactions.isEmpty)
              const Center(
                child: Text('No scheduled transactions'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupedTransactions.length,
                itemBuilder: (context, index) {
                  final key = groupedTransactions.keys.elementAt(index);
                  final transactions = groupedTransactions[key]!;
                  final firstTransaction = transactions.first;

                  // Sort transactions by next occurrence
                  transactions.sort((a, b) => DateTime.parse(a.nextOccurrence!)
                      .compareTo(DateTime.parse(b.nextOccurrence!)));

                  return ExpansionTile(
                    leading: Icon(
                      firstTransaction.isExpense
                          ? Constants
                              .expenseCategoryIcons[firstTransaction.category]
                          : Constants
                              .incomeCategoryIcons[firstTransaction.category],
                      color: firstTransaction.isExpense
                          ? Colors.red
                          : Colors.green,
                    ),
                    title: Text(
                      '${firstTransaction.amount.toStringAsFixed(2)} - ${firstTransaction.category}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${transactions.length} scheduled occurrence${transactions.length > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (firstTransaction.note != null &&
                            firstTransaction.note!.isNotEmpty)
                          Text(
                            firstTransaction.note!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _editScheduledTransaction(firstTransaction),
                          tooltip: 'Edit All',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _cancelScheduledTransaction(
                              firstTransaction,
                              cancelAll: true),
                          tooltip: 'Cancel All',
                        ),
                      ],
                    ),
                    children: transactions.map((transaction) {
                      return ListTile(
                        title: Text(
                          'Next: ${DateFormat.yMMMd().format(DateTime.parse(transaction.nextOccurrence!))}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Frequency: ${transaction.frequency?.capitalize()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (transaction.note != null &&
                                transaction.note!.isNotEmpty)
                              Text(
                                transaction.note!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () =>
                                  _editScheduledTransaction(transaction),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () =>
                                  _cancelScheduledTransaction(transaction),
                              tooltip: 'Cancel',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.batch_prediction),
          onPressed: _navigateToCategoryManagement,
          tooltip: 'Category Manager',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportScreen()),
              );
            },
            tooltip: 'Import Data',
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _exportData,
            tooltip: 'Export Data',
          ),
        ],
      ),
      body: Column(
        children: [
          MonthSelector(
            selectedMonth: _selectedMonth,
            onMonthChanged: (month) {
              setState(() {
                _selectedMonth = month;
              });
              _loadData();
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Income',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '\$${_totalIncome.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.green,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Expenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '\$${_totalExpense.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGaugeChart(),
                  const SizedBox(height: 16),
                  _buildTransactionForm(),
                  const SizedBox(height: 16),
                  _buildScheduledTransactions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    try {
      final transactions = await DatabaseHelper.instance.getTransactions();
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
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Expense Tracker Export',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 