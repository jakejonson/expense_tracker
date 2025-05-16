class Budget {
  final int? id;
  final double amount;
  final String? category; // null means overall budget
  final DateTime startDate;
  final DateTime endDate;

  Budget({
    this.id,
    required this.amount,
    this.category,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      amount: map['amount'],
      category: map['category'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }
} 