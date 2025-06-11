import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class BudgetDetailsScreen extends StatefulWidget {
  final Budget budget;

  const BudgetDetailsScreen({super.key, required this.budget});

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String _selectedPeriod = '6 Months';
  List<Map<String, dynamic>> _historicalData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case '6 Months':
        startDate = DateTime(now.year, now.month - 5, 1);
        break;
      case '3 Months':
        startDate = DateTime(now.year, now.month - 2, 1);
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    final transactions =
        await DatabaseHelper.instance.getTransactionsByDateRange(
      startDate,
      now,
    );

    // Filter transactions for this category or all expenses for overall budget
    final categoryTransactions = transactions
        .where((t) =>
            t.isExpense &&
            (widget.budget.category == null ||
                t.category == widget.budget.category))
        .toList();

    // Group transactions by month
    final Map<String, double> monthlySpending = {};
    for (var transaction in categoryTransactions) {
      final monthKey = DateFormat('MMM yyyy').format(transaction.date);
      monthlySpending[monthKey] =
          (monthlySpending[monthKey] ?? 0) + transaction.amount;
    }

    // Get budgets for each month
    final List<Map<String, dynamic>> historicalData = [];
    var currentDate = startDate;
    while (!currentDate.isAfter(now)) {
      final monthKey = DateFormat('MMM yyyy').format(currentDate);
      final monthBudgets =
          await DatabaseHelper.instance.getBudgetsForMonth(currentDate);
      final monthBudget = monthBudgets.firstWhere(
        (b) => b.category == widget.budget.category,
        orElse: () => widget.budget,
      );

      historicalData.add({
        'month': monthKey,
        'spent': monthlySpending[monthKey] ?? 0,
        'budget': monthBudget.amount,
      });
      currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
    }

    setState(() {
      _transactions = categoryTransactions;
      _historicalData = historicalData;
      _isLoading = false;
    });
  }

  void _onPeriodChanged(String? newPeriod) {
    if (newPeriod != null) {
      setState(() {
        _selectedPeriod = newPeriod;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.budget.category ?? 'Overall Budget'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),
                  _buildHistoricalChart(),
                  const SizedBox(height: 24),
                  _buildTransactionsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedPeriod,
      decoration: const InputDecoration(
        labelText: 'Time Period',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'Month', child: Text('This Month')),
        DropdownMenuItem(value: '3 Months', child: Text('Last 3 Months')),
        DropdownMenuItem(value: '6 Months', child: Text('Last 6 Months')),
        DropdownMenuItem(value: 'Year', child: Text('This Year')),
      ],
      onChanged: _onPeriodChanged,
    );
  }

  Widget _buildHistoricalChart() {
    // Calculate the maximum value for scaling
    final maxSpent = _historicalData.fold<double>(
      0,
      (max, data) => data['spent'] > max ? data['spent'] : max,
    );
    final maxBudget = _historicalData.fold<double>(
      0,
      (max, data) => data['budget'] > max ? data['budget'] : max,
    );
    final maxValue = [maxSpent, maxBudget].reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxValue * 1.2; // Add 20% padding

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  // Bar Chart
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceEvenly,
                      maxY: chartMaxY,
                      minY: 0,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final data = _historicalData[groupIndex];
                            return BarTooltipItem(
                              '${data['month']}\n'
                              'Spent: \$${data['spent'].toStringAsFixed(2)}\n'
                              'Budget: \$${data['budget'].toStringAsFixed(2)}',
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value >= 0 &&
                                  value < _historicalData.length) {
                                return Transform.rotate(
                                  angle: -0.5,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _historicalData[value.toInt()]['month'],
                                      style: const TextStyle(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '\$${value.toInt()}',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: _historicalData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data['spent'],
                              color: Colors.blue,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  // Line Chart (Budget)
                  Positioned.fill(
                    left: 40, // Match the leftTitles reservedSize
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: chartMaxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _historicalData.asMap().entries.map((entry) {
                              // Calculate center position for each bar
                              // With spaceEvenly, each bar takes up 1 unit of space
                              // So the center of each bar is at index + 0.5
                              final x = entry.key + 0.5;
                              return FlSpot(
                                x,
                                entry.value['budget'],
                              );
                            }).toList(),
                            isCurved: false,
                            color: Colors.red,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.red,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: Colors.blueGrey,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final index = spot.x.toInt();
                                final data = _historicalData[index];
                                return LineTooltipItem(
                                  'Spent: \$${data['spent'].toStringAsFixed(0)}\n'
                                  'Budget: \$${data['budget'].toStringAsFixed(0)}',
                                  const TextStyle(color: Colors.white),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        minX: 0,
                        maxX: _historicalData.length.toDouble(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return const Center(
        child: Text('No transactions found for this period'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _transactions.length,
          itemBuilder: (context, index) {
            final transaction = _transactions[index];
            return ListTile(
              title: Text(transaction.category),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(transaction.date),
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty)
                    Text(
                      transaction.note!,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              trailing: Text(
                '\$${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: transaction.isExpense ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
