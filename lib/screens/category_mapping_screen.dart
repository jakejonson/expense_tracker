import 'package:flutter/material.dart';
import 'package:expense_tracker/models/category_mapping.dart';
import 'package:expense_tracker/services/database_helper.dart';
import 'package:expense_tracker/utils/constants.dart';

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
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadMappings();
  }

  @override
  void dispose() {
    _keywordController.dispose();
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
    if (_keywordController.text.isEmpty || _selectedCategory == null) {
      return;
    }

    final keyword = _keywordController.text;
    final category = _selectedCategory!;

    final mapping = CategoryMapping(description: keyword, category: category);
    await _db.addCategoryMapping(mapping);

    _keywordController.clear();
    setState(() {
      _selectedCategory = null;
    });
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
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Cat.',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...Constants.expenseCategories.map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 200,
                              child: Row(
                                children: [
                                  Icon(
                                      Constants.expenseCategoryIcons[category]),
                                  const SizedBox(width: 8),
                                  Text(category),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      ...Constants.incomeCategories.map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 200,
                              child: Row(
                                children: [
                                  Icon(Constants.incomeCategoryIcons[category]),
                                  const SizedBox(width: 8),
                                  Text(category),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
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
