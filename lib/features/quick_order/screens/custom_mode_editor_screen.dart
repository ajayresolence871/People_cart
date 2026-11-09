import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grocery_loading_view.dart';
import '../../../models/product.dart';
import '../../../services/product_service.dart';
import '../models/quick_order_mode.dart';
import '../providers/quick_order_provider.dart';

class CustomModeEditorScreen extends StatefulWidget {
  final QuickOrderMode? existingMode;

  const CustomModeEditorScreen({
    super.key,
    this.existingMode,
  });

  @override
  State<CustomModeEditorScreen> createState() => _CustomModeEditorScreenState();
}

class _CustomModeEditorScreenState extends State<CustomModeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final ProductService _productService = ProductService();

  // Selected products and quantities for this mode
  final Map<Product, int> _selectedItems = {};

  List<Product> _allCatalog = [];
  List<Product> _filteredCatalog = [];
  bool _isLoadingCatalog = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingMode != null) {
      _nameController.text = widget.existingMode!.name;
      for (final item in widget.existingMode!.items) {
        if (item.product != null) {
          _selectedItems[item.product!] = item.quantity;
        }
      }
    }
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final list = await _productService.getProducts();
      if (mounted) {
        setState(() {
          _allCatalog = list;
          _filteredCatalog = list;
          _isLoadingCatalog = false;

          // Re-bind any items from existing mode where product was matching by ID
          if (widget.existingMode != null && _selectedItems.isEmpty) {
            for (final item in widget.existingMode!.items) {
              final found = list.where((p) => p.id == item.productId).toList();
              if (found.isNotEmpty) {
                _selectedItems[found.first] = item.quantity;
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    final clean = query.trim().toLowerCase();
    setState(() {
      if (clean.isEmpty) {
        _filteredCatalog = _allCatalog;
      } else {
        _filteredCatalog = _allCatalog.where((p) {
          final nameMatch = p.name.toLowerCase().contains(clean);
          final descMatch = p.description?.toLowerCase().contains(clean) ?? false;
          return nameMatch || descMatch;
        }).toList();
      }
    });
  }

  void _addProduct(Product product) {
    setState(() {
      if (_selectedItems.containsKey(product)) {
        _selectedItems[product] = _selectedItems[product]! + 1;
      } else {
        _selectedItems[product] = 1;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${product.name}" to collection'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppColors.badgeGreen,
      ),
    );
  }

  void _incrementQty(Product product) {
    setState(() {
      _selectedItems[product] = (_selectedItems[product] ?? 1) + 1;
    });
  }

  void _decrementQty(Product product) {
    setState(() {
      final cur = _selectedItems[product] ?? 1;
      if (cur > 1) {
        _selectedItems[product] = cur - 1;
      } else {
        _selectedItems.remove(product);
      }
    });
  }

  String _getProductEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('chip') || lower.contains('turns')) return '🥨';
    if (lower.contains('juice') || lower.contains('orange')) return '🍊';
    if (lower.contains('coconut')) return '🥥';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('potato')) return '🥔';
    if (lower.contains('chilli')) return '🌶️';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('ice cream') || lower.contains('cup')) return '🍨';
    return '🥗';
  }

  double get _estimatedTotal {
    double sum = 0.0;
    for (final entry in _selectedItems.entries) {
      sum += entry.key.price * entry.value;
    }
    return sum;
  }

  Future<void> _saveMode() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one product for this collection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<QuickOrderProvider>();
    final name = _nameController.text.trim();
    bool success;

    if (widget.existingMode != null) {
      success = await provider.updateCustomMode(
        id: widget.existingMode!.id,
        name: name,
        items: _selectedItems,
        iconName: widget.existingMode!.iconName,
      );
    } else {
      success = await provider.createCustomMode(
        name: name,
        items: _selectedItems,
        iconName: 'custom',
      );
    }

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingMode != null
                ? 'Shortcut "$name" updated successfully!'
                : 'Shopping shortcut "$name" created!',
          ),
          backgroundColor: AppColors.badgeGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingMode != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Shopping Shortcut' : 'Create Custom Mode',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          // Mode name input header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SHORTCUT NAME',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Please enter a name for this collection' : null,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. My Breakfast, Office Snacks, Movie Night...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.normal),
                      prefixIcon: const Icon(Icons.bolt_rounded, color: AppColors.accentPink, size: 22),
                      filled: true,
                      fillColor: const Color(0xFFF9F7FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentPink, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected Products Summary Drawer
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.giftBannerBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedItems.length} ${_selectedItems.length == 1 ? "product" : "products"} selected',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ],
                  ),
                  Text(
                    '~₹${_estimatedTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ],
              ),
            ),

          // Search catalog input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products to add (e.g. milk, bread, chips)...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF6F4F8),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Catalog List & Selected Steppers
          Expanded(
            child: _isLoadingCatalog
                ? const Center(
                    child: GroceryLoadingView(
                      size: 110,
                      compact: true,
                      message: 'Loading products…',
                    ),
                  )
                : _filteredCatalog.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found matching search',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredCatalog.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _filteredCatalog[index];
                          final isSelected = _selectedItems.containsKey(product);
                          final qty = _selectedItems[product] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                // Thumbnail
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F6FA),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                        ? Image.network(
                                            product.imageUrl!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => Text(
                                              _getProductEmoji(product.name),
                                              style: const TextStyle(fontSize: 22),
                                            ),
                                          )
                                        : Text(
                                            _getProductEmoji(product.name),
                                            style: const TextStyle(fontSize: 22),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name and price
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${product.price.toStringAsFixed(0)} ${product.description != null ? "• ${product.description}" : ""}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Selection control: ADD button vs Stepper
                                if (!isSelected)
                                  ElevatedButton(
                                    onPressed: () => _addProduct(product),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentPinkSoft,
                                      foregroundColor: AppColors.accentPink,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                    child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  )
                                else
                                  Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPinkSoft,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.accentPink),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            qty == 1 ? Icons.delete_outline : Icons.remove,
                                            size: 14,
                                            color: AppColors.accentPink,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
                                          onPressed: () => _decrementQty(product),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.accentPink,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 14, color: AppColors.accentPink),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
                                          onPressed: () => _incrementQty(product),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Update Shortcut' : 'Save Shortcut (${_selectedItems.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
