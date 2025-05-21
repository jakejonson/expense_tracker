import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'category_management_screen.dart';

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
  double _totalIncome = 0;
  double _totalExpense = 0;
  Map<String, double> _categorySpending = {};
  List<Budget> _budgets = [];
  double _totalBudget = 0;
  double _totalSpent = 0;
  double _monthlySpending = 0;
  double _monthlyBudget = 0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = Constants.expenseCategories.first;
    _loadTransactions();
    _loadBudgets();
  }

  Future<void> _loadTransactions() async {
    final transactions = await DatabaseHelper.instance.getTransactions();
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
    final budgets = await DatabaseHelper.instance.getBudgets();
    setState(() {
      _budgets = budgets.where((budget) => budget.category == null).toList();
      _totalBudget = _budgets.fold(0, (sum, budget) => sum + budget.amount);
    });
    _calculateSpending();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _navigateToCategoryManagement,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGaugeChart(),
            const SizedBox(height: 16),
            Card(
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
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: (_isExpense
                                ? Constants.expenseCategories
                                : Constants.incomeCategories)
                            .map((category) => DropdownMenuItem(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Icon(Constants.categoryIcons[category]),
                                      const SizedBox(width: 8),
                                      Text(category),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
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
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Theme.of(context).primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Theme.of(context).cardColor,
                                    onSurface: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color ??
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
                              frequency:
                                  _isRecurring ? _selectedFrequency : null,
                            );

                            await DatabaseHelper.instance
                                .insertTransaction(transaction);
                            _amountController.clear();
                            _noteController.clear();
                            _loadTransactions();
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
                          }
                        },
                        child: const Text('Save Transaction'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
} 