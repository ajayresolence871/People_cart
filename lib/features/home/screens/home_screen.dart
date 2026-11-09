import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../services/product_service.dart';
import '../widgets/delivery_header.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/gift_banner.dart';
import '../widgets/category_selector.dart';
import '../widgets/product_card.dart';
import '../widgets/steal_deals_section.dart';
import '../widgets/zepto_footer.dart';
import '../widgets/shop_by_category_section.dart';
import '../services/fresh_produce_selector.dart';
import '../../categories/screens/category_products_screen.dart';
import '../../address/widgets/address_selector_bottom_sheet.dart';
import '../../profile/screens/profile_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../quick_order/widgets/quick_order_modes_section.dart';
import '../../wishlist/screens/wishlist_screen.dart';
import '../../../providers/auth_provider.dart';
import '../providers/customer_order_tracking_provider.dart';
import '../models/customer_order_tracking.dart';
import 'order_tracking_screen.dart';
import '../../../core/widgets/grocery_loading_view.dart';
import '../widgets/customer_order_tracking_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCategories;
  final VoidCallback? onNavigateToCart;

  const HomeScreen({
    super.key,
    this.onNavigateToCategories,
    this.onNavigateToCart,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();

  List<Category> _categories = [];
  List<Product> _products = [];
  List<Product> _filteredProducts = [];

  String? _selectedCategoryId;
  bool _isLoading = true;
  String? _errorMessage;
  String? _trackingUserId;
  bool _hasInitializedTrackingIdentity = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<Object>([
        _productService.getCategories(),
        _productService.getProducts(),
      ]);
      final categories = results[0] as List<Category>;
      final products = results[1] as List<Product>;

      if (mounted) {
        _categories = categories;
        _products = products;
        _isLoading = false;
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not load products. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshActiveOrder() async {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final trackingProvider = Provider.of<CustomerOrderTrackingProvider?>(
      context,
      listen: false,
    );
    if (trackingProvider == null) return;
    await trackingProvider.refresh(userId: auth?.user?.id ?? auth?.profile?.id);
  }

  Future<void> _refreshHome() async {
    await Future.wait([_loadData(), _refreshActiveOrder()]);
  }

  Future<void> _openOrderTracking(
    CustomerOrderTracking order,
    String? userId,
  ) async {
    final trackingProvider = Provider.of<CustomerOrderTrackingProvider?>(
      context,
      listen: false,
    );
    if (trackingProvider == null || userId == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(
          orderId: order.id,
          userId: userId,
          provider: trackingProvider,
        ),
      ),
    );
    if (mounted) await _refreshActiveOrder();
  }

  void _onCategorySelected(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _applyFilters();
    });
  }

  void _onSearchChanged(String query) {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = selectFreshProduce(
        categories: _categories,
        products: _products,
        categoryId: _selectedCategoryId,
        query: _searchController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider?>(context);
    final userId = auth?.user?.id ?? auth?.profile?.id;
    if (!_hasInitializedTrackingIdentity || _trackingUserId != userId) {
      _hasInitializedTrackingIdentity = true;
      _trackingUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshActiveOrder();
      });
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentPink,
          onRefresh: _refreshHome,
          child: CustomScrollView(
            slivers: [
              // Top Delivery Location Bar
              SliverToBoxAdapter(
                child: DeliveryHeader(
                  onAddressTap: () => AddressSelectorBottomSheet.show(context),
                  onProfileTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  onWishlistTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WishlistScreen()),
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: SearchBarWidget(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: ActiveOrderTrackingSection(
                  userId: userId,
                  onTrackOrder: (order) => _openOrderTracking(order, userId),
                ),
              ),

              // Referral / Free Gift Banner
              const SliverToBoxAdapter(child: GiftBanner()),

              // Loading State
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: GroceryLoadingView(
                      message: 'Fetching fresh groceries for you…',
                      subtitle: 'Getting the freshest items & everyday essentials',
                    ),
                  ),
                )
              // Error State
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPink,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              // Content: Quick-Order Modes + Fresh Section + Steal Deals + Shop by Category + Footer
              else ...[
                // Quick-Order Modes Section (Above FRESH @ ?5)
                SliverToBoxAdapter(
                  child: QuickOrderModesSection(catalog: _products),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Category Selector & 'FRESH @₹5' Section
                SliverToBoxAdapter(
                  child: CategorySelector(
                    categories: freshProduceCategories(_categories),
                    selectedCategoryId: _selectedCategoryId,
                    onSelectCategory: _onCategorySelected,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Horizontal Product Carousel (Zepto style)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 236,
                    child: _filteredProducts.isEmpty
                        ? const Center(
                            child: Text(
                              'No products found in this category',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            itemCount: _filteredProducts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              return ProductCard(product: product);
                            },
                          ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(thickness: 6, color: Color(0xFFF4F4F6)),
                  ),
                ),

                // 'Steal Deals' Section (below the Fresh section)
                SliverToBoxAdapter(
                  child: StealDealsSection(baseProducts: _products),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(thickness: 6, color: Color(0xFFF4F4F6)),
                  ),
                ),

                // Shop by Category Section (5-column responsive grid matching reference)
                SliverToBoxAdapter(
                  child: ShopByCategorySection(
                    categories: _categories,
                    onCategoryTap: (item) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryProductsScreen(
                            category: item,
                            initialProducts: _products,
                          ),
                        ),
                      );
                    },
                    onSeeAllTap: widget.onNavigateToCategories,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Branded Promotional Footer
                SliverToBoxAdapter(
                  child: BrandedPromotionalFooter(
                    onSeeAllTap: widget.onNavigateToCategories,
                  ),
                ),

                // Bottom padding to avoid overlapping the sticky cart bar
                const SliverToBoxAdapter(child: SizedBox(height: 2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
