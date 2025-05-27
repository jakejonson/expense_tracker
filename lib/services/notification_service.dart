import 'dart:async';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import 'database_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _eventChannel =
      const EventChannel('com.example.expense_tracker/transactions');
  StreamSubscription? _subscription;
  Timer? _recurringCheckTimer;
  DateTime? _lastCheckTime;

  void startListening() {
    _subscription?.cancel();
    _subscription =
        _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        _handleTransaction(event);
      }
    });

    // Check for recurring transactions every 6 hours instead of every hour
    _recurringCheckTimer?.cancel();
    _recurringCheckTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      _checkRecurringTransactions();
    });

    // Also check when the service starts
    _checkRecurringTransactions();
  }

  Future<void> _checkRecurringTransactions() async {
    try {
      // Skip if we've checked in the last hour
      final now = DateTime.now();
      if (_lastCheckTime != null &&
          now.difference(_lastCheckTime!) < const Duration(hours: 1)) {
        return;
      }

      await DatabaseHelper.instance.checkAndCreateRecurringTransactions();
      _lastCheckTime = now;
    } catch (e) {
      print('Error checking recurring transactions: $e');
    }
  }

  Future<void> _handleTransaction(Map<dynamic, dynamic> event) async {
    try {
      final transaction = Transaction(
        amount: event['amount'] as double,
        category: 'Samsung Wallet', // Fixed category as requested
        note: event['description'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(event['date'] as int),
        isExpense: true,
        isRecurring: 0,
      );

      try {
        // Insert transaction into database
        await DatabaseHelper.instance.insertTransaction(transaction);

        // Log successful transaction creation
        print(
            'Transaction created: ${transaction.amount} - ${transaction.note}');
      } on DuplicateTransactionException catch (e) {
        // Log duplicate transaction
        print(
            'Duplicate transaction detected: ${transaction.amount} - ${transaction.note}');
        // We don't show a dialog here since this is a background service
      }
    } catch (e) {
      print('Error creating transaction: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _recurringCheckTimer?.cancel();
    _recurringCheckTimer = null;
    _lastCheckTime = null;
  }
}
