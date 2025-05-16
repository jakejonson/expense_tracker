import 'package:flutter/material.dart';

class Constants {
  static const List<String> categories = [
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

  static const Map<String, IconData> categoryIcons = {
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
    'Other': Icons.more_horiz,
  };

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