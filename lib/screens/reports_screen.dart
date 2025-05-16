import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = Constants.periods.first;
  List<Transaction> _transactions = [];
  Map<String, double> _categoryTotals = {};
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    DateTime startDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Quarter':
        startDate = DateTime(now.year, now.month - 2, 1);
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    final transactions = await DatabaseHelper.instance
        .getTransactionsByDateRange(startDate, now);
    
    final Map<String, double> totals = {};
    double total = 0;

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        totals[transaction.category] =
            (totals[transaction.category] ?? 0) + transaction.amount;
        total += transaction.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _categoryTotals = totals;
      _totalExpense = total;
    });
  }

  List<PieChartSectionData> _getSections() {
    final List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    _categoryTotals.forEach((category, amount) {
      if (amount > 0) {
        sections.add(
          PieChartSectionData(
            color: Constants.chartColors[colorIndex % Constants.chartColors.length],
            value: amount,
            title: '${(amount / _totalExpense * 100).toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        colorIndex++;
      }
    });

    return sections;
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _categoryTotals.entries.map((entry) {
        final index = _categoryTotals.keys.toList().indexOf(entry.key);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Constants.chartColors[index % Constants.chartColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.key),
              ),
              Text(
                NumberFormat.currency(symbol: '\$').format(entry.value),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: Constants.periods
                  .map((period) => ButtonSegment<String>(
                        value: period,
                        label: Text(period),
                      ))
                  .toList(),
              selected: {_selectedPeriod},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedPeriod = newSelection.first;
                });
                _loadTransactions();
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Total Expenses',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(symbol: '\$').format(_totalExpense),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_categoryTotals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: PieChart(
                      PieChartData(
                        sections: _getSections(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildLegend(),
                    ),
                  ),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No expenses in this period'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 