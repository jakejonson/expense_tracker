import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'category_grid.dart';

class CategorySelectionDialog extends StatelessWidget {
  final bool isExpense;
  final String? selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySelectionDialog({
    super.key,
    required this.isExpense,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories =
        isExpense ? Constants.expenseCategories : Constants.incomeCategories;

    return AlertDialog(
      title: Text('Select ${isExpense ? "Expense" : "Income"} Category'),
      content: SizedBox(
        width: double.maxFinite,
        child: CategoryGrid(
          categories: categories,
          isExpense: isExpense,
          selectedCategory: selectedCategory,
          onCategorySelected: (category) {
            onCategorySelected(category);
            Navigator.pop(context);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
