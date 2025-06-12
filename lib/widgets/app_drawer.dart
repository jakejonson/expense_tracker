import 'package:flutter/material.dart';
import '../screens/import_screen.dart';
import '../screens/category_management_screen.dart';
import '../screens/category_mapping_screen.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../utils/constants.dart';
import '../utils/string_extensions.dart';
import 'package:intl/intl.dart';
import '../widgets/category_selection_dialog.dart';

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
  final _transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final recentTransactions =
          await _transactionService.getRecentTransactions();
      final scheduledTransactions =
          await _transactionService.getScheduledTransactions();

      setState(() {
        _last20Transactions = recentTransactions;
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
    bool isSelectionMode = false;
    final Set<int> selectedTransactions = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              if (title == 'Recent Transactions') ...[
                if (isSelectionMode && selectedTransactions.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _transactionService.batchEditTransactions(
                          context, selectedTransactions.toList());
                      _loadData();
                    },
                    tooltip: 'Edit Selected',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _transactionService.batchDeleteTransactions(
                          context, selectedTransactions.toList());
                      _loadData();
                    },
                    tooltip: 'Delete Selected',
                  ),
                ],
                IconButton(
                  icon: Icon(isSelectionMode ? Icons.close : Icons.select_all),
                  onPressed: () {
                    setState(() {
                      isSelectionMode = !isSelectionMode;
                      if (!isSelectionMode) {
                        selectedTransactions.clear();
                      }
                    });
                  },
                  tooltip:
                      isSelectionMode ? 'Exit Selection' : 'Select Multiple',
                ),
              ],
            ],
          ),
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
                      return GestureDetector(
                        onLongPress: () {
                          if (title == 'Recent Transactions' &&
                              !isSelectionMode) {
                            setState(() {
                              isSelectionMode = true;
                              selectedTransactions.add(transaction.id!);
                            });
                          }
                        },
                        child: ListTile(
                          leading:
                              isSelectionMode && title == 'Recent Transactions'
                                  ? Checkbox(
                                      value: selectedTransactions
                                          .contains(transaction.id),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            selectedTransactions
                                                .add(transaction.id!);
                                          } else {
                                            selectedTransactions
                                                .remove(transaction.id);
                                            if (selectedTransactions.isEmpty) {
                                              isSelectionMode = false;
                                            }
                                          }
                                        });
                                      },
                                    )
                                  : Icon(
                                      transaction.isExpense
                                          ? Icons.remove
                                          : Icons.add,
                                      color: transaction.isExpense
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                          title: Text(transaction.category),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (transaction.note != null &&
                                  transaction.note!.isNotEmpty)
                                Text(transaction.note!),
                              if (transaction.nextOccurrence != null)
                                Text(
                                  'Next: ${DateFormat.yMMMd().format(DateTime.parse(transaction.nextOccurrence!))}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (transaction.frequency != null)
                                Text(
                                  'Frequency: ${transaction.frequency!.capitalize()}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${transaction.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: transaction.isExpense
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (title == 'Scheduled Transactions') ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _transactionService
                                        .editScheduledTransaction(
                                            context, transaction);
                                    _loadData();
                                  },
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _transactionService
                                        .cancelScheduledTransaction(
                                            context, transaction);
                                    _loadData();
                                  },
                                  tooltip: 'Cancel',
                                ),
                              ] else if (title == 'Recent Transactions' &&
                                  !isSelectionMode) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _transactionService.editTransaction(
                                        context, transaction);
                                    _loadData();
                                  },
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _transactionService.deleteTransaction(
                                        context, transaction);
                                    _loadData();
                                  },
                                  tooltip: 'Delete',
                                ),
                              ],
                            ],
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
      ),
    );
  }
}
