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

  void startListening() {
    _subscription?.cancel();
    _subscription =
        _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        _handleTransaction(event);
      }
    });
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

      // Insert transaction into database
      await DatabaseHelper.instance.insertTransaction(transaction);

      // Log successful transaction creation
      print('Transaction created: ${transaction.amount} - ${transaction.note}');
    } catch (e) {
      print('Error creating transaction: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
