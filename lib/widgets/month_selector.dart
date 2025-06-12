import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  const MonthSelector({
    Key? key,
    required this.selectedMonth,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          // Swipe right - previous month
          onMonthChanged(DateTime(
            selectedMonth.year,
            selectedMonth.month - 1,
            1,
          ));
        } else if (details.primaryVelocity! < 0) {
          // Swipe left - next month
          onMonthChanged(DateTime(
            selectedMonth.year,
            selectedMonth.month + 1,
            1,
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                onMonthChanged(DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                  1,
                ));
              },
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat.yMMMM().format(selectedMonth),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                onMonthChanged(DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                  1,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
