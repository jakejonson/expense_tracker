import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/month_selector.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  Map<String, double> _categorySpending = {};
  double _totalIncome = 0;
  double _totalExpense = 0;

  // Color scheme for categories
  final List<Color> _categoryColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final transactions =
        await DatabaseHelper.instance.getTransactionsForMonth(_selectedMonth);
    final spending = await DatabaseHelper.instance
        .getCategorySpendingForMonth(_selectedMonth);
    
    double income = 0;
    double expense = 0;
    
    for (var transaction in transactions) {
      if (transaction.isExpense) {
        expense += transaction.amount;
      } else {
        income += transaction.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _categorySpending = spending;
      _totalIncome = income;
      _totalExpense = expense;
      _isLoading = false;
    });
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
      key: ValueKey('reports_screen_${_selectedMonth.millisecondsSinceEpoch}'),
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Column(
        children: [
          MonthSelector(
            selectedMonth: _selectedMonth,
            onMonthChanged: _onMonthChanged,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 16),
                        _buildExpensePieChart(),
                        const SizedBox(height: 16),
                        _buildCategoryBreakdown(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Income',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_totalIncome.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Expenses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_totalExpense.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.red,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpensePieChart() {
    if (_categorySpending.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No expense data for this month'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _categorySpending.entries.map((entry) {
                    final percentage = (entry.value / _totalExpense) * 100;
                    final colorIndex =
                        _categorySpending.keys.toList().indexOf(entry.key) %
                            _categoryColors.length;
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      color: _categoryColors[colorIndex],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categorySpending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ..._categorySpending.entries.map((entry) {
              final percentage = (entry.value / _totalExpense) * 100;
              final colorIndex =
                  _categorySpending.keys.toList().indexOf(entry.key) %
                      _categoryColors.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          '\$${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _categoryColors[colorIndex],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
} 