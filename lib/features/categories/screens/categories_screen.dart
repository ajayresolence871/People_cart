import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grocery_loading_view.dart';
import '../../home/widgets/search_bar_widget.dart';
import '../../../models/category.dart';
import '../../../services/product_service.dart';
import '../widgets/category_groups_widget.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final ValueChanged<Category>? onCategorySelected;
  final ProductCatalogDataSource? dataSource;

  const CategoriesScreen({super.key, this.onCategorySelected, this.dataSource});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final ProductCatalogDataSource _dataSource;
  List<Category>? _categories;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProductService();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await _dataSource.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories
            .where((category) => category.isActive)
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _handleCategoryTap(Category category) {
    if (widget.onCategorySelected != null) {
      widget.onCategorySelected!(category);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryProductsScreen(
            category: category,
            dataSource: _dataSource,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'All Categories',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentPink,
          onRefresh: _loadCategories,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              const SearchBarWidget(),
              const SizedBox(height: 8),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: GroceryLoadingView(
                      size: 130,
                      message: 'Loading categories…',
                    ),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Could not load categories: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadCategories,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              else
                CategoryGroupsWidget(
                  categories: _categories ?? const [],
                  onCategoryTap: _handleCategoryTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
