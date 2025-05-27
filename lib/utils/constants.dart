import 'package:flutter/material.dart';

class Constants {
  static List<String> expenseCategories = [
    'Groceries',
    'Rent',
    'Car',
    'Eating Out',
    'Entertainment',
    'Sports',
    'Shopping',
    'Transportation',
    'Utilities',
    'Healthcare',
    'Education',
    'Tax',
    'Pet',
    'Saeid',
    'Travel',
    'Other',
  ];

  static List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Tax Refund',
    'Other'
  ];

  static Map<String, IconData> expenseCategoryIcons = {
    'Groceries': Icons.shopping_basket,
    'Rent': Icons.home,
    'Car': Icons.directions_car,
    'Sports': Icons.sports_gymnastics,
    'Eating Out': Icons.restaurant,
    'Entertainment': Icons.movie,
    'Shopping': Icons.shopping_bag,
    'Transportation': Icons.directions_bus,
    'Utilities': Icons.power,
    'Healthcare': Icons.local_hospital,
    'Education': Icons.school,
    'Pet': Icons.pets,
    'Tax': Icons.receipt_long,
    'Saeid': Icons.person,
    'Travel': Icons.flight,
    'Other': Icons.more_horiz,
  };

  static Map<String, IconData> incomeCategoryIcons = {
    'Salary': Icons.work,
    'Freelance': Icons.computer,
    'Tax Refund': Icons.receipt_long,
    'Other': Icons.more_horiz,
  };

  static void addCategory(String category, bool isExpense) {
    if (isExpense) {
      if (!expenseCategories.contains(category)) {
        expenseCategories.add(category);
        expenseCategoryIcons[category] = Icons.category;
      }
    } else {
      if (!incomeCategories.contains(category)) {
        incomeCategories.add(category);
        incomeCategoryIcons[category] = Icons.category;
      }
    }
  }

  static void removeCategory(String category, bool isExpense) {
    if (isExpense) {
      expenseCategories.remove(category);
    } else {
      incomeCategories.remove(category);
    }
    if (isExpense) {
      expenseCategoryIcons.remove(category);
    } else {
      incomeCategoryIcons.remove(category);
    }
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