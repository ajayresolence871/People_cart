import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/catalog_image.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/product_service.dart';
import '../../../services/customer_event_service.dart';
import '../../budget_guardian/utils/budget_dialog_helper.dart';
import '../../wishlist/widgets/wishlist_heart_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final List<Product>? similarProducts;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.similarProducts,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final int _currentImageIndex = 0;
  List<Product> _loadedSimilarProducts = [];
  bool _isLoadingSimilarProducts = false;
  String? _similarProductsError;

  @override
  void initState() {
    super.initState();
    logEventWithoutBlocking(
      CustomerEventService().logProductView(widget.product.id),
    );
    if (widget.similarProducts == null || widget.similarProducts!.isEmpty) {
      _loadSimilarProducts();
    }
  }

  Future<void> _loadSimilarProducts() async {
    final categoryId = widget.product.categoryId;
    if (categoryId == null || categoryId.isEmpty) return;
    setState(() {
      _isLoadingSimilarProducts = true;
      _similarProductsError = null;
    });
    try {
      final products = await ProductService().getProducts(
        categoryId: categoryId,
      );
      if (!mounted) return;
      setState(() {
        _loadedSimilarProducts = products
            .where(
              (product) =>
                  product.id != widget.product.id && product.isAvailable,
            )
            .toList();
        _isLoadingSimilarProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _similarProductsError = 'Could not load similar products.';
        _isLoadingSimilarProducts = false;
      });
    }
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
    if (lower.contains('curry') || lower.contains('turns')) return '🥨';
    if (lower.contains('mix') || lower.contains('party')) return '🥜';
    if (lower.contains('ice cream') || lower.contains('cup')) return '🍨';
    if (lower.contains('spot') ||
        lower.contains('serum') ||
        lower.contains('lotion')) {
      return '🧴';
    }
    return '🥗';
  }

  List<Product> _getSimilarProducts() {
    if (widget.similarProducts != null && widget.similarProducts!.isNotEmpty) {
      return widget.similarProducts!
          .where((p) => p.id != widget.product.id)
          .take(4)
          .toList();
    }
    return _loadedSimilarProducts.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.getQuantity(widget.product.id);
    final similarList = _getSimilarProducts();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable Content
            CustomScrollView(
              slivers: [
                // 1. Top Image Showcase & Overlay Controls (Matching Image 1)
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      // Image Showcase Container
                      Container(
                        height: 340,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9F9FA),
                        ),
                        child: Center(
                          child: CatalogImage(
                            imageUrl: widget.product.imageUrl,
                            fit: BoxFit.contain,
                            placeholder: Text(
                              _getProductEmoji(widget.product.name),
                              style: const TextStyle(fontSize: 110),
                            ),
                          ),
                        ),
                      ),

                      // Top App Bar Floating Buttons
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button
                            _buildCircleButton(
                              icon: Icons.chevron_left,
                              iconSize: 26,
                              onTap: () => Navigator.pop(context),
                            ),
                            // Search and Share Buttons
                            Row(
                              children: [
                                _buildCircleButton(
                                  icon: Icons.search,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Search triggered!'),
                                        duration: Duration(milliseconds: 600),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildCircleButton(
                                  icon: Icons.ios_share_outlined,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Product link copied!'),
                                        duration: Duration(milliseconds: 600),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Promotional Tagline on Image (top-right)
                      Positioned(
                        top: 70,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '100% FRESH',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange.shade800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                              'Farm to doorstep',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2B0938),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Rating Pill (Bottom-Left of image)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '4.8',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: AppColors.badgeGreen,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '|  1.2k',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Carousel Dots (Bottom-Center)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            final isActive = index == _currentImageIndex;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: isActive ? 14 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Wishlist Heart Button (Bottom-Right of image)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: WishlistHeartButton(
                          product: widget.product,
                          diameter: 44,
                          iconSize: 23,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Product Information Section (Matching Image 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag Chips Row
                        Row(
                          children: [
                            _buildTagChip('Fresh Produce'),
                            const SizedBox(width: 6),
                            _buildTagChip('Handpicked'),
                            const SizedBox(width: 6),
                            _buildTagChip('Daily Essential'),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Brand Name with subtle dotted style
                        const Text(
                          'People Cart Fresh',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Full Product Title
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Net Qty Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Net Qty: ${widget.product.description ?? '500 g'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pricing & Delivery Speed Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Price Badge & Discount
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.badgeGreen,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '₹${widget.product.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.product.discountPercentage}% Off',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.badgeGreen,
                                  ),
                                ),
                              ],
                            ),

                            // Delivery Speed Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F6ED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    size: 14,
                                    color: AppColors.badgeGreen,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    '10 mins',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.badgeGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Strikethrough MRP
                        Text(
                          '₹${widget.product.originalPrice.toStringAsFixed(0)} MRP (incl. of all taxes)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Divider(thickness: 6, color: Color(0xFFF4F4F6)),
                ),

                // 3. Similar Products Section (Matching Image 2 & 3)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Similar Products',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See all',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentPink,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: AppColors.accentPink,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Similar Products Horizontal List
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 230,
                    child: _isLoadingSimilarProducts
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentPink,
                            ),
                          )
                        : _similarProductsError != null
                        ? Center(
                            child: Text(
                              _similarProductsError!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : similarList.isEmpty
                        ? const Center(
                            child: Text(
                              'No similar products are available yet.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: similarList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final sim = similarList[index];
                              final simQty = cart.getQuantity(sim.id);

                              return Container(
                                width: 130,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image with ADD button
                                    Stack(
                                      children: [
                                        Container(
                                          height: 105,
                                          width: double.infinity,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF9F9FA),
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                          ),
                                          child: Center(
                                            child: CatalogImage(
                                              imageUrl: sim.imageUrl,
                                              fit: BoxFit.contain,
                                              placeholder: Text(
                                                _getProductEmoji(sim.name),
                                                style: const TextStyle(
                                                  fontSize: 44,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          left: 10,
                                          right: 10,
                                          child: cart.isOutOfStock(sim)
                                              ? InkWell(
                                                  onTap: () {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).hideCurrentSnackBar();
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${sim.name} is currently out of stock.',
                                                        ),
                                                        duration:
                                                            const Duration(
                                                              seconds: 1,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'OUT',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : simQty == 0
                                              ? InkWell(
                                                  onTap: () {
                                                    BudgetDialogHelper.checkAndAdd(
                                                      context: context,
                                                      itemPrice: sim.price,
                                                      onProceed: () =>
                                                          cart.addItem(sim),
                                                    );
                                                  },
                                                  child: Container(
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .accentPink,
                                                      ),
                                                    ),
                                                    child: const Center(
                                                      child: Text(
                                                        'ADD',
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .accentPink,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accentPink,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      InkWell(
                                                        onTap: () => cart
                                                            .removeSingleItem(
                                                              sim.id,
                                                            ),
                                                        child: const Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                              ),
                                                          child: Icon(
                                                            Icons.remove,
                                                            size: 14,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        '$simQty',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: () {
                                                          if (!cart
                                                              .canIncrement(
                                                                sim,
                                                              )) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).hideCurrentSnackBar();
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Cannot add more. Only ${sim.stockQuantity} in stock.',
                                                                ),
                                                                duration:
                                                                    const Duration(
                                                                      seconds:
                                                                          1,
                                                                    ),
                                                              ),
                                                            );
                                                            return;
                                                          }
                                                          BudgetDialogHelper.checkAndAdd(
                                                            context: context,
                                                            itemPrice:
                                                                sim.price,
                                                            onProceed: () =>
                                                                cart.addItem(
                                                                  sim,
                                                                ),
                                                          );
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                              ),
                                                          child: Icon(
                                                            Icons.add,
                                                            size: 14,
                                                            color:
                                                                cart.canIncrement(
                                                                  sim,
                                                                )
                                                                ? Colors.white
                                                                : Colors
                                                                      .white54,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sim.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            sim.description ?? '500 g',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                '₹${sim.price.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '₹${sim.originalPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.textMuted,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                            ],
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
                ),

                const SliverToBoxAdapter(
                  child: Divider(thickness: 6, color: Color(0xFFF4F4F6)),
                ),

                // 4. Ratings & Reviews Section (Matching Image 2 & 3)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ratings & Reviews',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Big Star Rating Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.badgeGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '4.8',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Ratings Count
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9FA),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text(
                                '11,965 Ratings | 2,410 Reviews',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Spacing for Floating Bar
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

            // 5. Persistent Bottom "Add to Cart" Bar (Matching Image 1, 2, 3)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: cart.isOutOfStock(widget.product)
                    ? SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${widget.product.name} is currently out of stock.',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.grey.shade600,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Out of Stock',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      )
                    : quantity == 0
                    ? SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            BudgetDialogHelper.checkAndAdd(
                              context: context,
                              itemPrice: widget.product.price,
                              onProceed: () => cart.addItem(widget.product),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.accentPink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Item in Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: () =>
                                      cart.removeSingleItem(widget.product.id),
                                ),
                                Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: cart.canIncrement(widget.product)
                                        ? Colors.white
                                        : Colors.white54,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    if (!cart.canIncrement(widget.product)) {
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Cannot add more. Only ${widget.product.stockQuantity} in stock.',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                      return;
                                    }
                                    BudgetDialogHelper.checkAndAdd(
                                      context: context,
                                      itemPrice: widget.product.price,
                                      onProceed: () =>
                                          cart.addItem(widget.product),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 20,
    Color iconColor = AppColors.textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
