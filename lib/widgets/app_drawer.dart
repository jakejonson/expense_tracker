import 'package:flutter/material.dart';
import '../screens/import_screen.dart';
import '../screens/category_management_screen.dart';
import '../screens/category_mapping_screen.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';

class AppDrawer extends StatefulWidget {
  final Function() onExport;

  const AppDrawer({
    super.key,
    required this.onExport,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Transaction> _last20Transactions = [];
  List<Transaction> _scheduledTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Get all transactions and sort by date
      final allTransactions = await DatabaseHelper.instance.getTransactions();
      allTransactions.sort((a, b) => b.date.compareTo(a.date));

      // Get scheduled transactions
      final scheduledTransactions =
          await DatabaseHelper.instance.getScheduledTransactions();

      setState(() {
        _last20Transactions = allTransactions.take(20).toList();
        _scheduledTransactions = scheduledTransactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Text(
              'Expense Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export'),
            onTap: () {
              Navigator.pop(context);
              widget.onExport();
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Category Management'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryManagementScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Category Mapping'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryMappingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Recent Transactions'),
            onTap: () {
              Navigator.pop(context);
              if (_isLoading) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loading transactions...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              _showTransactionsDialog(
                  context, _last20Transactions, 'Recent Transactions');
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Scheduled Transactions'),
            onTap: () {
              Navigator.pop(context);
              if (_isLoading) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loading transactions...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              _showTransactionsDialog(
                  context, _scheduledTransactions, 'Scheduled Transactions');
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh Data'),
            onTap: () {
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing data...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTransactionsDialog(
      BuildContext context, List<Transaction> transactions, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: transactions.isEmpty
              ? const Center(
                  child: Text('No transactions found'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      leading: Icon(
                        transaction.isExpense ? Icons.remove : Icons.add,
                        color:
                            transaction.isExpense ? Colors.red : Colors.green,
                      ),
                      title: Text(transaction.category),
                      subtitle: Text(transaction.note ?? ''),
                      trailing: Text(
                        '\$${transaction.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color:
                              transaction.isExpense ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
