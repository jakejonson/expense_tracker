class Transaction {
  final int? id;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final bool isExpense;
  final int isRecurring;
  final String? frequency;
  final int? originalTransactionId;
  final String? nextOccurrence;
  final DateTime? creationDate;

  Transaction({
    this.id,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    required this.isExpense,
    this.isRecurring = 0,
    this.frequency,
    this.originalTransactionId,
    this.nextOccurrence,
    this.creationDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'isExpense': isExpense ? 1 : 0,
      'isRecurring': isRecurring,
      'frequency': frequency,
      'originalTransactionId': originalTransactionId,
      'nextOccurrence': nextOccurrence,
      'creationDate': creationDate?.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      amount: map['amount'] as double,
      category: map['category'] as String,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      isExpense: map['isExpense'] == 1,
      isRecurring: map['isRecurring'] as int? ?? 0,
      frequency: map['frequency'] as String?,
      originalTransactionId: map['originalTransactionId'] as int?,
      nextOccurrence: map['nextOccurrence'] as String?,
      creationDate: map['creationDate'] != null
          ? DateTime.parse(map['creationDate'] as String)
          : null,
    );
  }
} 