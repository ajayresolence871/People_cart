import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grocery_loading_view.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/customer_event_service.dart';
import '../../../services/product_service.dart';
import '../../cart/screens/cart_checkout_screen.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import '../../budget_guardian/utils/budget_dialog_helper.dart';
import '../../wishlist/widgets/wishlist_heart_button.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _recentSearchesKey = 'pc_recent_searches';

  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  final CustomerEventLogger _eventLogger = CustomerEventService();

  List<Product> _allProducts = [];
  List<Product> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isLoading = true;
  String _currentQuery = '';

  final List<String> _trendingSearches = [
    'Milk',
    'Bread',
    'Bananas',
    'Tomatoes',
    'Eggs',
    'Chips',
    'Ice Cream',
    'Atta',
    'Coconut',
    'Lotion',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _currentQuery = widget.initialQuery!;
    }
    _loadProductsAndHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsAndHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_recentSearchesKey);
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _recentSearches = decoded.map((e) => e.toString()).toList();
      } else {
        _recentSearches = ['Fresh Bananas', 'Milk', 'Bread'];
      }

      final products = await _productService.getProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      _currentQuery = query.trim();
      if (_currentQuery.isEmpty) {
        _searchResults = [];
      } else {
        final q = _currentQuery.toLowerCase();
        _searchResults = _allProducts.where((p) {
          final matchName = p.name.toLowerCase().contains(q);
          final matchDesc = p.description?.toLowerCase().contains(q) ?? false;
          return matchName || matchDesc;
        }).toList();
      }
    });
  }

  void _onSearchSubmitted(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    _addToRecentSearches(clean);
    _performSearch(clean);
    logEventWithoutBlocking(
      _eventLogger.logSearch(clean, _searchResults.length),
    );
  }

  Future<void> _addToRecentSearches(String term) async {
    if (_recentSearches.contains(term)) {
      _recentSearches.remove(term);
    }
    _recentSearches.insert(0, term);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.sublist(0, 8);
    }
    setState(() {});

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recentSearchesKey, jsonEncode(_recentSearches));
    } catch (_) {}
  }

  Future<void> _clearRecentSearches() async {
    setState(() {
      _recentSearches.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }

  String _getProductEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('banana')) return '🍌';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('chip')) return '🥔';
    if (lower.contains('juice') || lower.contains('orange')) return '🍊';
    if (lower.contains('coconut')) return '🥥';
    if (lower.contains('dragon')) return '🐉';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('coriander')) return '🌿';
    if (lower.contains('potato')) return '🥔';
    if (lower.contains('chilli')) return '🌶️';
    if (lower.contains('ice cream') || lower.contains('cup')) return '🍨';
    if (lower.contains('lotion') || lower.contains('nivea')) return '🧴';
    return '🥗';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 46,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F4F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: widget.initialQuery == null,
            onChanged: _performSearch,
            onSubmitted: _onSearchSubmitted,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search "milk, bananas, chips..."',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: GroceryLoadingView(
                    size: 120,
                    compact: true,
                    message: 'Loading products…',
                  ),
                )
              : _currentQuery.isEmpty
              ? _buildEmptyQueryContent()
              : _buildSearchResults(),

          // Sticky Cart Bar if cart has items
          if (cart.totalQuantity > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildFloatingCartBar(cart),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY QUERY: RECENTS & TRENDING SEARCHES
  // ==========================================
  Widget _buildEmptyQueryContent() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Recent Searches section
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Recent Searches',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((term) {
              return ActionChip(
                backgroundColor: const Color(0xFFF7F5F9),
                side: BorderSide(color: Colors.grey.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                avatar: const Icon(
                  Icons.history,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                label: Text(
                  term,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                onPressed: () {
                  _searchController.text = term;
                  _onSearchSubmitted(term);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Trending Searches section
        const Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 18,
              color: Color(0xFFFF5722),
            ),
            SizedBox(width: 6),
            Text(
              'Trending Searches',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trendingSearches.map((term) {
            return ActionChip(
              backgroundColor: AppColors.giftBannerBg,
              side: const BorderSide(color: Color(0xFFE9DCF2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              avatar: const Icon(
                Icons.trending_up,
                size: 14,
                color: AppColors.primary,
              ),
              label: Text(
                term,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              onPressed: () {
                _searchController.text = term;
                _onSearchSubmitted(term);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Popular Quick categories banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF0F5), Color(0xFFFFE8EF)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accentPink.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('⚡', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Superfast 5-10 Mins Delivery',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '5,000+ daily essentials available at dark store price',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SEARCH RESULTS GRID
  // ==========================================
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6F4F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No products found for "$_currentQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try searching with generic terms like "milk", "bread", "banana", or check spelling.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Showing ${_searchResults.length} ${_searchResults.length == 1 ? 'result' : 'results'} for "$_currentQuery"',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final product = _searchResults[index];
              return _buildProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getQuantity(product.id);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              _getProductEmoji(product.name),
                              style: const TextStyle(fontSize: 48),
                            ),
                          )
                        : Text(
                            _getProductEmoji(product.name),
                            style: const TextStyle(fontSize: 48),
                          ),
                  ),
                  // Discount badge
                  if (product.discountPercentage > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.badgeGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${product.discountPercentage}% OFF',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: WishlistHeartButton(
                      product: product,
                      diameter: 34,
                      iconSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Product Name
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),

            // Weight/Unit or Desc
            if (product.description != null && product.description!.isNotEmpty)
              Text(
                product.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),

            const SizedBox(height: 8),

            // Price & Add Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (product.originalPrice > product.price)
                      Text(
                        '₹${product.originalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),

                // ADD Button / Stepper
                cart.isOutOfStock(product)
                    ? SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.name} is currently out of stock.',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      )
                    : qty == 0
                    ? SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            BudgetDialogHelper.checkAndAdd(
                              context: context,
                              itemPrice: product.price,
                              onProceed: () => cart.addItem(product),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPinkSoft,
                            foregroundColor: AppColors.accentPink,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                color: AppColors.accentPink,
                                width: 1,
                              ),
                            ),
                          ),
                          child: const Text(
                            'ADD',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : Container(
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
                              icon: const Icon(
                                Icons.remove,
                                size: 14,
                                color: AppColors.accentPink,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 32,
                              ),
                              onPressed: () =>
                                  cart.removeSingleItem(product.id),
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accentPink,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                size: 14,
                                color: cart.canIncrement(product)
                                    ? AppColors.accentPink
                                    : Colors.grey.shade400,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 32,
                              ),
                              onPressed: () {
                                if (!cart.canIncrement(product)) {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cannot add more. Only ${product.stockQuantity} in stock.',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                  return;
                                }
                                BudgetDialogHelper.checkAndAdd(
                                  context: context,
                                  itemPrice: product.price,
                                  onProceed: () => cart.addItem(product),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.accentPink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${cart.totalQuantity} items • ₹${cart.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    cart.isFreeDeliveryUnlocked
                        ? 'Free Delivery Unlocked!'
                        : 'Add items for free delivery',
                    style: TextStyle(
                      color: cart.isFreeDeliveryUnlocked
                          ? AppColors.badgeGreenLight
                          : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartCheckoutScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Text(
                  'View Cart',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
