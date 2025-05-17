import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Transaction> _transactions = [];
  String _selectedPeriod = 'This Month';
  final List<String> _periods = [
    'This Month',
    'Last Month',
    'This Year',
    'Last Year'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await DatabaseHelper.instance.getTransactions();
    setState(() {
      _transactions = transactions;
    });
  }

  List<Transaction> _getFilteredTransactions() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    switch (_selectedPeriod) {
      case 'This Month':
        return _transactions
            .where((t) =>
                t.date
                    .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
            .toList();
      case 'Last Month':
        return _transactions
            .where((t) =>
                t.date.isAfter(DateTime(now.year, now.month - 1, 1)
                    .subtract(const Duration(days: 1))) &&
                t.date.isBefore(DateTime(now.year, now.month, 0)
                    .add(const Duration(days: 1))))
            .toList();
      case 'This Year':
        return _transactions
            .where((t) =>
                t.date.isAfter(DateTime(now.year, 1, 1)
                    .subtract(const Duration(days: 1))) &&
                t.date.isBefore(
                    DateTime(now.year, 12, 31).add(const Duration(days: 1))))
            .toList();
      case 'Last Year':
        return _transactions
            .where((t) =>
                t.date.isAfter(DateTime(now.year - 1, 1, 1)
                    .subtract(const Duration(days: 1))) &&
                t.date.isBefore(DateTime(now.year - 1, 12, 31)
                    .add(const Duration(days: 1))))
            .toList();
      default:
        return _transactions;
    }
  }

  Map<String, double> _getCategoryTotals(List<Transaction> transactions) {
    final Map<String, double> totals = {};
    for (var transaction in transactions) {
      if (transaction.isExpense) {
        totals[transaction.category] =
            (totals[transaction.category] ?? 0) + transaction.amount;
      }
    }
    return totals;
  }

  Widget _buildPieChart(Map<String, double> categoryTotals) {
    final total =
        categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);
    final List<Color> colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sections: categoryTotals.entries.map((entry) {
            final index = categoryTotals.keys.toList().indexOf(entry.key);
            return PieChartSectionData(
              value: entry.value,
              title: '${((entry.value / total) * 100).toStringAsFixed(1)}%',
              color: colors[index % colors.length],
              radius: 100,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildCategoryList(Map<String, double> categoryTotals) {
    final total =
        categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final entry = sortedCategories[index];
        final percentage = (entry.value / total) * 100;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade400,
            child: Icon(
              _getCategoryIcon(entry.key),
              color: Colors.white,
            ),
          ),
          title: Text(entry.key),
          subtitle: LinearProgressIndicator(
            value: entry.value / total,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.blue.shade400,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(symbol: '\$').format(entry.value),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'entertainment':
        return Icons.movie;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
        return Icons.receipt;
      case 'health':
        return Icons.medical_services;
      case 'education':
        return Icons.school;
      case 'travel':
        return Icons.flight;
      case 'salary':
        return Icons.work;
      case 'investment':
        return Icons.trending_up;
      case 'gift':
        return Icons.card_giftcard;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();
    final categoryTotals = _getCategoryTotals(filteredTransactions);
    final totalExpenses =
        categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);
    final totalIncome = filteredTransactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Period',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPeriod,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _periods.map((period) {
                        return DropdownMenuItem<String>(
                          value: period,
                          child: Text(period),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedPeriod = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Income'),
                            Text(
                              NumberFormat.currency(symbol: '\$')
                                  .format(totalIncome),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Expenses'),
                            Text(
                              NumberFormat.currency(symbol: '\$')
                                  .format(totalExpenses),
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Balance'),
                            Text(
                              NumberFormat.currency(symbol: '\$')
                                  .format(totalIncome - totalExpenses),
                              style: TextStyle(
                                color: (totalIncome - totalExpenses) >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
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
                    if (categoryTotals.isNotEmpty) ...[
                      _buildPieChart(categoryTotals),
                      const SizedBox(height: 16),
                      _buildCategoryList(categoryTotals),
                    ] else
                      const Center(
                        child: Text('No expenses in this period'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
