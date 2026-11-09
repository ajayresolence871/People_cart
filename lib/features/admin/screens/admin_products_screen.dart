import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/catalog_image.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_product_provider.dart';
import '../services/admin_dashboard_service.dart';
import '../services/admin_product_service.dart';

enum _InventoryFilter { all, available, lowStock, outOfStock }

class AdminProductsScreen extends StatelessWidget {
  final AdminProductDataSource? dataSource;

  const AdminProductsScreen({super.key, this.dataSource});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.profile == null ||
        auth.role != 'admin') {
      return const Center(
        child: Text(
          'Admin access required.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) =>
          AdminProductProvider(dataSource: dataSource ?? AdminProductService())
            ..load(),
      child: const _AdminProductsContent(),
    );
  }
}

class _AdminProductsContent extends StatefulWidget {
  const _AdminProductsContent();

  @override
  State<_AdminProductsContent> createState() => _AdminProductsContentState();
}

class _AdminProductsContentState extends State<_AdminProductsContent> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId;
  _InventoryFilter _filter = _InventoryFilter.all;
  int _selectedTabIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filteredProducts(
    List<Product> products,
    Map<String, Category> categories,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return products.where((product) {
      final matchesName = product.name.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategoryId == null ||
          product.categoryId == _selectedCategoryId;
      final matchesFilter = switch (_filter) {
        _InventoryFilter.all => true,
        _InventoryFilter.available =>
          product.isAvailable && product.stockQuantity > 0,
        _InventoryFilter.lowStock =>
          product.stockQuantity > 0 &&
              product.stockQuantity <= AdminDashboardService.lowStockThreshold,
        _InventoryFilter.outOfStock => product.stockQuantity <= 0,
      };
      return matchesName && matchesCategory && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProductProvider>();
    final products = provider.products;
    final categories = provider.categories;
    final categoryById = {
      for (final category in categories ?? <Category>[]) category.id: category,
    };

    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage catalog details and on-hand stock.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh products',
                        onPressed: provider.isLoading ? null : provider.load,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InventoryTabSwitcher(
                    selectedIndex: _selectedTabIndex,
                    onSelected: (index) =>
                        setState(() => _selectedTabIndex = index),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedTabIndex == 1)
                    if (categories == null && provider.isLoading)
                      const _InventoryLoading()
                    else if (categories == null)
                      _InventoryError(
                        message:
                            provider.loadError ??
                            'Categories could not be loaded.',
                        onRetry: provider.load,
                      )
                    else
                      _CategoryManagementSection(
                        categories: categories,
                        isSaving: provider.isSaving,
                        error: provider.categoryError ?? provider.loadError,
                        onCreate: () => _openCategoryForm(context, provider),
                        onRename: (category) => _openCategoryForm(
                          context,
                          provider,
                          category: category,
                        ),
                        onDeactivate: (category) => _confirmDeactivateCategory(
                          context,
                          provider,
                          category,
                        ),
                      )
                  else ...[
                    if (products != null)
                      _InventorySummaryCards(
                        products: products,
                        selectedFilter: _filter,
                        onSelected: (filter) =>
                            setState(() => _filter = filter),
                      ),
                    if (products != null) const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed:
                            categories == null ||
                                !categories.any((category) => category.isActive)
                            ? null
                            : () => _openProductForm(
                                context,
                                provider,
                                categories,
                              ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add product'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentPink,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (provider.isLoading && products == null)
                      const _InventoryLoading()
                    else if (provider.loadError != null && products == null)
                      _InventoryError(
                        message: provider.loadError!,
                        onRetry: provider.load,
                      )
                    else if (products != null && categories != null) ...[
                      if (provider.loadError != null)
                        _InventoryInlineError(message: provider.loadError!),
                      if (!categories.any((category) => category.isActive))
                        const _InventoryInlineError(
                          message: 'No active categories are available. Create or reactivate a category before adding products.',
                        ),
                      _InventoryFilters(
                        searchController: _searchController,
                        categories: categories,
                        selectedCategoryId: _selectedCategoryId,
                        selectedFilter: _filter,
                        onSearchChanged: (_) => setState(() {}),
                        onCategoryChanged: (value) =>
                            setState(() => _selectedCategoryId = value),
                        onFilterChanged: (value) =>
                            setState(() => _filter = value),
                      ),
                      const SizedBox(height: 14),
                      if (provider.isLoading)
                        const LinearProgressIndicator(
                          color: AppColors.accentPink,
                        ),
                      if (products.isEmpty)
                        const _InventoryEmpty(
                          message: 'No products are in the catalog yet.',
                        )
                      else
                        _ProductGrid(
                          products: _filteredProducts(products, categoryById),
                          categories: categoryById,
                          onEdit: (product) => _openProductForm(
                            context,
                            provider,
                            categories,
                            product,
                          ),
                        ),
                      if (products.isNotEmpty &&
                          _filteredProducts(products, categoryById).isEmpty)
                        const _InventoryEmpty(
                          message: 'No products match these filters.',
                        ),
                    ] else if (provider.isLoading)
                      const _InventoryLoading()
                    else
                      _InventoryError(
                        message: 'Product data is incomplete. Refresh to try loading products and categories again.',
                        onRetry: provider.load,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductForm(
    BuildContext context,
    AdminProductProvider provider,
    List<Category> categories, [
    Product? product,
  ]) async {
    final selectableCategories = categories
        .where(
          (category) => category.isActive || category.id == product?.categoryId,
        )
        .toList();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ProductFormDialog(
        categories: selectableCategories,
        product: product,
        onSave: provider.save,
      ),
    );
    if (!mounted || !context.mounted || saved != true) return;
    Provider.of<AdminDashboardProvider?>(
      context,
      listen: false,
    )?.loadDashboard();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          product == null ? 'Product created.' : 'Product updated.',
        ),
        backgroundColor: AppColors.badgeGreen,
      ),
    );
  }

  Future<void> _openCategoryForm(
    BuildContext context,
    AdminProductProvider provider, {
    Category? category,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(
        category: category,
        onSave: (name, imageUrl) => provider.saveCategory(
          name,
          categoryId: category?.id,
          imageUrl: imageUrl,
        ),
      ),
    );
    if (!mounted || !context.mounted || saved != true) return;
    final refreshError = provider.categoryError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          refreshError ??
              (category == null ? 'Category created.' : 'Category renamed.'),
        ),
        backgroundColor: refreshError == null
            ? AppColors.badgeGreen
            : AppColors.accentPink,
      ),
    );
  }

  Future<void> _confirmDeactivateCategory(
    BuildContext context,
    AdminProductProvider provider,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate category?'),
        content: Text(
          '${category.name} will be hidden from customer browsing. Existing products and orders will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPink,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (!mounted || !context.mounted || confirmed != true) return;
    try {
      await provider.deactivateCategory(category.id);
      if (!mounted || !context.mounted) return;
      final refreshError = provider.categoryError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refreshError ?? 'Category deactivated.'),
          backgroundColor: refreshError == null
              ? AppColors.badgeGreen
              : AppColors.accentPink,
        ),
      );
    } catch (error) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not deactivate category: $error'),
          backgroundColor: AppColors.accentPink,
        ),
      );
    }
  }
}

