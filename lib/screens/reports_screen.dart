import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/month_selector.dart';
import '../utils/constants.dart';
import 'dart:math';
import '../widgets/app_drawer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, double> _categorySpending = {};
  Map<String, double> _categoryIncome = {};
  Map<int, double> _monthlySpending = {};
  Map<int, double> _monthlyIncome = {};
  Map<int, double> _dailySpending = {};
  List<Transaction> _transactions = [];
  bool _isLoading = true;

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

  Color _getCategoryColor(String category, List<String> categories) {
    final index = categories.indexOf(category);
    return _categoryColors[index % _categoryColors.length];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    DateTime startDate;
    DateTime endDate;

    if (_startDate != null && _endDate != null) {
      startDate = _startDate!;
      endDate = _endDate!;
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    }

    final transactions = await DatabaseHelper.instance
        .getTransactionsByDateRange(startDate, endDate);
    
    final Map<String, double> spending = {};
    final Map<String, double> income = {};
    final Map<int, double> dailySpending = {};
    final Map<int, double> monthlySpending = {};
    final Map<int, double> monthlyIncome = {};

    // Calculate monthly spending and income for the year
    for (var i = 1; i <= 12; i++) {
      monthlySpending[i] = 0;
      monthlyIncome[i] = 0;
    }

    // Get all transactions for the year to calculate monthly trends
    final yearStart = DateTime(_selectedMonth.year, 1, 1);
    final yearEnd = DateTime(_selectedMonth.year, 12, 31);
    final yearlyTransactions = await DatabaseHelper.instance
        .getTransactionsByDateRange(yearStart, yearEnd);

    for (var transaction in yearlyTransactions) {
      final month = transaction.date.month;
      if (transaction.isExpense) {
        monthlySpending[month] =
            (monthlySpending[month] ?? 0) + transaction.amount;
      } else {
        monthlyIncome[month] = (monthlyIncome[month] ?? 0) + transaction.amount;
      }
    }

    // Calculate daily spending for the selected period
    final daysInRange = endDate.difference(startDate).inDays + 1;
    for (var i = 0; i < daysInRange; i++) {
      final date = startDate.add(Duration(days: i));
      dailySpending[date.day] = 0;
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
      _monthlyIncome = monthlyIncome;
      _dailySpending = dailySpending;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
      _startDate = null;
      _endDate = null;
    });
    _loadData();
  }

  Widget _buildYearlyTrendChart() {
    final monthlySpendingData = _monthlySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final monthlyIncomeData = _monthlyIncome.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yearly Financial Trend',
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
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    // Spending line
                    LineChartBarData(
                      spots: monthlySpendingData.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: false,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withAlpha(51),
                      ),
                    ),
                    // Income line
                    LineChartBarData(
                      spots: monthlyIncomeData.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: false,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withAlpha(51),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final isIncome = spot.barIndex == 1;
                          return LineTooltipItem(
                            '${isIncome ? "Income" : "Spending"}: \$${spot.y.toStringAsFixed(0)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Spending', Colors.red),
                const SizedBox(width: 16),
                _buildLegendItem('Income', Colors.green),
              ],
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
                              value.toInt().toStringAsFixed(0),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: dailyData.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withAlpha(51),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            'Day ${spot.x.toInt()}\n\$${spot.y.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: AppDrawer(
        onExport: () async {
          try {
            final transactions =
                await DatabaseHelper.instance.getTransactions();
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
              await Share.shareXFiles([XFile(filePath)]);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error exporting data: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                MonthSelector(
                  selectedMonth: _selectedMonth,
                  onMonthChanged: _onMonthChanged,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_startDate != null && _endDate != null
                        ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                        : 'Select Date Range'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
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
                  _buildYearlyTrendChart(),
                  const SizedBox(height: 16),
                  _buildMonthlyTrendChart(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  _buildSuperCategoryPieChart(),
                  const SizedBox(height: 16),
                  _buildExpensePieChart(),
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
    final sortedCategories = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pie Chart
                SizedBox(
                  width: 200,
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: sortedCategories.map((entry) {
                        final percentage = (entry.value / totalExpense) * 100;
                        return PieChartSectionData(
                          value: entry.value,
                          title: '${percentage.toStringAsFixed(1)}%',
                          radius: 100,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          color: _getCategoryColor(entry.key,
                              sortedCategories.map((e) => e.key).toList()),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Category Breakdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...sortedCategories.map((entry) {
                        final percentage = (entry.value / totalExpense) * 100;
                        return InkWell(
                          onTap: () => _showCategoryTransactions(entry.key),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      '\$${entry.value.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
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
                                    _getCategoryColor(
                                        entry.key,
                                        sortedCategories
                                            .map((e) => e.key)
                                            .toList()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryTransactions(String category) {
    final categoryTransactions = _transactions
        .where((t) => t.category == category)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$category Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: categoryTransactions.isEmpty
                  ? const Center(
                      child: Text('No transactions found for this category'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: categoryTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = categoryTransactions[index];
                        return ListTile(
                          leading: Icon(
                            transaction.isExpense
                                ? Constants
                                    .expenseCategoryIcons[transaction.category]
                                : Constants
                                    .incomeCategoryIcons[transaction.category],
                            color: transaction.isExpense
                                ? Colors.red
                                : Colors.green,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  transaction.note ?? transaction.category,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                '\$${transaction.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: transaction.isExpense
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            DateFormat.yMMMd().format(transaction.date),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperCategoryPieChart() {
    if (_categorySpending.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate super category totals
    final Map<String, double> superCategoryTotals = {};
    for (var entry in _categorySpending.entries) {
      final superCategory =
          Constants.categoryToSuperCategory[entry.key] ?? 'Wants';
      superCategoryTotals[superCategory] =
          (superCategoryTotals[superCategory] ?? 0) + entry.value;
    }

    final totalExpense = superCategoryTotals.values.reduce((a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Super Category Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: GestureDetector(
                onTapDown: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final Offset localPosition =
                      box.globalToLocal(details.globalPosition);
                  final double centerX = box.size.width / 2;
                  final double centerY = box.size.height / 2;
                  const double radius = 100;

                  // Calculate angle and distance from center
                  final double dx = localPosition.dx - centerX;
                  final double dy = localPosition.dy - centerY;
                  final double distance = sqrt(dx * dx + dy * dy);

                  if (distance <= radius) {
                    final double angle = atan2(dy, dx);
                    final double normalizedAngle = (angle + pi) / (2 * pi);

                    // Calculate which section was tapped
                    double currentAngle = 0;
                    for (var entry in superCategoryTotals.entries) {
                      final sectionAngle =
                          (entry.value / totalExpense) * 2 * pi;
                      if (normalizedAngle >= currentAngle &&
                          normalizedAngle <= currentAngle + sectionAngle) {
                        _showSuperCategoryTrend(entry.key);
                        break;
                      }
                      currentAngle += sectionAngle;
                    }
                  }
                },
                child: PieChart(
                  PieChartData(
                    sections: superCategoryTotals.entries.map((entry) {
                      final percentage = (entry.value / totalExpense) * 100;
                      final colorIndex =
                          Constants.superCategories.indexOf(entry.key);
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
            ),
            const SizedBox(height: 16),
            ...superCategoryTotals.entries.map((entry) {
              final percentage = (entry.value / totalExpense) * 100;
              final colorIndex = Constants.superCategories.indexOf(entry.key);
              return InkWell(
                onTap: () => _showSuperCategoryTrend(entry.key),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: _categoryColors[colorIndex],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.key),
                      ),
                      Text(
                        '\$${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _showSuperCategoryTrend(String superCategory) async {
    // Get transactions for the last 6 months
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
    final transactions = await DatabaseHelper.instance
        .getTransactionsByDateRange(sixMonthsAgo, now);

    // Calculate monthly totals for both super categories
    final Map<DateTime, Map<String, double>> monthlyTotals = {};
    for (var i = 0; i < 6; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyTotals[month] = {
        'Wants': 0,
        'Needs': 0,
        'Investments': 0,
      };
    }

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        final categorySuperCategory =
            Constants.categoryToSuperCategory[transaction.category] ?? 'Wants';
        final month =
            DateTime(transaction.date.year, transaction.date.month, 1);
        if (monthlyTotals.containsKey(month)) {
          monthlyTotals[month]![categorySuperCategory] =
              monthlyTotals[month]![categorySuperCategory]! +
                  transaction.amount;
        }
      }
    }

    // Sort months chronologically
    final sortedMonths = monthlyTotals.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Super Categories Monthly Trend',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
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
                            if (value.toInt() >= 0 &&
                                value.toInt() < sortedMonths.length) {
                              return Text(
                                DateFormat('MMM')
                                    .format(sortedMonths[value.toInt()]),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      // Wants trend
                      LineChartBarData(
                        spots: List.generate(sortedMonths.length, (index) {
                          return FlSpot(
                            index.toDouble(),
                            monthlyTotals[sortedMonths[index]]!['Wants']!,
                          );
                        }),
                        isCurved: false,
                        color: _categoryColors[
                            Constants.superCategories.indexOf('Wants')],
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _categoryColors[
                                  Constants.superCategories.indexOf('Wants')]
                              .withOpacity(0.2),
                        ),
                      ),
                      // Needs trend
                      LineChartBarData(
                        spots: List.generate(sortedMonths.length, (index) {
                          return FlSpot(
                            index.toDouble(),
                            monthlyTotals[sortedMonths[index]]!['Needs']!,
                          );
                        }),
                        isCurved: false,
                        color: _categoryColors[
                            Constants.superCategories.indexOf('Needs')],
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _categoryColors[
                                  Constants.superCategories.indexOf('Needs')]
                              .withOpacity(0.2),
                        ),
                      ),
                      // Investments trend
                      LineChartBarData(
                        spots: List.generate(sortedMonths.length, (index) {
                          return FlSpot(
                            index.toDouble(),
                            monthlyTotals[sortedMonths[index]]!['Investments']!,
                          );
                        }),
                        isCurved: false,
                        color: _categoryColors[
                            Constants.superCategories.indexOf('Investments')],
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _categoryColors[Constants.superCategories
                                  .indexOf('Investments')]
                              .withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(
                      'Wants',
                      _categoryColors[
                          Constants.superCategories.indexOf('Wants')]),
                  const SizedBox(width: 24),
                  _buildLegendItem(
                      'Needs',
                      _categoryColors[
                          Constants.superCategories.indexOf('Needs')]),
                  const SizedBox(width: 24),
                  _buildLegendItem(
                      'Investments',
                      _categoryColors[
                          Constants.superCategories.indexOf('Investments')]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
} 