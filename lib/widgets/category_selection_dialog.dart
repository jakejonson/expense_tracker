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
    final categories = [
      'All',
      ...(isExpense ? Constants.expenseCategories : Constants.incomeCategories)
    ];
    
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            CategoryGrid(
              categories: categories,
              isExpense: isExpense,
              selectedCategory: selectedCategory,
              onCategorySelected: (category) {
                onCategorySelected(category == 'All' ? '' : category);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
