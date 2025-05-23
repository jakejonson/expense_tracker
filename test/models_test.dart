import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/models/budget.dart';

void main() {
  group('Transaction Model Tests', () {
    test('Create transaction', () {
      final now = DateTime.now();
      final transaction = Transaction(
        amount: 100.0,
        category: 'Food',
        date: now,
        isExpense: true,
      );

      expect(transaction.amount, 100.0);
      expect(transaction.category, 'Food');
      expect(transaction.date, now);
      expect(transaction.isExpense, true);
    });

    test('Transaction toMap and fromMap', () {
      final now = DateTime.now();
      final transaction = Transaction(
        amount: 100.0,
        category: 'Food',
        date: now,
        isExpense: true,
      );

      final map = transaction.toMap();
      expect(map['amount'], 100.0);
      expect(map['category'], 'Food');
      expect(map['date'], now.toIso8601String());
      expect(map['isExpense'], 1);

      final fromMap = Transaction.fromMap(map);
      expect(fromMap.amount, transaction.amount);
      expect(fromMap.category, transaction.category);
      expect(fromMap.date, transaction.date);
      expect(fromMap.isExpense, transaction.isExpense);
    });
  });

  group('Budget Model Tests', () {
    test('Create budget', () {
      final now = DateTime.now();
      final budget = Budget(
        amount: 1000.0,
        category: 'Food',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
      );

      expect(budget.amount, 1000.0);
      expect(budget.category, 'Food');
      expect(budget.startDate, now);
      expect(budget.endDate, now.add(const Duration(days: 30)));
    });

    test('Budget toMap and fromMap', () {
      final now = DateTime.now();
      final budget = Budget(
        amount: 1000.0,
        category: 'Food',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
      );

      final map = budget.toMap();
      expect(map['amount'], 1000.0);
      expect(map['category'], 'Food');
      expect(map['startDate'], now.toIso8601String());
      expect(
          map['endDate'], now.add(const Duration(days: 30)).toIso8601String());

      final fromMap = Budget.fromMap(map);
      expect(fromMap.amount, budget.amount);
      expect(fromMap.category, budget.category);
      expect(fromMap.startDate, budget.startDate);
      expect(fromMap.endDate, budget.endDate);
    });

    test('Budget with null category', () {
      final now = DateTime.now();
      final budget = Budget(
        amount: 1000.0,
        category: null,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
      );

      expect(budget.amount, 1000.0);
      expect(budget.category, null);
      expect(budget.startDate, now);
      expect(budget.endDate, now.add(const Duration(days: 30)));

      final map = budget.toMap();
      expect(map['category'], null);

      final fromMap = Budget.fromMap(map);
      expect(fromMap.category, null);
    });
  });
}
