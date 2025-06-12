import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/transaction.dart';
import 'database_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _eventChannel =
      const EventChannel('com.example.expense_tracker/transactions');
  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription? _subscription;
  Timer? _recurringCheckTimer;
  DateTime? _lastCheckTime;

  Future<void> initialize() async {
    print('Initializing NotificationService...');
    // Initialize timezone data
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    print('NotificationService initialized successfully');

    // Start listening immediately after initialization
    startListening();
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to transaction details
    print('Notification tapped: ${response.payload}');
  }

  Future<void> _showNotification(String title, String body,
      {String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'recurring_transactions',
      'Recurring Transactions',
      channelDescription: 'Notifications for recurring transactions',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> scheduleNotification(
      Transaction transaction, DateTime scheduledDate) async {
    const androidDetails = AndroidNotificationDetails(
      'scheduled_transactions',
      'Scheduled Transactions',
      channelDescription: 'Notifications for scheduled transactions',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      transaction.id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Upcoming Transaction',
      '${transaction.isExpense ? "Expense" : "Income"} of \$${transaction.amount.toStringAsFixed(2)} for ${transaction.category} is scheduled for ${scheduledDate.toString().split(' ')[0]}',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: transaction.id?.toString(),
    );
  }

  void startListening() {
    print('Starting NotificationService listener...');
    _subscription?.cancel();
    _subscription =
        _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      print('Received event from event channel: $event');
      if (event is Map) {
        _handleTransaction(event);
      }
    });

    // Check for recurring transactions every 6 hours
    _recurringCheckTimer?.cancel();
    _recurringCheckTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      print('Timer triggered - checking recurring transactions');
      _checkRecurringTransactions();
    });

    // Perform initial check immediately
    print('Performing initial recurring transaction check');
    _checkRecurringTransactions();
    print('NotificationService listener started successfully');
  }

  Future<void> _checkRecurringTransactions() async {
    print('Checking recurring transactions...');
    // Skip if we've checked in the last hour
    final now = DateTime.now();
    if (_lastCheckTime != null &&
        now.difference(_lastCheckTime!) < const Duration(hours: 1)) {
      print('Skipping check - last check was less than an hour ago');
      return;
    }

    final createdTransactions =
        await DatabaseHelper.instance.checkAndCreateRecurringTransactions();
    
    print('Found ${createdTransactions.length} transactions to create');

    // Show notification for each created transaction
    for (var transaction in createdTransactions) {
      print(
          'Creating transaction: ${transaction.amount} for ${transaction.category}');
      await _showNotification(
        'Recurring Transaction Created',
        '${transaction.isExpense ? "Expense" : "Income"} of \$${transaction.amount.toStringAsFixed(2)} for ${transaction.category} has been created.',
        payload: transaction.id?.toString(),
      );
    }

    // Schedule notifications for upcoming recurring transactions
    final scheduledTransactions =
        await DatabaseHelper.instance.getScheduledTransactions();
    for (var transaction in scheduledTransactions) {
      if (transaction.nextOccurrence != null) {
        final nextDate = DateTime.parse(transaction.nextOccurrence!);
        if (nextDate.isAfter(now)) {
          await scheduleNotification(transaction, nextDate);
        }
      }
    }

    _lastCheckTime = now;
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
      } on DuplicateTransactionException {
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
