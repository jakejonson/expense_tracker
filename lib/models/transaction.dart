class Transaction {
  final int? id;
  final double amount;
  final bool isExpense;
  final DateTime date;
  final String category;
  final String? note;

  Transaction({
    this.id,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.category,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'isExpense': isExpense ? 1 : 0,
      'date': date.toIso8601String(),
      'category': category,
      'note': note,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: map['amount'],
      isExpense: map['isExpense'] == 1,
      date: DateTime.parse(map['date']),
      category: map['category'],
      note: map['note'],
    );
  }
} 