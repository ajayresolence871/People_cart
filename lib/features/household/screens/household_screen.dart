import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/catalog_image.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/product_service.dart';
import '../../cart/screens/cart_checkout_screen.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import '../models/household.dart';
import '../models/shared_basket_item.dart';
import '../providers/household_provider.dart';

class HouseholdScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCategories;

  const HouseholdScreen({super.key, this.onNavigateToCategories});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final TextEditingController _sharedSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HouseholdProvider>().loadHouseholdData();
      }
    });
  }

  @override
  void dispose() {
    _sharedSearchController.dispose();
    super.dispose();
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
    if (lower.contains('oil') || lower.contains('rice')) return '🌾';
    return '🥗';
  }

  @override
  Widget build(BuildContext context) {
    final householdProvider = context.watch<HouseholdProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            _buildHeader(context, householdProvider),

            // Family Shared Basket Content
            Expanded(child: _buildFamilyTab(context, householdProvider)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER
  // ==========================================
  Widget _buildHeader(
    BuildContext context,
    HouseholdProvider householdProvider,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.giftBannerBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Household',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Shop together, save together',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Top-right actions
          if (householdProvider.hasHousehold)
            PopupMenuButton<String>(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FA),
                  border: Border.all(color: const Color(0xFFEADBEE)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              onSelected: (value) {
                if (value == 'create') {
                  _showCreateHouseholdDialog(context);
                } else if (value == 'join') {
                  _showJoinHouseholdDialog(context);
                } else if (value == 'refresh') {
                  householdProvider.loadHouseholdData();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_home_rounded,
                        size: 18,
                        color: AppColors.accentPink,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Create New Household',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'join',
                  child: Row(
                    children: [
                      Icon(
                        Icons.vpn_key_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Join Another Household',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 18,
                        color: AppColors.badgeGreen,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Refresh Shared Basket',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: () => _showCreateHouseholdDialog(context),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accentPinkSoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.accentPink,
              ),
              label: const Text(
                'Create',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED FAMILY TAB
  // ==========================================
  Widget _buildFamilyTab(BuildContext context, HouseholdProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPink),
      );
    }

    if (provider.errorMessage != null && !provider.hasHousehold) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.accentPink,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load your household',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: provider.loadHouseholdData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!provider.hasHousehold) {
      return _buildNoHouseholdEmptyState(context);
    }

    final household = provider.household!;
    final items = provider.filteredSharedItems;
    final totalItemsCount = provider.sharedItems.length;

    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: () => provider.loadHouseholdData(),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              children: [
                // 1. Household Summary Card
                _buildHouseholdSummaryCard(context, household),

                const SizedBox(height: 14),

                // 2. Search Field
                _buildSearchInput(
                  controller: _sharedSearchController,
                  hintText: 'Search in household basket...',
                  onChanged: (val) => provider.setSearchQuery(val),
                  onClear: () {
                    _sharedSearchController.clear();
                    provider.setSearchQuery('');
                  },
                ),

                const SizedBox(height: 16),

                // 3. Shared Basket Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Shared Basket',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentPinkSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$totalItemsCount items',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentPink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Items added by all members',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Upgraded "+ Add Items" Button
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () =>
                            _showAddProductsBottomSheet(context, provider),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.04,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Add items',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Product Rows or Empty Basket State
                if (items.isEmpty)
                  _buildSharedBasketEmptyState(context, provider)
                else
                  ...items.map(
                    (item) => _buildSharedProductRow(context, provider, item),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // 5. Estimated Basket Total & Review Button
          if (provider.sharedItems.isNotEmpty)
            _buildSharedBasketFooter(context, provider),
        ],
      ),
    );
  }

  Widget _buildHouseholdSummaryCard(BuildContext context, Household household) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEADBEE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A154B), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      household.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _buildMemberAvatarStack(household.memberCount),
                        const SizedBox(width: 8),
                        Text(
                          '${household.memberCount} ${household.memberCount == 1 ? 'member' : 'members'} active',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0EBF4)),
          const SizedBox(height: 12),
          // Join Code row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HOUSEHOLD JOIN CODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      household.joinCode.isNotEmpty
                          ? household.joinCode
                          : 'PC-FAMILY',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Upgraded Copy Code Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: household.joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Join code "${household.joinCode}" copied to clipboard!',
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.badgeGreen,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EAF8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0D0EC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Copy Code',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatarStack(int count) {
    final displayCount = count.clamp(1, 4);
    final colors = [
      AppColors.primary,
      AppColors.accentPink,
      AppColors.badgeGreen,
      const Color(0xFFF97316),
    ];
    final letters = ['Y', 'F', 'M', 'R'];

    return SizedBox(
      height: 22,
      width: (displayCount * 14.0) + 10,
      child: Stack(
        children: List.generate(displayCount, (index) {
          return Positioned(
            left: index * 14.0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  letters[index % letters.length],
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSharedProductRow(
    BuildContext context,
    HouseholdProvider provider,
    SharedBasketItem item,
  ) {
    final product = item.product;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product Thumbnail
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: CatalogImage(
                imageUrl: product.imageUrl,
                placeholder: Text(
                  _getProductEmoji(product.name),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                ),
              ),
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
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '(${product.description})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // "Added by" Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EAF8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 11,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Added by ${item.addedByName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Quantity Stepper and Total Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${item.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              // Upgraded Stepper Button
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentPinkSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accentPink.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_rounded,
                        size: 15,
                        color: AppColors.accentPink,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 32,
                      ),
                      onPressed: () => provider.decrementItem(item),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentPink,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: AppColors.accentPink,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 32,
                      ),
                      onPressed: () => provider.incrementItem(item),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSharedBasketEmptyState(
    BuildContext context,
    HouseholdProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8F2)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.giftBannerBg,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your Shared Basket is Empty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add daily essentials so all household members can see and share the order.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _showAddProductsBottomSheet(context, provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text(
              'Add Family Essentials',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedBasketFooter(
    BuildContext context,
    HouseholdProvider provider,
  ) {
    final subtotal = provider.sharedSubtotal;
    final memberCount = provider.household?.memberCount ?? 1;
    final splitPerPerson = memberCount > 0
        ? (subtotal / memberCount)
        : subtotal;
    final totalSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ESTIMATED BASKET TOTAL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              '₹${subtotal.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            if (memberCount > 1)
              Text(
                '(~₹${splitPerPerson.toStringAsFixed(0)} / member)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.badgeGreen,
                ),
              ),
          ],
        ),
      ],
    );
    final reviewButton = ElevatedButton.icon(
      onPressed: () => _showReviewBasketDialog(context, provider),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
        shadowColor: AppColors.primary.withValues(alpha: 0.4),
      ),
      icon: const Icon(Icons.receipt_long_rounded, size: 17),
      label: const Text(
        'Review Basket',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
    final compact = MediaQuery.sizeOf(context).width < 540;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact) ...[
            Align(alignment: Alignment.centerLeft, child: totalSummary),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: reviewButton),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [totalSummary, reviewButton],
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SEARCH BAR WIDGET
  // ==========================================
  Widget _buildSearchInput({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEADBEE)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: AppColors.textMuted,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 12,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ==========================================
  // NO HOUSEHOLD EMPTY STATE
  // ==========================================
  Widget _buildNoHouseholdEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.giftBannerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.diversity_3_rounded,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Shop together, save together',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a household basket with your family or flatmates. Add items together and avoid duplicate orders!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateHouseholdDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_home_rounded, size: 18),
                label: const Text(
                  'Create Household',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showJoinHouseholdDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const Text(
                  'Join Household with Code',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CREATE HOUSEHOLD DIALOG
  // ==========================================
  void _showCreateHouseholdDialog(BuildContext context) {
    final controller = TextEditingController(text: 'My Family');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.add_home_rounded,
                color: AppColors.accentPink,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Create Household',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give your household a name (e.g. Reddy Family, Flat 302):',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Reddy Family',
                  filled: true,
                  fillColor: const Color(0xFFF7F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      setDialogState(() => isSubmitting = true);
                      final provider = dialogCtx.read<HouseholdProvider>();
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final success = await provider.createHousehold(name);

                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }

                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Household "$name" created! Share the join code with your family.'
                                : (provider.errorMessage ??
                                      'Could not create household. Please try again.'),
                          ),
                          backgroundColor: success
                              ? AppColors.badgeGreen
                              : Colors.red,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // JOIN HOUSEHOLD DIALOG
  // ==========================================
  void _showJoinHouseholdDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Join Household',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the 6-character code shared by your family member (e.g. PC-8K2N):',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. PC-8K2N',
                  filled: true,
                  fillColor: const Color(0xFFF7F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = controller.text.trim();
                      if (code.isEmpty) return;

                      setDialogState(() => isSubmitting = true);
                      final provider = dialogCtx.read<HouseholdProvider>();
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final success = await provider.joinHousehold(code);

                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }

                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Joined household successfully!'
                                : (provider.errorMessage ??
                                      'Invalid join code. Please try again.'),
                          ),
                          backgroundColor: success
                              ? AppColors.badgeGreen
                              : Colors.red,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ADD PRODUCTS TO SHARED BASKET BOTTOM SHEET
  // ==========================================
  void _showAddProductsBottomSheet(
    BuildContext context,
    HouseholdProvider householdProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => _AddProductsSheet(
        householdProvider: householdProvider,
        emojiGetter: _getProductEmoji,
      ),
    );
  }

  // ==========================================
  // REVIEW BASKET SUMMARY DIALOG
  // ==========================================
  Future<void> _openGroupCheckout(
    BuildContext context,
    HouseholdProvider provider,
    List<SharedBasketItem> items,
  ) async {
    final unavailable = items.where((item) {
      return !item.product.isInStock ||
          item.quantity > item.product.stockQuantity;
    }).toList();
    if (unavailable.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Update unavailable or out-of-stock items before checkout: '
            '${unavailable.map((item) => item.product.name).join(', ')}',
          ),
        ),
      );
      return;
    }

    final checkoutItems = List<SharedBasketItem>.unmodifiable(items);
    final purchasedSharedItemIds = checkoutItems
        .map((item) => item.id)
        .toList(growable: false);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<CartProvider>(
          create: (_) {
            final checkoutCart = CartProvider();
            checkoutCart.addBatchProducts({
              for (final item in checkoutItems) item.product: item.quantity,
            });
            return checkoutCart;
          },
          child: CartCheckoutScreen(
            onBack: () => Navigator.pop(context),
            onStartShopping: () => Navigator.pop(context),
            onOrderCompleted: () =>
                provider.removeItemsAfterCheckout(purchasedSharedItemIds),
          ),
        ),
      ),
    );
  }

  void _showReviewBasketDialog(
    BuildContext context,
    HouseholdProvider provider,
  ) {
    final subtotal = provider.sharedSubtotal;
    final items = provider.sharedItems;
    final memberCount = provider.household?.memberCount ?? 1;
    final splitPerPerson = memberCount > 0
        ? (subtotal / memberCount)
        : subtotal;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Household Basket Review',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.giftBannerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All ${provider.household?.name ?? 'Household'} members can see these items. Anyone can place this combined order.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Total Items:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Basket Subtotal:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '₹${subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Split ($memberCount members):',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '₹${splitPerPerson.toStringAsFixed(0)} each',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.badgeGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  unawaited(_openGroupCheckout(context, provider, items));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue to Group Checkout',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// QUICK PRODUCT PICKER SHEET FOR SHARED BASKET
// ==========================================
class _AddProductsSheet extends StatefulWidget {
  final HouseholdProvider householdProvider;
  final String Function(String) emojiGetter;

  const _AddProductsSheet({
    required this.householdProvider,
    required this.emojiGetter,
  });

  @override
  State<_AddProductsSheet> createState() => _AddProductsSheetState();
}

class _AddProductsSheetState extends State<_AddProductsSheet> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  final Set<String> _addingProductIds = {};
  bool _isLoading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await _productService.getProducts();
      if (mounted) {
        setState(() {
          _products = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.trim().isEmpty
        ? _products
        : _products
              .where(
                (p) => p.name.toLowerCase().contains(_filter.toLowerCase()),
              )
              .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.add_shopping_cart_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Add Items to Shared Basket',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: TextField(
              onChanged: (val) => setState(() => _filter = val),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
          const SizedBox(height: 6),
          // Product List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentPink,
                    ),
                  )
                : filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final product = filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F6FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: CatalogImage(
                              imageUrl: product.imageUrl,
                              placeholder: Text(
                                widget.emojiGetter(product.name),
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '₹${product.price.toStringAsFixed(0)} ${product.description != null ? "• ${product.description}" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: () {
                          final matchingItems = widget
                              .householdProvider
                              .sharedItems
                              .where((item) => item.productId == product.id)
                              .toList();
                          final existingItem = matchingItems.isNotEmpty
                              ? matchingItems.first
                              : null;
                          final existingQty = existingItem?.quantity ?? 0;

                          if (existingQty > 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentPinkSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.accentPink.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    onPressed:
                                        _addingProductIds.contains(product.id)
                                        ? null
                                        : () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            setState(
                                              () => _addingProductIds.add(
                                                product.id,
                                              ),
                                            );
                                            try {
                                              if (existingQty <= 1) {
                                                await widget.householdProvider
                                                    .removeItem(
                                                      existingItem!.id,
                                                    );
                                              } else {
                                                await widget.householdProvider
                                                    .decrementItem(
                                                      existingItem!,
                                                    );
                                              }
                                            } catch (error) {
                                              if (mounted &&
                                                  messenger.mounted) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Could not update ${product.name}: $error',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _addingProductIds
                                                      .remove(product.id),
                                                );
                                              }
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.remove_rounded,
                                      size: 15,
                                      color: AppColors.accentPink,
                                    ),
                                  ),
                                  Text(
                                    '$existingQty',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.accentPink,
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    onPressed:
                                        _addingProductIds.contains(product.id)
                                        ? null
                                        : () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            setState(
                                              () => _addingProductIds.add(
                                                product.id,
                                              ),
                                            );
                                            try {
                                              await widget.householdProvider
                                                  .addSharedProduct(product);
                                            } catch (error) {
                                              if (mounted &&
                                                  messenger.mounted) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Could not add ${product.name}: $error',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _addingProductIds
                                                      .remove(product.id),
                                                );
                                              }
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 15,
                                      color: AppColors.accentPink,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ElevatedButton(
                            onPressed: _addingProductIds.contains(product.id)
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    setState(
                                      () => _addingProductIds.add(product.id),
                                    );
                                    try {
                                      await widget.householdProvider
                                          .addSharedProduct(product);
                                      if (!mounted) return;
                                      if (messenger.mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Added "${product.name}" to Shared Basket!',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                            backgroundColor:
                                                AppColors.badgeGreen,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (error) {
                                      if (!mounted) return;
                                      if (messenger.mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not add ${product.name}: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(
                                          () => _addingProductIds.remove(
                                            product.id,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPinkSoft,
                              foregroundColor: AppColors.accentPink,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                            ),
                            child: Text(
                              _addingProductIds.contains(product.id)
                                  ? 'ADDING'
                                  : 'ADD',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
