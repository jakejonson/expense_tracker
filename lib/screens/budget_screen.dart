import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  List<Budget> _budgets = [];
  Map<String, double> _currentSpending = {};

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final budgets = await DatabaseHelper.instance.getBudgets();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final transactions = await DatabaseHelper.instance
        .getTransactionsByDateRange(startOfMonth, now);

    final spending = <String, double>{};
    for (var transaction in transactions) {
      if (transaction.isExpense) {
        spending[transaction.category] =
            (spending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    setState(() {
      _budgets = budgets;
      _currentSpending = spending;
    });

    // Check for budget alerts
    for (var budget in budgets) {
      final categorySpending = spending[budget.category ?? 'overall'] ?? 0;
      if (categorySpending > budget.amount) {
        _showBudgetAlert(budget, categorySpending);
      }
    }
  }

  Future<void> _showBudgetAlert(Budget budget, double spending) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications for budget alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Budget Alert',
      'Your ${budget.category ?? 'overall'} spending (\$${spending.toStringAsFixed(2)}) '
          'has exceeded the budget of \$${budget.amount.toStringAsFixed(2)}',
      platformChannelSpecifics,
    );
  }

  void _showAddBudgetModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set Budget',
                style: Theme.of(context).textTheme.titleLarge,
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
              DropdownButtonFormField<String?>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Overall Budget'),
                  ),
                  ...Constants.categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveBudget,
                child: const Text('Save Budget'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final budget = Budget(
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      );

      await DatabaseHelper.instance.insertBudget(budget);
      _amountController.clear();
      _selectedCategory = null;
      if (mounted) {
        Navigator.pop(context);
        _loadBudgets();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
      ),
      body: ListView.builder(
        itemCount: _budgets.length,
        itemBuilder: (context, index) {
          final budget = _budgets[index];
          final spending = _currentSpending[budget.category ?? 'overall'] ?? 0;
          final progress = spending / budget.amount;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: progress >= 1 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1 ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spent: ${NumberFormat.currency(symbol: '\$').format(spending)} '
                    'of ${NumberFormat.currency(symbol: '\$').format(budget.amount)}',
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBudgetModal,
        label: const Text('Set Budget'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
} 