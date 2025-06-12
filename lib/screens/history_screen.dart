import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import '../widgets/month_selector.dart';
import '../models/category_mapping.dart';
import '../widgets/category_selection_dialog.dart';
import '../widgets/app_drawer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Transaction> _transactions = [];
  String? _selectedCategory;
  bool? _isExpense;
  final _searchController = TextEditingController();
  final _editAmountController = TextEditingController();
  final _editNoteController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<int> _selectedTransactions = {};
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  String _sortBy = 'date'; // 'date' or 'amount'
  bool _sortAscending = false;

  // Static variables to persist filter state
  static String? _lastSelectedCategory;
  static bool? _lastIsExpense;
  static String _lastSearchText = '';
  static String _lastSortBy = 'date';
  static bool _lastSortAscending = false;
  static DateTime _lastSelectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Restore last filter state
    _selectedCategory = _lastSelectedCategory;
    _isExpense = _lastIsExpense;
    _searchController.text = _lastSearchText;
    _sortBy = _lastSortBy;
    _sortAscending = _lastSortAscending;
    _selectedMonth = _lastSelectedMonth;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final transactions =
        await DatabaseHelper.instance.getTransactionsForMonth(_selectedMonth);
    setState(() {
      _transactions = transactions;
      _selectedTransactions.clear();
      _isSelectionMode = false;
      _isLoading = false;
    });
  }

  void _toggleTransactionSelection(int id) {
    setState(() {
      if (_selectedTransactions.contains(id)) {
        _selectedTransactions.remove(id);
        if (_selectedTransactions.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTransactions.add(id);
      }
    });
  }

  Future<void> _batchDeleteTransactions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transactions'),
        content: Text(
          'Are you sure you want to delete ${_selectedTransactions.length} transaction${_selectedTransactions.length > 1 ? 's' : ''}?',
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
      for (var id in _selectedTransactions) {
        await DatabaseHelper.instance.deleteTransaction(id);
      }
      _loadTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedTransactions.length} transaction${_selectedTransactions.length > 1 ? 's' : ''} deleted successfully',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _batchEditTransactions() async {
    final amountController = TextEditingController();
    String? selectedCategory;
    bool? isExpense;
    DateTime? selectedDate;

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
                        isExpense: _isExpense ?? true,
                        selectedCategory: _selectedCategory,
                        onCategorySelected: (category) {
                          setState(() {
                            _selectedCategory = category;
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
                        if (_selectedCategory != null) ...[
                          Icon(
                            _isExpense == true
                                ? Constants
                                    .expenseCategoryIcons[_selectedCategory]
                                : Constants
                                    .incomeCategoryIcons[_selectedCategory],
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(_selectedCategory ?? 'Select Category'),
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
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('New Date (Optional)'),
                  subtitle: Text(
                    selectedDate != null
                        ? DateFormat.yMMMd().format(selectedDate!)
                        : 'Select a date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
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
                Navigator.pop(context, {
                  'amount': amountController.text.isNotEmpty
                      ? double.parse(amountController.text)
                      : null,
                  'category': selectedCategory,
                  'isExpense': isExpense,
                  'date': selectedDate,
                });
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      for (var id in _selectedTransactions) {
        final transaction = _transactions.firstWhere((t) => t.id == id);
        final updatedTransaction = Transaction(
          id: transaction.id,
          amount: result['amount'] ?? transaction.amount,
          category: result['category'] ?? transaction.category,
          note: transaction.note,
          date: result['date'] ?? transaction.date,
          isExpense: result['isExpense'] ?? transaction.isExpense,
          isRecurring: transaction.isRecurring,
          frequency: transaction.frequency,
        );
        await DatabaseHelper.instance.updateTransaction(updatedTransaction);
      }
      await DatabaseHelper.instance.checkAndUpdateBudgets();
      _loadTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedTransactions.length} transaction${_selectedTransactions.length > 1 ? 's' : ''} updated successfully',
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  List<Transaction> _getFilteredTransactions() {
    return _transactions.where((transaction) {
      if (_selectedCategory != null &&
          _selectedCategory!.isNotEmpty &&
          transaction.category != _selectedCategory) {
        return false;
      }
      if (_isExpense != null && transaction.isExpense != _isExpense) {
        return false;
      }
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase().trim();
        // Search in amount
        if (transaction.amount.toString().contains(searchTerm)) {
          return true;
        }
        // Search in note
        if (transaction.note != null &&
            transaction.note!.toLowerCase().contains(searchTerm)) {
          return true;
        }
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (_sortBy == 'date') {
          return _sortAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date);
        } else {
          // Always sort amount in descending order
          return b.amount.compareTo(a.amount);
        }
      });
  }

  void _toggleSort() {
    setState(() {
      if (_sortBy == 'date') {
        _sortBy = 'amount';
        _sortAscending = false;
      } else {
        _sortBy = 'date';
        _sortAscending = !_sortAscending;
      }
    });
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadTransactions();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _isExpense = null;
      _searchController.clear();
      _sortBy = 'date';
      _sortAscending = false;
      _selectedMonth = DateTime.now();
      _isSelectionMode = false;
      _selectedTransactions.clear();
    });
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedTransactions.clear();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Filters',
              onPressed: _resetFilters,
            ),
            IconButton(
              icon: Icon(
                _sortBy == 'date' ? Icons.calendar_today : Icons.attach_money,
                color: _sortAscending ? Colors.blue : null,
              ),
              tooltip:
                  'Sort by ${_sortBy} (${_sortAscending ? 'ascending' : 'descending'})',
              onPressed: _toggleSort,
            ),
            if (_isSelectionMode && _selectedTransactions.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _batchEditTransactions,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _batchDeleteTransactions,
              ),
            ],
          ],
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
        body: Column(
          children: [
            MonthSelector(
              selectedMonth: _selectedMonth,
              onMonthChanged: _onMonthChanged,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search in amounts or notes',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => CategorySelectionDialog(
                                isExpense: _isExpense ?? true,
                                selectedCategory: _selectedCategory,
                                onCategorySelected: (category) {
                                  setState(() {
                                    _selectedCategory = category;
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
                                if (_selectedCategory != null) ...[
                                  Icon(
                                    _isExpense == true
                                        ? Constants.expenseCategoryIcons[
                                            _selectedCategory]
                                        : Constants.incomeCategoryIcons[
                                            _selectedCategory],
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(_selectedCategory ?? 'All Categories'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<bool?>(
                          value: _isExpense,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<bool?>(
                              value: null,
                              child: Text('All'),
                            ),
                            DropdownMenuItem<bool?>(
                              value: true,
                              child: Text('Expense'),
                            ),
                            DropdownMenuItem<bool?>(
                              value: false,
                              child: Text('Income'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _isExpense = value;
                              _selectedCategory = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTransactions.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isNotEmpty
                                ? 'No transactions found matching "${_searchController.text}"'
                                : 'No transactions for ${DateFormat.yMMMM().format(_selectedMonth)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : _buildTransactionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    final filteredTransactions = _getFilteredTransactions();
    return ListView.builder(
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = filteredTransactions[index];
        return Dismissible(
          key: Key(transaction.id.toString()),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Delete Transaction'),
                  content: const Text(
                      'Are you sure you want to delete this transaction?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) async {
            await DatabaseHelper.instance.deleteTransaction(transaction.id!);
            setState(() {
              _transactions.remove(transaction);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${transaction.isExpense ? 'Expense' : 'Income'} deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await DatabaseHelper.instance
                        .insertTransaction(transaction);
                    setState(() {
                      _transactions.add(transaction);
                    });
                  },
                ),
              ),
            );
          },
          child: GestureDetector(
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedTransactions.add(transaction.id!);
                });
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: InkWell(
                onTap: _isSelectionMode
                    ? () => _toggleTransactionSelection(transaction.id!)
                    : null,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  dense: true,
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: _selectedTransactions.contains(transaction.id),
                          onChanged: (value) {
                            _toggleTransactionSelection(transaction.id!);
                          },
                        )
                      : Icon(
                          transaction.isExpense
                              ? Constants
                                  .expenseCategoryIcons[transaction.category]
                              : Constants
                                  .incomeCategoryIcons[transaction.category],
                          color:
                              transaction.isExpense ? Colors.red : Colors.green,
                          size: 18,
                        ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.category,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        NumberFormat.currency(symbol: '\$')
                            .format(transaction.amount),
                        style: TextStyle(
                          color:
                              transaction.isExpense ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (transaction.note != null &&
                          transaction.note!.isNotEmpty)
                        Text(
                          transaction.note!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        DateFormat.yMMMd().format(transaction.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                  trailing: _isSelectionMode
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _editTransaction(transaction),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editTransaction(Transaction transaction) async {
    _editAmountController.text = transaction.amount.toString();
    _editNoteController.text = transaction.note ?? '';
    bool isExpense = transaction.isExpense;
    String selectedCategory = transaction.category;
    DateTime selectedDate = transaction.date;
    bool categoryChanged = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _editAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => CategorySelectionDialog(
                        isExpense: isExpense,
                        selectedCategory: selectedCategory,
                        onCategorySelected: (category) {
                          setState(() {
                            selectedCategory = category;
                            categoryChanged = category != transaction.category;
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
                        ...[
                          Icon(
                            isExpense
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
                SegmentedButton<bool>(
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
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      isExpense = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat.yMMMd().format(selectedDate),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _editNoteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (categoryChanged &&
                    transaction.note != null &&
                    transaction.note!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await DatabaseHelper.instance.addCategoryMapping(
                          CategoryMapping(
                            description: transaction.note!,
                            category: selectedCategory,
                          ),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Added mapping: ${transaction.note} → $selectedCategory'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding mapping: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                        'Add mapping: ${transaction.note} → $selectedCategory'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_editAmountController.text.isNotEmpty &&
                    double.tryParse(_editAmountController.text) != null) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final updatedTransaction = Transaction(
        id: transaction.id,
        amount: double.parse(_editAmountController.text),
        isExpense: isExpense,
        date: selectedDate,
        category: selectedCategory,
        note:
            _editNoteController.text.isEmpty ? null : _editNoteController.text,
      );

      await DatabaseHelper.instance.updateTransaction(updatedTransaction);
      await DatabaseHelper.instance.checkAndUpdateBudgets();
      _loadTransactions();
    }
  }

  Future<void> _checkInvalidTransactions() async {
    setState(() => _isLoading = true);

    // Get all transactions
    final allTransactions = await DatabaseHelper.instance.getAllTransactions();

    // Check for invalid transactions
    final invalidTransactions = allTransactions.where((transaction) {
      // Check if category exists in Constants
      if (transaction.isExpense) {
        if (!Constants.expenseCategories.contains(transaction.category)) {
          return true;
        }
      } else {
        if (!Constants.incomeCategories.contains(transaction.category)) {
          return true;
        }
      }

      // Check if amount is valid
      if (transaction.amount <= 0) {
        return true;
      }

      // Check if date is valid
      if (transaction.date.isAfter(DateTime.now())) {
        return true;
      }

      return false;
    }).toList();

    setState(() => _isLoading = false);

    if (invalidTransactions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No invalid transactions found'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // Show dialog with invalid transactions
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Transactions'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: invalidTransactions.length,
              itemBuilder: (context, index) {
                final transaction = invalidTransactions[index];
                return ListTile(
                  title: Text(
                    '${transaction.category} - ${NumberFormat.currency(symbol: '\$').format(transaction.amount)}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Date: ${DateFormat.yMMMd().format(transaction.date)}'),
                      if (transaction.note != null)
                        Text('Note: ${transaction.note}'),
                      Text(
                        'Issues: ${_getInvalidTransactionIssues(transaction)}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.pop(context);
                          _editTransaction(transaction);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await DatabaseHelper.instance
                              .deleteTransaction(transaction.id!);
                          _loadTransactions();
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction deleted'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ],
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

  String _getInvalidTransactionIssues(Transaction transaction) {
    final issues = <String>[];

    if (transaction.isExpense) {
      if (!Constants.expenseCategories.contains(transaction.category)) {
        issues.add('Invalid expense category');
      }
    } else {
      if (!Constants.incomeCategories.contains(transaction.category)) {
        issues.add('Invalid income category');
      }
    }

    if (transaction.amount <= 0) {
      issues.add('Invalid amount');
    }

    if (transaction.date.isAfter(DateTime.now())) {
      issues.add('Future date');
    }

    return issues.join(', ');
  }

  @override
  void dispose() {
    // Save current filter state
    _lastSelectedCategory = _selectedCategory;
    _lastIsExpense = _isExpense;
    _lastSearchText = _searchController.text;
    _lastSortBy = _sortBy;
    _lastSortAscending = _sortAscending;
    _lastSelectedMonth = _selectedMonth;
    
    _searchController.dispose();
    _editAmountController.dispose();
    _editNoteController.dispose();
    super.dispose();
  }
} 