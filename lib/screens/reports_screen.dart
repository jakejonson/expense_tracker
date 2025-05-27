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
  DateTime _selectedMonth = DateTime.now();
  Map<String, double> _categorySpending = {};
  Map<String, double> _categoryIncome = {};
  Map<int, double> _monthlySpending = {};
  Map<int, double> _dailySpending = {};
  List<Transaction> _transactions = [];

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
    final transactions =
        await DatabaseHelper.instance.getTransactionsForMonth(_selectedMonth);
    final Map<String, double> spending = {};
    final Map<String, double> income = {};
    final Map<int, double> dailySpending = {};
    final Map<int, double> monthlySpending = {};

    // Get all transactions for the year to calculate monthly trends
    final yearStart = DateTime(_selectedMonth.year, 1, 1);
    final yearEnd = DateTime(_selectedMonth.year, 12, 31);
    final yearlyTransactions = await DatabaseHelper.instance
        .getTransactionsByDateRange(yearStart, yearEnd);

    // Calculate monthly spending for the year
    for (var i = 1; i <= 12; i++) {
      monthlySpending[i] = 0;
    }
    for (var transaction in yearlyTransactions) {
      if (transaction.isExpense) {
        final month = transaction.date.month;
        monthlySpending[month] =
            (monthlySpending[month] ?? 0) + transaction.amount;
      }
    }

    // Calculate daily spending for the selected month
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    for (var i = 1; i <= daysInMonth; i++) {
      dailySpending[i] = 0;
    }
    for (var transaction in transactions) {
      if (transaction.isExpense) {
        final day = transaction.date.day;
        dailySpending[day] = (dailySpending[day] ?? 0) + transaction.amount;
        spending[transaction.category] =
            (spending[transaction.category] ?? 0) + transaction.amount;
      } else {
        income[transaction.category] =
            (income[transaction.category] ?? 0) + transaction.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _categorySpending = spending;
      _categoryIncome = income;
      _monthlySpending = monthlySpending;
      _dailySpending = dailySpending;
    });
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadData();
  }

  Widget _buildYearlyTrendChart() {
    final monthlyData = _monthlySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yearly Spending Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 1 && value.toInt() <= 12) {
                            return Text(
                              DateFormat('MMM')
                                  .format(DateTime(2000, value.toInt(), 1)),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles:
                        const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: monthlyData.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: false,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
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

  Widget _buildMonthlyTrendChart() {
    final dailyData = _dailySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Spending Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 1 && value.toInt() <= 31) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles:
                        const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: dailyData.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: false,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildYearlyTrendChart(),
                  const SizedBox(height: 16),
                  _buildMonthlyTrendChart(),
                  const SizedBox(height: 16),
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
    final totalIncome = _categoryIncome.values.isEmpty
        ? 0.0
        : _categoryIncome.values.reduce((a, b) => a + b);
    final totalExpense = _categorySpending.values.isEmpty
        ? 0.0
        : _categorySpending.values.reduce((a, b) => a + b);

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
                    '\$${totalIncome.toStringAsFixed(2)}',
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
                    '\$${totalExpense.toStringAsFixed(2)}',
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

    final totalExpense = _categorySpending.values.reduce((a, b) => a + b);

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
                    final percentage = (entry.value / totalExpense) * 100;
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

    final totalExpense = _categorySpending.values.reduce((a, b) => a + b);
    
    // Sort categories by amount in descending order
    final sortedCategories = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            ...sortedCategories.map((entry) {
              final percentage = (entry.value / totalExpense) * 100;
              final colorIndex =
                  sortedCategories.indexOf(entry) %
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