import 'package:flutter/material.dart';
import '../utils/constants.dart';

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
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final icon = isExpense
                ? Constants.expenseCategoryIcons[category]
                : Constants.incomeCategoryIcons[category];

            return ListTile(
              leading: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(category),
              selected: category == selectedCategory,
              onTap: () {
                onCategorySelected(category);
                Navigator.pop(context);
              },
            );
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
