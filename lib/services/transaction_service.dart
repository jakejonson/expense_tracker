import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import '../widgets/category_selection_dialog.dart';
import '../utils/string_extensions.dart';

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Transaction>> getRecentTransactions() async {
    final allTransactions = await _dbHelper.getTransactions();
    return allTransactions.take(20).toList();
  }

  Future<List<Transaction>> getScheduledTransactions() async {
    return await _dbHelper.getScheduledTransactions();
  }

  Future<Transaction?> getTransaction(int id) async {
    final transactions = await _dbHelper.getTransactions();
    try {
      return transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> editTransaction(
    BuildContext context,
    Transaction transaction,
  ) async {
    final amountController =
        TextEditingController(text: transaction.amount.toString());
    final noteController = TextEditingController(text: transaction.note);
    String selectedCategory = transaction.category;
    bool isExpense = transaction.isExpense;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Edit Transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: (isExpense
                        ? Constants.expenseCategories
                        : Constants.incomeCategories)
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, {
                'amount': amount,
                'category': selectedCategory,
                'note': noteController.text,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedTransaction = Transaction(
        id: transaction.id,
        amount: result['amount'],
        category: result['category'],
        date: transaction.date,
        isExpense: isExpense,
        note: result['note'],
      );

      await _dbHelper.updateTransaction(updatedTransaction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> deleteTransaction(
    BuildContext context,
    Transaction transaction,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${transaction.isExpense ? "expense" : "income"} of \$${transaction.amount.toStringAsFixed(2)} for ${transaction.category}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _dbHelper.deleteTransaction(transaction.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editScheduledTransaction(
    BuildContext context,
    Transaction transaction,
  ) async {
    final amountController =
        TextEditingController(text: transaction.amount.toString());
    final noteController = TextEditingController(text: transaction.note);
    String selectedCategory = transaction.category;
    String selectedFrequency = transaction.frequency ?? 'weekly';
    bool isExpense = transaction.isExpense;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Scheduled Transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: (isExpense
                        ? Constants.expenseCategories
                        : Constants.incomeCategories)
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFrequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: ['daily', 'weekly', 'monthly', 'yearly']
                    .map((freq) => DropdownMenuItem(
                          value: freq,
                          child: Text(freq.capitalize()),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedFrequency = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, {
                'amount': amount,
                'category': selectedCategory,
                'note': noteController.text,
                'frequency': selectedFrequency,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedTransaction = Transaction(
        id: transaction.id,
        amount: result['amount'],
        category: result['category'],
        date: transaction.date,
        isExpense: isExpense,
        note: result['note'],
        frequency: result['frequency'],
        nextOccurrence: transaction.nextOccurrence,
      );

      await _dbHelper.updateTransaction(updatedTransaction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled transaction updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> cancelScheduledTransaction(
    BuildContext context,
    Transaction transaction,
  ) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scheduled Transaction'),
        content: Text(
          'Are you sure you want to cancel this scheduled ${transaction.isExpense ? "expense" : "income"} of \$${transaction.amount.toStringAsFixed(2)} for ${transaction.category}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      await _dbHelper.deleteTransaction(transaction.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled transaction cancelled'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> batchEditTransactions(
    BuildContext context,
    List<int> transactionIds,
  ) async {
    final amountController = TextEditingController();
    String? selectedCategory;
    bool? isExpense;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Transactions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'New Amount (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => CategorySelectionDialog(
                        isExpense: isExpense ?? true,
                        selectedCategory: selectedCategory,
                        onCategorySelected: (category) {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Row(
                      children: [
                        if (selectedCategory != null) ...[
                          Icon(
                            isExpense == true
                                ? Constants
                                    .expenseCategoryIcons[selectedCategory]
                                : Constants
                                    .incomeCategoryIcons[selectedCategory],
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(selectedCategory ?? 'Select Category'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool?>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Expense'),
                      icon: Icon(Icons.remove),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Income'),
                      icon: Icon(Icons.add),
                    ),
                  ],
                  selected: {isExpense},
                  onSelectionChanged: (Set<bool?> newSelection) {
                    setState(() {
                      isExpense = newSelection.first;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amount = amountController.text.isEmpty
                    ? null
                    : double.tryParse(amountController.text);
                if (amount != null && amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'amount': amount,
                  'category': selectedCategory,
                  'isExpense': isExpense,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final transactions = await _dbHelper.getTransactions();
      for (var id in transactionIds) {
        final transaction = transactions.firstWhere((t) => t.id == id);
        final updatedTransaction = Transaction(
          id: transaction.id,
          amount: result['amount'] ?? transaction.amount,
          category: result['category'] ?? transaction.category,
          date: transaction.date,
          isExpense: result['isExpense'] ?? transaction.isExpense,
          note: transaction.note,
        );

        await _dbHelper.updateTransaction(updatedTransaction);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${transactionIds.length} transactions updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> batchDeleteTransactions(
    BuildContext context,
    List<int> transactionIds,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transactions'),
        content: Text(
          'Are you sure you want to delete ${transactionIds.length} transaction${transactionIds.length > 1 ? 's' : ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (var id in transactionIds) {
        await _dbHelper.deleteTransaction(id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${transactionIds.length} transaction${transactionIds.length > 1 ? 's' : ''} deleted successfully',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
