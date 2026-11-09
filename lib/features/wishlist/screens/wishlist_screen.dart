import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grocery_loading_view.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  WishlistProvider? _loadedProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wishlist = context.read<WishlistProvider>();
    if (_loadedProvider != wishlist) {
      _loadedProvider = wishlist;
      final force = wishlist.hasLoaded;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedProvider == wishlist) {
          wishlist.load(force: force);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    final cart = context.read<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Wishlist',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh wishlist',
            onPressed: wishlist.isLoading
                ? null
                : () => wishlist.load(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentPink,
        onRefresh: () => wishlist.load(force: true),
        child: _buildBody(context, wishlist, cart),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WishlistProvider wishlist,
    CartProvider cart,
  ) {
    if (wishlist.isLoading && !wishlist.hasLoaded) {
      return const _ScrollableMessage(
        child: GroceryLoadingView(
          size: 130,
          message: 'Loading your saved items…',
        ),
      );
    }

    if (wishlist.error != null &&
        (!wishlist.hasLoaded || wishlist.products.isEmpty)) {
      return _ScrollableMessage(
        child: _WishlistMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Wishlist could not be loaded',
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () => wishlist.load(force: true),
        ),
      );
    }

    if (wishlist.products.isEmpty) {
      final hasUnresolvedProducts = wishlist.productIds.isNotEmpty;
      return _ScrollableMessage(
        child: _WishlistMessage(
          icon: hasUnresolvedProducts
              ? Icons.sync_problem_rounded
              : Icons.favorite_border_rounded,
          title: hasUnresolvedProducts
              ? 'Saved products are unavailable'
              : 'Your wishlist is empty',
          message: hasUnresolvedProducts
              ? 'Refresh to load the latest catalog details.'
              : 'Tap the heart on a product to save it here.',
          actionLabel: hasUnresolvedProducts ? 'Refresh' : null,
          onAction: hasUnresolvedProducts
              ? () => wishlist.load(force: true)
              : null,
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (wishlist.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WishlistMessage(
              icon: Icons.error_outline_rounded,
              title: 'Refresh failed',
              message: wishlist.error!,
              actionLabel: 'Retry',
              onAction: () => wishlist.load(force: true),
            ),
          ),
        for (final product in wishlist.products)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WishlistProductCard(
              product: product,
              isRemoving: wishlist.isPending(product.id),
              onRemove: () =>
                  wishlist.toggleProduct(product.id, product: product),
              onAddToCart: () => _addToCart(context, cart, product),
            ),
          ),
      ],
    );
  }

  void _addToCart(BuildContext context, CartProvider cart, Product product) {
    final result = cart.addItem(product);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.isSuccess
              ? AppColors.badgeGreen
              : AppColors.primary,
        ),
      );
  }
}

class _WishlistProductCard extends StatelessWidget {
  final Product product;
  final bool isRemoving;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;

  const _WishlistProductCard({
    required this.product,
    required this.isRemoving,
    required this.onRemove,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isManuallyUnavailable = !product.isAvailable;
    final isInStock = product.isAvailable && product.stockQuantity > 0;
    final availabilityLabel = isManuallyUnavailable
        ? 'Unavailable'
        : isInStock
        ? 'In stock · ${product.stockQuantity} available'
        : 'Out of stock';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 76,
              height: 76,
              color: AppColors.giftBannerBg,
              child: product.imageUrl == null || product.imageUrl!.isEmpty
                  ? const Icon(
                      Icons.shopping_basket_outlined,
                      color: AppColors.primary,
                      size: 32,
                    )
                  : Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.shopping_basket_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
            ),
          ),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  availabilityLabel,
                  style: TextStyle(
                    color: isInStock
                        ? AppColors.badgeGreen
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: isInStock && !isRemoving ? onAddToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPink,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      isInStock
                          ? 'Add to Cart'
                          : isManuallyUnavailable
                          ? 'Unavailable'
                          : 'Out of stock',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove from wishlist',
            onPressed: isRemoving ? null : onRemove,
            icon: isRemoving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.accentPink,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableMessage extends StatelessWidget {
  final Widget child;

  const _ScrollableMessage({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _WishlistMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _WishlistMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.accentPink),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPink,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