class _InventoryTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _InventoryTabSwitcher({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('Products', Icons.inventory_2_outlined),
      ('Categories', Icons.category_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.giftBannerBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            Expanded(
              child: _InventoryTabButton(
                key: ValueKey('inventory-tab-$index'),
                title: tabs[index].$1,
                icon: tabs[index].$2,
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InventoryTabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _InventoryTabButton({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.white : Colors.transparent,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? AppColors.cardBorder : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryManagementSection extends StatelessWidget {
  final List<Category> categories;
  final bool isSaving;
  final String? error;
  final VoidCallback onCreate;
  final ValueChanged<Category> onRename;
  final ValueChanged<Category> onDeactivate;

  const _CategoryManagementSection({
    required this.categories,
    required this.isSaving,
    required this.error,
    required this.onCreate,
    required this.onRename,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final active = categories.where((category) => category.isActive).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$active active · ${categories.length - active} inactive',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: isSaving ? null : onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add category'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          _InventoryInlineError(message: error!),
        ],
        if (isSaving)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(color: AppColors.accentPink),
          ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const _InventoryEmpty(message: 'No categories have been created yet.')
        else
          ...categories.map(
            (category) => Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              child: ListTile(
                minLeadingWidth: 40,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                leading: CircleAvatar(
                  radius: 19,
                  backgroundColor: category.isActive
                      ? AppColors.giftBannerBg
                      : AppColors.cardBorder,
                  child: ClipOval(
                    child: category.imageUrl?.trim().isNotEmpty == true
                        ? CatalogImage(
                            imageUrl: category.imageUrl,
                            placeholder: Icon(
                              Icons.category_outlined,
                              color: category.isActive
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.category_outlined,
                            color: category.isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                  ),
                ),
                title: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(category.isActive ? 'Active' : 'Inactive'),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      tooltip: 'Rename ${category.name}',
                      onPressed: isSaving ? null : () => onRename(category),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (category.isActive)
                      IconButton(
                        tooltip: 'Deactivate ${category.name}',
                        onPressed: isSaving
                            ? null
                            : () => onDeactivate(category),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.visibility_off_outlined,
                          color: AppColors.accentPink,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final Category? category;
  final Future<Category> Function(String name, String? imageUrl) onSave;

  const _CategoryFormDialog({required this.category, required this.onSave});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _imageUrlController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _imageUrlController = TextEditingController(
      text: widget.category?.imageUrl ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _nameController.text,
        _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF3EAF3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.category == null ? 'Add category' : 'Edit category',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('category-name'),
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 80,
                  decoration: _categoryInputDecoration('Category name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Category name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('category-image-url'),
                  controller: _imageUrlController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.url,
                  decoration: _categoryInputDecoration(
                    'Category image URL (optional)',
                    prefixIcon: const Icon(Icons.image_outlined, size: 19),
                  ),
                  validator: _validateImageUrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use a publicly accessible https image URL.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (_imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 76,
                      height: 76,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: CatalogImage(
                        imageUrl: _imageUrlController.text,
                        fit: BoxFit.cover,
                        placeholder: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.accentPink),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentPink,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(_isSaving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateImageUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      return 'Enter a valid https image URL.';
    }
    return null;
  }

  InputDecoration _categoryInputDecoration(
    String label, {
    Widget? prefixIcon,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFD2C7D3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFD2C7D3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}

class _InventorySummaryCards extends StatelessWidget {
  final List<Product> products;
  final _InventoryFilter selectedFilter;
  final ValueChanged<_InventoryFilter> onSelected;

  const _InventorySummaryCards({
    required this.products,
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final counts =
        <({String label, int count, IconData icon, _InventoryFilter filter})>[
          (
            label: 'Total products',
            count: products.length,
            icon: Icons.inventory_2_outlined,
            filter: _InventoryFilter.all,
          ),
          (
            label: 'Available',
            count: products
                .where(
                  (product) => product.isAvailable && product.stockQuantity > 0,
                )
                .length,
            icon: Icons.check_circle_outline_rounded,
            filter: _InventoryFilter.available,
          ),
          (
            label: 'Low stock',
            count: products
                .where(
                  (product) =>
                      product.stockQuantity > 0 &&
                      product.stockQuantity <=
                          AdminDashboardService.lowStockThreshold,
                )
                .length,
            icon: Icons.warning_amber_rounded,
            filter: _InventoryFilter.lowStock,
          ),
          (
            label: 'Out of stock',
            count: products
                .where((product) => product.stockQuantity <= 0)
                .length,
            icon: Icons.remove_shopping_cart_outlined,
            filter: _InventoryFilter.outOfStock,
          ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 480 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: counts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 68,
          ),
          itemBuilder: (context, index) {
            final item = counts[index];
            final selected = selectedFilter == item.filter;
            return Material(
              color: selected ? AppColors.giftBannerBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(item.filter),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        color: selected
                            ? AppColors.primary
                            : AppColors.accentPink,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.count}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InventoryFilters extends StatelessWidget {
  final TextEditingController searchController;
  final List<Category> categories;
  final String? selectedCategoryId;
  final _InventoryFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_InventoryFilter> onFilterChanged;

  const _InventoryFilters({
    required this.searchController,
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final search = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search product name',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            );
            final category = DropdownButtonFormField<String>(
              initialValue: selectedCategoryId ?? '',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Category',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All categories'),
                ),
                ...categories.map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.id,
                    child: Text(entry.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => onCategoryChanged(
                value == null || value.isEmpty ? null : value,
              ),
            );
            if (!wide) {
              return Column(
                children: [search, const SizedBox(height: 10), category],
              );
            }
            return Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 12),
                Expanded(child: category),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _filterChip('All', _InventoryFilter.all),
            _filterChip('Available', _InventoryFilter.available),
            _filterChip('Low Stock', _InventoryFilter.lowStock),
            _filterChip('Out of Stock', _InventoryFilter.outOfStock),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, _InventoryFilter filter) {
    final selected = selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onFilterChanged(filter),
      selectedColor: AppColors.giftBannerBg,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.25)
            : AppColors.cardBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Map<String, Category> categories;
  final ValueChanged<Product> onEdit;

  const _ProductGrid({
    required this.products,
    required this.categories,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _InventoryEmpty(message: 'No products match these filters.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: products
              .map(
                (product) => SizedBox(
                  width: width,
                  child: _ProductCard(
                    product: product,
                    categoryName: categories[product.categoryId]?.name,
                    onEdit: () => onEdit(product),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String? categoryName;
  final VoidCallback onEdit;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = product.stockQuantity <= 0;
    final available = product.isAvailable && !isOut;
    final statusColor = !product.isAvailable
        ? AppColors.textSecondary
        : isOut
        ? AppColors.accentPink
        : product.stockQuantity <= AdminDashboardService.lowStockThreshold
        ? AppColors.accentPink
        : AppColors.badgeGreen;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _ProductImage(url: product.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  categoryName ?? 'Uncategorized',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${product.stockQuantity} in stock',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    !product.isAvailable && isOut
                        ? 'Unavailable · Out of stock'
                        : !product.isAvailable
                        ? 'Unavailable'
                        : isOut
                        ? 'Out of stock'
                        : available
                        ? 'Available'
                        : 'Unavailable',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit ${product.name}',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;

  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 72,
        color: AppColors.giftBannerBg,
        child: url == null || url!.trim().isEmpty
            ? const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.primary,
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final List<Category> categories;
  final Product? product;
  final Future<Product> Function(Product product) onSave;

  const _ProductFormDialog({
    required this.categories,
    required this.product,
    required this.onSave,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _imageUrlController;
  String? _categoryId;
  bool _isAvailable = true;
  bool _isSaving = false;
  String? _saveError;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toString(),
    );
    _stockController = TextEditingController(
      text: product?.stockQuantity.toString() ?? '0',
    );
    _imageUrlController = TextEditingController(text: product?.imageUrl ?? '');
    _categoryId = product?.categoryId;
    _isAvailable = product?.isAvailable ?? true;
    if (_categoryId != null &&
        !widget.categories.any((category) => category.id == _categoryId)) {
      _categoryId = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    final price = double.tryParse(value?.trim() ?? '');
    if (price == null || !price.isFinite || price <= 0) {
      return 'Enter a price greater than zero.';
    }
    return null;
  }

  String? _validateStock(String? value) {
    final quantity = int.tryParse(value?.trim() ?? '');
    if (quantity == null || quantity < 0) {
      return 'Enter a whole number of zero or more.';
    }
    return null;
  }

  String? _validateImageUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      return 'Enter a valid https image URL.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _saveError = 'Select a category.');
      return;
    }

    final existing = widget.product;
    final product = Product(
      id: existing?.id ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      categoryId: _categoryId,
      stockQuantity: int.parse(_stockController.text.trim()),
      isAvailable: _isAvailable,
      createdAt: existing?.createdAt,
    );

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(product);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      backgroundColor: const Color(0xFFF3EAF3),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit product' : 'Add product',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFD9CCD9)),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  children: [
                    _textField(
                      controller: _nameController,
                      fieldKey: const ValueKey('product-name'),
                      label: 'Product name *',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Product name is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _descriptionController,
                      fieldKey: const ValueKey('product-description'),
                      label: 'Description',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final price = _textField(
                          controller: _priceController,
                          fieldKey: const ValueKey('product-price'),
                          label: 'Price (₹) *',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _validatePrice,
                        );
                        final stock = _textField(
                          controller: _stockController,
                          fieldKey: const ValueKey('product-stock'),
                          label: 'Stock quantity *',
                          keyboardType: TextInputType.number,
                          validator: _validateStock,
                        );
                        if (constraints.maxWidth < 390) {
                          return Column(
                            children: [
                              price,
                              const SizedBox(height: 12),
                              stock,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: price),
                            const SizedBox(width: 12),
                            Expanded(child: stock),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Select a category.' : null,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _categoryId = value),
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _imageUrlController,
                      fieldKey: const ValueKey('product-image-url'),
                      label: 'Product image URL (optional)',
                      keyboardType: TextInputType.url,
                      validator: _validateImageUrl,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Use a publicly accessible https image URL. Device file paths cannot be displayed to customers.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isAvailable,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _isAvailable = value),
                      activeThumbColor: AppColors.badgeGreen,
                      title: const Text(
                        'Available in customer catalog',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_saveError != null)
                      _InventoryInlineError(message: _saveError!),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFD9CCD9)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                width < 500 ? 16 : 20,
                12,
                width < 500 ? 16 : 20,
                16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Create product'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    Key? fieldKey,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFBF9FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD2C7D3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD2C7D3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _InventoryLoading extends StatelessWidget {
  const _InventoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.accentPink),
      ),
    );
  }
}

class _InventoryEmpty extends StatelessWidget {
  final String message;

  const _InventoryEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _InventoryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InventoryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InventoryInlineError(message: message),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }
}

class _InventoryInlineError extends StatelessWidget {
  final String message;

  const _InventoryInlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.accentPinkSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
    );
  }
}
