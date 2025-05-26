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
    final keyword = _keywordController.text.trim().toUpperCase();
    final category = _categoryController.text.trim();

    if (keyword.isEmpty || category.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both keyword and category';
      });
      return;
    }

    try {
      final mapping = CategoryMapping(keyword: keyword, category: category);
      await _db.addCategoryMapping(mapping);
      _keywordController.clear();
      _categoryController.clear();
      await _loadMappings();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error adding mapping: ${e.toString()}';
      });
    }
  }

  Future<void> _deleteMapping(String keyword) async {
    try {
      await _db.deleteCategoryMapping(keyword);
      await _loadMappings();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error deleting mapping: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Mappings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _keywordController,
                        decoration: const InputDecoration(
                          labelText: 'Keyword',
                          hintText: 'Enter keyword to match',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'Enter category name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addMapping,
                        child: const Text('Add Mapping'),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
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
                        title: Text(mapping.keyword),
                        subtitle: Text(mapping.category),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteMapping(mapping.keyword),
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
