import 'package:flutter/material.dart';
import 'package:expense_tracker/models/category_mapping.dart';
import 'package:expense_tracker/services/database_helper.dart';

class CategoryMappingScreen extends StatefulWidget {
  const CategoryMappingScreen({super.key});

  @override
  State<CategoryMappingScreen> createState() => _CategoryMappingScreenState();
}

class _CategoryMappingScreenState extends State<CategoryMappingScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<CategoryMapping> _mappings = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _keywordController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMappings();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadMappings() async {
    try {
      final mappings = await _db.getCategoryMappings();
      setState(() {
        _mappings = mappings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading mappings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _addMapping() async {
    if (_keywordController.text.isEmpty || _categoryController.text.isEmpty) {
      return;
    }

    final keyword = _keywordController.text;
    final category = _categoryController.text;

    final mapping = CategoryMapping(description: keyword, category: category);
    await _db.addCategoryMapping(mapping);

    _keywordController.clear();
    _categoryController.clear();
    _loadMappings();
  }

  Future<void> _deleteMapping(String description) async {
    await _db.deleteCategoryMapping(description);
    _loadMappings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Mappings'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _addMapping,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _mappings.length,
              itemBuilder: (context, index) {
                final mapping = _mappings[index];
                return ListTile(
                  title: Text(mapping.description),
                  subtitle: Text(mapping.category),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteMapping(mapping.description),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
