import 'package:flutter/material.dart';

class Constants {
  static List<String> expenseCategories = [
    'Groceries',
    'Rent',
    'Car',
    'Eating Out',
    'Entertainment',
    'Shopping',
    'Transportation',
    'Utilities',
    'Healthcare',
    'Education',
    'Other'
  ];

  static List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Government',
    'Tax Refund',
    'Other'
  ];

  static Map<String, IconData> categoryIcons = {
    // Expense icons
    'Groceries': Icons.shopping_basket,
    'Rent': Icons.home,
    'Car': Icons.directions_car,
    'Eating Out': Icons.restaurant,
    'Entertainment': Icons.movie,
    'Shopping': Icons.shopping_bag,
    'Transportation': Icons.directions_bus,
    'Utilities': Icons.power,
    'Healthcare': Icons.local_hospital,
    'Education': Icons.school,
    // Income icons
    'Salary': Icons.work,
    'Freelance': Icons.computer,
    'Government': Icons.account_balance,
    'Tax Refund': Icons.receipt_long,
    'Other': Icons.more_horiz,
  };

  static void addCategory(String category, bool isExpense) {
    if (isExpense) {
      if (!expenseCategories.contains(category)) {
        expenseCategories.add(category);
        categoryIcons[category] = Icons.category;
      }
    } else {
      if (!incomeCategories.contains(category)) {
        incomeCategories.add(category);
        categoryIcons[category] = Icons.category;
      }
    }
  }

  static void removeCategory(String category, bool isExpense) {
    if (isExpense) {
      expenseCategories.remove(category);
    } else {
      incomeCategories.remove(category);
    }
    categoryIcons.remove(category);
  }

  static const List<Color> chartColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.brown,
  ];

  static const List<String> periods = [
    'Week',
    'Month',
    'Quarter',
    'Year'
  ];
} 