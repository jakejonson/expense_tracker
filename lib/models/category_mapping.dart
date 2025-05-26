class CategoryMapping {
  final int? id;
  final String description;
  final String category;

  CategoryMapping({
    this.id,
    required this.description,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'category': category,
    };
  }

  factory CategoryMapping.fromMap(Map<String, dynamic> map) {
    return CategoryMapping(
      id: map['id'] as int,
      description: map['description'] as String,
      category: map['category'] as String,
    );
  }
}
