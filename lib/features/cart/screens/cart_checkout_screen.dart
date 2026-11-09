import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/catalog_image.dart';
import '../../../models/cart_item.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/order_service.dart';
import '../../../services/razorpay_order_service.dart';
import '../../address/widgets/address_selector_bottom_sheet.dart';
import '../../address/screens/add_address_screen.dart';
import '../../address/providers/address_provider.dart';
import '../../address/models/address_model.dart';
import '../../home/providers/customer_order_tracking_provider.dart';
import '../../budget_guardian/widgets/budget_guardian_card.dart';
import '../../budget_guardian/utils/budget_dialog_helper.dart';
import '../../navigation/main_navigation_screen.dart';
import '../../profile/models/order_history_item.dart';
import '../../profile/services/order_history_service.dart';
import '../../profile/screens/login_screen.dart';
import '../../product_detail/screens/product_detail_screen.dart';
import 'order_success_screen.dart';

class CartCheckoutScreen extends StatefulWidget {
  final OrderService? orderService;
  final VoidCallback? onStartShopping;
  final VoidCallback? onBack;
  final Future<void> Function()? onOrderCompleted;

  const CartCheckoutScreen({
    super.key,
    this.orderService,
    this.onStartShopping,
    this.onBack,
    this.onOrderCompleted,
  });

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  late final OrderService _orderService;
  bool _isPlacingOrder = false;
  bool _couponApplied = false;
  Razorpay? _razorpay;
  final RazorpayOrderService _razorpayOrderService = RazorpayOrderService();
  String? _paymentIdempotencyKey;
  AddressModel? _pendingPaymentAddress;
  List<CartItem>? _pendingPaymentItems;
  int? _pendingPaymentItemCount;
  String? _pendingPaymentAttemptId;
  String? _pendingRazorpayOrderId;
  PaymentSuccessResponse? _pendingPaymentResponse;

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _handleNavigateBackOrShopping();
    }
  }

  void _handleNavigateBackOrShopping() {
    if (widget.onStartShopping != null) {
      widget.onStartShopping!();
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // Safe fallback when opened as root without navigation history
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
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
    if (lower.contains('turns')) return '🥨';
    if (lower.contains('mix') || lower.contains('bbq')) return '🥜';
    if (lower.contains('ice cream') || lower.contains('cup')) return '🍨';
    return '🥗';
  }

  void _openProductDetails(Product product) {
    final cart = context.read<CartProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<CartProvider>.value(
          value: cart,
          child: ProductDetailScreen(product: product),
        ),
      ),
    );
  }

  Future<void> _handlePlaceOrder(String paymentMethod) async {
    if (_isPlacingOrder) return;
    final cart = context.read<CartProvider>();
    if (cart.itemList.isEmpty) return;

    setState(() => _isPlacingOrder = true);
    try {
      // Login requirement: Redirect unauthenticated customers to login before checkout.
      if (!_orderService.isAuthenticated) {
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );

        if (!mounted) return;
        if (loggedIn != true || !_orderService.isAuthenticated) {
          return;
        }
      }

      final selectedAddress = await _validateDeliveryAddress();
      if (selectedAddress == null) return;

      final items = List<CartItem>.from(cart.itemList);
      final total = cart.toPayAmount;
      final totalQty = cart.totalQuantity;

      final result = await _orderService.placeOrder(
        items: items,
        totalAmount: total,
        deliveryAddressId: selectedAddress.id,
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;

      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Failed to place order. Please try again.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      await _completeSuccessfulOrder(
        result: result,
        paymentMethod: paymentMethod,
        selectedAddress: selectedAddress,
        items: items,
        totalQty: totalQty,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place your order: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  Future<void> _completeSuccessfulOrder({
    required OrderResult result,
    required String paymentMethod,
    required AddressModel selectedAddress,
    required List<CartItem> items,
    required int totalQty,
  }) async {
    if (!mounted) return;
    final cart = context.read<CartProvider>();

    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final currentUserId = auth?.user?.id ?? auth?.profile?.id;
    if (result.totalAmount != null) {
      final orderHistoryItem = OrderHistoryItem(
        orderId: result.orderId,
        status: 'Order Placed',
        createdAt: DateTime.now(),
        totalAmount: result.totalAmount!,
        paymentMethod: paymentMethod == 'razorpay'
            ? 'Razorpay (test mode)'
            : 'Cash on delivery',
        deliveryAddress: selectedAddress.shortDisplay,
        items: items
            .map(
              (item) => OrderItemSummary(
                productId: item.product.id,
                productName: item.product.name,
                quantity: item.quantity,
                unitPrice: item.product.price,
                imageUrl: item.product.imageUrl,
              ),
            )
            .toList(),
      );
      await OrderHistoryService().recordOrder(
        orderHistoryItem,
        userId: currentUserId,
      );
    }

    if (!mounted) return;
    final trackingProvider = context.read<CustomerOrderTrackingProvider?>();
    if (trackingProvider != null) {
      unawaited(trackingProvider.refresh(userId: currentUserId));
    }

    cart.clearCart();

    try {
      await widget.onOrderCompleted?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order was placed, but the shared basket could not be cleared: $error',
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderId: result.orderId,
          totalAmount: result.totalAmount,
          itemCount: totalQty,
          paymentMethod: paymentMethod,
        ),
      ),
    );
  }

  Future<void> _handlePayOnline() async {
    if (_isPlacingOrder) return;
    final previousSuccess = _pendingPaymentResponse;
    if (previousSuccess != null) {
      await _verifyRazorpayPayment(previousSuccess);
      return;
    }
    final cart = context.read<CartProvider>();
    if (cart.itemList.isEmpty) return;
    setState(() => _isPlacingOrder = true);
    try {
      if (!_orderService.isAuthenticated) {
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (!mounted) return;
        if (loggedIn != true || !_orderService.isAuthenticated) {
          setState(() => _isPlacingOrder = false);
          return;
        }
      }
      final address = await _validateDeliveryAddress();
      if (!mounted) return;
      if (address == null) {
        setState(() => _isPlacingOrder = false);
        return;
      }
      _paymentIdempotencyKey ??= RazorpayOrderService.newIdempotencyKey();
      final items = List<CartItem>.from(cart.itemList);
      final paymentOrder = await _razorpayOrderService.createOrder(
        items: items,
        addressId: address.id,
        idempotencyKey: _paymentIdempotencyKey!,
      );
      if (!mounted) return;
      _pendingPaymentAddress = address;
      _pendingPaymentItems = items;
      _pendingPaymentItemCount = cart.totalQuantity;
      _pendingPaymentAttemptId = paymentOrder.attemptId;
      _pendingRazorpayOrderId = paymentOrder.razorpayOrderId;
      final razorpay = _razorpay ??= Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayExternalWallet);
      razorpay.open({
        'key': paymentOrder.keyId,
        'amount': paymentOrder.amountPaise,
        'currency': paymentOrder.currency,
        'order_id': paymentOrder.razorpayOrderId,
        'name': 'People Mart',
        'description': 'Grocery order payment',
        'retry': {'enabled': true, 'max_count': 3},
        'notes': {'attempt_id': paymentOrder.attemptId},
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start payment: $error')),
        );
      }
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    _pendingPaymentResponse = response;
    unawaited(_verifyRazorpayPayment(response));
  }

  Future<void> _verifyRazorpayPayment(PaymentSuccessResponse response) async {
    if (!mounted) return;
    final address = _pendingPaymentAddress;
    final items = _pendingPaymentItems;
    final itemCount = _pendingPaymentItemCount;
    if (address == null || items == null || itemCount == null) return;
    setState(() => _isPlacingOrder = true);
    try {
      final verified = await _razorpayOrderService.verifyPayment(
        attemptId: _pendingPaymentAttemptId ?? '',
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
      if (!mounted) return;
      await _completeSuccessfulOrder(
        result: OrderResult(
          isSuccess: true,
          orderId: verified['order_id'].toString(),
          totalAmount: (verified['total_amount'] as num?)?.toDouble(),
        ),
        paymentMethod: 'razorpay',
        selectedAddress: address,
        items: items,
        totalQty: itemCount,
      );
      _paymentIdempotencyKey = null;
      _pendingPaymentAddress = null;
      _pendingPaymentItems = null;
      _pendingPaymentItemCount = null;
      _pendingPaymentAttemptId = null;
      _pendingRazorpayOrderId = null;
      _pendingPaymentResponse = null;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment received; verification is pending. Refresh your orders before retrying. ($error)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    if (response.code == Razorpay.PAYMENT_CANCELLED &&
        _pendingPaymentAttemptId != null &&
        _pendingRazorpayOrderId != null) {
      setState(() => _isPlacingOrder = true);
      unawaited(_releaseCancelledPayment());
    } else {
      setState(() => _isPlacingOrder = false);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.code == Razorpay.PAYMENT_CANCELLED
              ? 'Payment cancelled. You can retry securely.'
              : 'Payment did not complete. Your order was not placed. Please retry.',
        ),
      ),
    );
  }

  Future<void> _releaseCancelledPayment() async {
    try {
      final released = await _razorpayOrderService.releaseCancelledAttempt(
        attemptId: _pendingPaymentAttemptId!,
        razorpayOrderId: _pendingRazorpayOrderId!,
      );
      if (released && mounted) {
        _paymentIdempotencyKey = null;
        _pendingPaymentAttemptId = null;
        _pendingRazorpayOrderId = null;
        _pendingPaymentAddress = null;
        _pendingPaymentItems = null;
        _pendingPaymentItemCount = null;
      }
    } catch (_) {
      // Leave the reservation in place if payment status could not be checked.
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isPlacingOrder = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName ?? 'wallet'}',
        ),
      ),
    );
  }

  Future<AddressModel?> _validateDeliveryAddress() async {
    final addressProvider = Provider.of<AddressProvider?>(
      context,
      listen: false,
    );
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userId = auth?.user?.id ?? auth?.profile?.id;

    if (addressProvider?.loadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not load your delivery addresses. Retry before checkout.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _reloadAddressesForCurrentUser(addressProvider!),
          ),
        ),
      );
      return null;
    }

    if (addressProvider == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address to continue.'),
        ),
      );
      return null;
    }

    if (addressProvider.isLoading || !addressProvider.isLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your delivery addresses are still loading. Please try again.',
          ),
        ),
      );
      return null;
    }

    if (!addressProvider.hasValidSelectedAddressFor(userId)) {
      if (addressProvider.addresses.isEmpty) {
        final shouldAddAddress = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delivery address required'),
            content: const Text(
              'Please select a delivery address to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Add address'),
              ),
            ],
          ),
        );
        if (!mounted || shouldAddAddress != true) return null;

        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const AddAddressScreen()),
        );
        if (!mounted) return null;

        if (addressProvider.hasValidSelectedAddressFor(userId)) {
          return addressProvider.selectedAddress;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address to continue.'),
        ),
      );
      return null;
    }
    return addressProvider.selectedAddress;
  }

  Future<void> _openAddressSelector(AddressProvider? addressProvider) async {
    if (addressProvider == null) return;
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userId = auth?.user?.id ?? auth?.profile?.id;
    if (userId == null) return;
    if (addressProvider.loadError != null ||
        !addressProvider.isLoaded ||
        addressProvider.currentUserId != userId) {
      await addressProvider.loadAddressesForUser(userId);
      if (addressProvider.loadError != null || !mounted) return;
    }
    await AddressSelectorBottomSheet.show(context);
    if (mounted) setState(() {});
  }

  Future<void> _reloadAddressesForCurrentUser(
    AddressProvider addressProvider,
  ) async {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userId = auth?.user?.id ?? auth?.profile?.id;
    if (userId != null) {
      await addressProvider.loadAddressesForUser(userId);
    }
  }

  Widget _buildDeliveryAddressCard(AddressProvider? addressProvider) {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userId = auth?.user?.id ?? auth?.profile?.id;
    final isValid =
        addressProvider != null &&
        userId != null &&
        addressProvider.hasValidSelectedAddressFor(userId);
    final selectedAddress = isValid ? addressProvider.selectedAddress : null;

    String message;
    if (addressProvider?.isLoading == true ||
        addressProvider?.isLoaded == false) {
      message = 'Loading saved delivery addresses…';
    } else if (addressProvider?.loadError != null) {
      message = 'Could not load your delivery addresses.';
    } else if (selectedAddress == null) {
      message = 'Please select a delivery address to continue.';
    } else {
      message = selectedAddress.shortDisplay;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selectedAddress == null
              ? AppColors.accentPink.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery address',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedAddress == null
                        ? AppColors.accentPink
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: addressProvider?.isLoading == true
                ? null
                : () => _openAddressSelector(addressProvider),
            child: Text(
              selectedAddress == null ? 'Select' : 'Change',
              style: const TextStyle(
                color: AppColors.accentPink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final addressProvider = context.watch<AddressProvider?>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: (widget.onBack != null || Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                onPressed: _handleBack,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  addressProvider?.selectedAddress?.tag ?? 'Delivery',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            Text(
              addressProvider?.selectedAddress?.shortDisplay ??
                  'Select Delivery Location',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.favorite_border,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Wishlist opened!'),
                  duration: Duration(milliseconds: 600),
                ),
              );
            },
          ),
        ],
      ),
      body: cart.itemList.isEmpty
          ? _buildEmptyCart(context)
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 110),
                  child: Column(
                    children: [
                      // 1. Top Green Savings Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        color: const Color(0xFFE8F6ED),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Yay! You saved ₹${cart.totalSavings.toStringAsFixed(0)} on this order',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.badgeGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: AppColors.badgeGreen,
                            ),
                          ],
                        ),
                      ),

                      _buildDeliveryAddressCard(addressProvider),

                      // 2. Budget Guardian Card (Spending Assistant)
                      const BudgetGuardianCard(),

                      // 3. Coupons & Offers Card
                      _buildCouponsCard(),

                      // 3. Delivery Time & Items Card
                      _buildDeliveryAndItemsCard(cart),

                      // 4. Ordering a Gift Card
                      _buildGiftCard(),

                      // 5. Milestone Savings Progress Tracker
                      _buildMilestoneTracker(cart),

                      // 6. Bill Summary Card
                      _buildBillSummaryCard(cart),

                      // 7. Savings On This Order Card
                      _buildSavingsCard(cart),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // 8. Bottom Sticky Payment Action Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomPaymentBar(context, cart),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add fresh groceries & snacks from People Cart!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleNavigateBackOrShopping,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Shopping',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue Notification Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Apply coupons + payment offers & save more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Coupons & offers',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Coupon 1
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F6ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.percent,
                  color: AppColors.badgeGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save ₹50 with OFFERSAVE50',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Shop for ₹680 more to apply',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Locked',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          // Offer 2
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    'pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Get Upto ₹50 Cashback on using Amazon Pay',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _couponApplied = !_couponApplied;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _couponApplied ? 'Offer applied!' : 'Offer removed!',
                      ),
                      duration: const Duration(milliseconds: 600),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  side: const BorderSide(color: AppColors.accentPink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _couponApplied ? 'Applied' : 'Apply',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAndItemsCard(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header: Delivering in 10 mins + Schedule
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled,
                      color: Color(0xFF7E22CE),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivering in 10 mins',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${cart.totalQuantity} items',
                            style: const TextStyle(
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
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: Colors.orange,
                ),
                label: const Text(
                  'Schedule',
                  style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          // Item Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cart.itemList.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = cart.itemList[index];

              return Row(
                children: [
                  // Product Thumbnail / Fallback
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      onTap: () => _openProductDetails(item.product),
                      child: Center(
                        child: CatalogImage(
                          imageUrl: item.product.imageUrl,
                          placeholder: Text(
                            _getProductEmoji(item.product.name),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title and Weight
                  Expanded(
                    child: InkWell(
                      onTap: () => _openProductDetails(item.product),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.product.description ?? '500 g',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '₹${item.product.originalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '₹${item.product.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.badgeGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Pink - [qty] + Stepper
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFF2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accentPink.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => cart.removeSingleItem(item.product.id),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.remove,
                              size: 14,
                              color: AppColors.accentPink,
                            ),
                          ),
                        ),
                        Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentPink,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (!cart.canIncrement(item.product)) {
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Cannot add more. Only ${item.product.stockQuantity} in stock.',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              return;
                            }
                            BudgetDialogHelper.checkAndAdd(
                              context: context,
                              itemPrice: item.product.price,
                              onProceed: () => cart.addItem(item.product),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.add,
                              size: 14,
                              color: cart.canIncrement(item.product)
                                  ? AppColors.accentPink
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Add More Items
          InkWell(
            onTap: _handleNavigateBackOrShopping,
            child: const Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  'Forgot something? ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Add More Items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Text('🛍️', style: TextStyle(fontSize: 24)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordering a gift?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Select items to pack in a gift bag!',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMilestoneTracker(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shop more, Unlock bigger savings!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Progress Line with Checkpoint Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildMilestonePoint(
                  'Free Delivery',
                  'Auto applied',
                  isAchieved: cart.isFreeDeliveryUnlocked,
                ),
              ),
              Expanded(
                child: _buildMilestonePoint(
                  '₹50 OFF',
                  'Coupon',
                  isAchieved: cart.subtotal >= 200,
                ),
              ),
              Expanded(
                child: _buildMilestonePoint(
                  '₹100 OFF',
                  'Coupon',
                  isAchieved: cart.subtotal >= 400,
                ),
              ),
              Expanded(
                child: _buildMilestonePoint(
                  '₹150 OFF',
                  'Coupon',
                  isAchieved: cart.subtotal >= 600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonePoint(
    String title,
    String subtitle, {
    bool isAchieved = false,
  }) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isAchieved ? AppColors.badgeGreen : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAchieved ? Icons.check : Icons.percent,
            size: 14,
            color: isAchieved ? Colors.white : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isAchieved ? AppColors.badgeGreen : AppColors.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBillSummaryCard(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'Bill Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 18),

          // Item Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Item Total',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  Text(
                    '₹${cart.mrpTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '₹${cart.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Delivery Fee
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Delivery Fee',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  const Text(
                    '₹30',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cart.isFreeDeliveryUnlocked ? 'FREE' : '₹30',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.badgeGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Handling Fee
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Handling Fee',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  Text(
                    '₹10',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.badgeGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 18),

          // To Pay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'To Pay',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '₹${(cart.mrpTotal + 40).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '₹${cart.toPayAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Savings on this order',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.badgeGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '₹${cart.totalSavings.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFDCFCE7)),
          _buildSavingRow(
            'Discount on MRP',
            '₹${cart.discountOnMrp.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 6),
          _buildSavingRow('FREE delivery savings', '₹30'),
          const SizedBox(height: 6),
          _buildSavingRow('Savings on Handling fee', '₹10'),
        ],
      ),
    );
  }

  Widget _buildSavingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF166534),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF166534),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPaymentBar(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left: To Pay Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To Pay',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₹${cart.toPayAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Action 1: Pay Online
            Expanded(
              child: OutlinedButton(
                onPressed: _isPlacingOrder ? null : _handlePayOnline,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pay Online',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Action 2: Pay Cash/UPI (on delivery)
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: _isPlacingOrder
                    ? null
                    : () => _handlePlaceOrder('cash_on_delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isPlacingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pay Cash/UPI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '(on delivery)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
