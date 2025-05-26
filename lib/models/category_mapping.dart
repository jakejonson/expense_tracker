class CategoryMapping {
  final String keyword;
  final String category;

  CategoryMapping({
    required this.keyword,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'keyword': keyword,
      'category': category,
    };
  }

  factory CategoryMapping.fromMap(Map<String, dynamic> map) {
    return CategoryMapping(
      keyword: map['keyword'] as String,
      category: map['category'] as String,
    );
  }
}
