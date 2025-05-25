import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'category_management_screen.dart';
import '../widgets/month_selector.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

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
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedCategory = Constants.expenseCategories.first;
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTransactions(),
      _loadBudgets(),
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

                    await DatabaseHelper.instance
                        .insertTransaction(transaction);
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

  Widget _buildRecentTransactions() {
    // Get only the last 5 transactions
    final recentTransactions = _transactions.take(5).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (recentTransactions.isEmpty)
              const Center(
                child: Text('No recent transactions'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = recentTransactions[index];
                  return ListTile(
                    title: Text(
                      '${transaction.amount.toStringAsFixed(2)} - ${transaction.category}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    subtitle: Text(
                      DateFormat.yMMMd().format(transaction.date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.batch_prediction),
            tooltip: 'Manage Categories',
            onPressed: _navigateToCategoryManagement,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Import from Excel',
            onPressed: _importFromExcel,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Export to Excel',
            onPressed: _exportToExcel,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGaugeChart(),
                  const SizedBox(height: 16),
                  _buildTransactionForm(),
                  const SizedBox(height: 16),
                  _buildRecentTransactions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get all transactions and budgets
      final transactions = await DatabaseHelper.instance.getAllTransactions();
      final budgets = await DatabaseHelper.instance.getBudgets();

      // Create Excel file
      var excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // Create named sheets
      var transactionsSheet = excel['Transactions'];
      var budgetsSheet = excel['Budgets'];

      // Add headers for transactions
      transactionsSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Type'),
        TextCellValue('Note'),
      ]);

      // Add transaction data
      for (var transaction in transactions) {
        transactionsSheet.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(transaction.date)),
          TextCellValue(transaction.category),
          TextCellValue(transaction.amount.toString()),
          TextCellValue(transaction.isExpense ? 'Expense' : 'Income'),
          TextCellValue(transaction.note ?? ''),
        ]);
      }

      // Add headers for budgets
      budgetsSheet.appendRow([
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Start Date'),
        TextCellValue('End Date'),
        TextCellValue('Has Surpassed'),
      ]);

      // Add budget data
      for (var budget in budgets) {
        budgetsSheet.appendRow([
          TextCellValue(budget.category ?? 'Overall'),
          TextCellValue(budget.amount.toString()),
          TextCellValue(DateFormat('yyyy-MM-dd').format(budget.startDate)),
          TextCellValue(DateFormat('yyyy-MM-dd').format(budget.endDate)),
          TextCellValue(budget.hasSurpassed ? 'Yes' : 'No'),
        ]);
      }

      // Auto-fit columns for transactions
      transactionsSheet.setColumnWidth(0, 15.0); // Date
      transactionsSheet.setColumnWidth(1, 20.0); // Category
      transactionsSheet.setColumnWidth(2, 15.0); // Amount
      transactionsSheet.setColumnWidth(3, 10.0); // Type
      transactionsSheet.setColumnWidth(4, 30.0); // Note

      // Auto-fit columns for budgets
      budgetsSheet.setColumnWidth(0, 20.0); // Category
      budgetsSheet.setColumnWidth(1, 15.0); // Amount
      budgetsSheet.setColumnWidth(2, 15.0); // Start Date
      budgetsSheet.setColumnWidth(3, 15.0); // End Date
      budgetsSheet.setColumnWidth(4, 15.0); // Has Surpassed

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final String fileName =
          'expense_tracker_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final String filePath = '${directory.path}/$fileName';

      // Save file
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Close loading dialog
        Navigator.pop(context);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel file exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Share file
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'My Expense Tracker Export',
        );
      }
    } catch (e) {
      // Close loading dialog if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importFromExcel() async {
    try {
      // Pick Excel file
      const typeGroup = XTypeGroup(
        label: 'Excel',
        extensions: ['xlsx'],
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Read Excel file
      final bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);

      // Remove default Sheet1 if it exists
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Process transactions
      if (!excel.tables.containsKey('Transactions')) {
        throw Exception('Transactions sheet not found in the Excel file');
      }
      var transactionsSheet = excel.tables['Transactions']!;
      List<Transaction> transactions = [];

      // Skip header row and process transaction data
      for (var i = 1; i < transactionsSheet.rows.length; i++) {
        var row = transactionsSheet.rows[i];
        if (row.isEmpty || row[0]?.value == null) continue;

        try {
          final date = DateFormat('yyyy-MM-dd').parse(row[0]!.value.toString());
          final category = row[1]!.value.toString();
          final amount = double.parse(row[2]!.value.toString());
          final isExpense = row[3]!.value.toString().toLowerCase() == 'expense';
          final note = row[4]?.value?.toString();

          // Validate category
          if (!Constants.expenseCategories.contains(category) &&
              !Constants.incomeCategories.contains(category)) {
            continue; // Skip invalid categories
          }

          transactions.add(Transaction(
            amount: amount,
            category: category,
            note: note,
            date: date,
            isExpense: isExpense,
            isRecurring: 0,
          ));
        } catch (e) {
          // Skip invalid rows
          continue;
        }
      }

      // Process budgets
      if (!excel.tables.containsKey('Budgets')) {
        throw Exception('Budgets sheet not found in the Excel file');
      }
      var budgetsSheet = excel.tables['Budgets']!;
      List<Budget> budgets = [];

      // Skip header row and process budget data
      for (var i = 1; i < budgetsSheet.rows.length; i++) {
        var row = budgetsSheet.rows[i];
        if (row.isEmpty || row[0]?.value == null) continue;

        try {
          final category = row[0]!.value.toString();
          final amount = double.parse(row[1]!.value.toString());
          final startDate =
              DateFormat('yyyy-MM-dd').parse(row[2]!.value.toString());
          final endDate =
              DateFormat('yyyy-MM-dd').parse(row[3]!.value.toString());
          final hasSurpassed = row[4]!.value.toString().toLowerCase() == 'yes';

          // Validate category if not overall budget
          if (category != 'Overall' &&
              !Constants.expenseCategories.contains(category)) {
            continue; // Skip invalid categories
          }

          budgets.add(Budget(
            amount: amount,
            category: category == 'Overall' ? null : category,
            startDate: startDate,
            endDate: endDate,
            hasSurpassed: hasSurpassed,
          ));
        } catch (e) {
          // Skip invalid rows
          continue;
        }
      }

      // Insert transactions and budgets
      for (var transaction in transactions) {
        await DatabaseHelper.instance.insertTransaction(transaction);
      }

      for (var budget in budgets) {
        await DatabaseHelper.instance.insertBudget(budget);
      }

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully imported ${transactions.length} transactions and ${budgets.length} budgets'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh data
      await _loadData();
    } catch (e) {
      // Close loading dialog if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
} 