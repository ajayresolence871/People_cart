import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../models/customer_behavior_data.dart';
import '../providers/customer_behavior_provider.dart';
import '../services/customer_behavior_service.dart';

class CustomerBehaviorScreen extends StatelessWidget {
  final CustomerBehaviorDataSource? dataSource;

  const CustomerBehaviorScreen({super.key, this.dataSource});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.profile == null ||
        auth.role != 'admin') {
      return const Center(child: Text('Admin access required.'));
    }

    return ChangeNotifierProvider(
      create: (_) => CustomerBehaviorProvider(
        dataSource: dataSource ?? CustomerBehaviorService(),
      )..load(),
      child: const _CustomerBehaviorContent(),
    );
  }
}

class _CustomerBehaviorContent extends StatelessWidget {
  const _CustomerBehaviorContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerBehaviorProvider>();
    final data = provider.data;
    return RefreshIndicator(
      color: AppColors.accentPink,
      onRefresh: provider.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final heading = const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer insights',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Understand what shoppers want.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                      final rangePicker = _InsightsRangePicker(
                        provider: provider,
                      );

                      if (constraints.maxWidth < 480) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            Align(
                              alignment: Alignment.centerRight,
                              child: rangePicker,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: heading),
                          rangePicker,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  if (provider.isLoading && data == null)
                    const _InsightsMessage(
                      icon: Icons.insights_outlined,
                      message: 'Loading recorded customer activity…',
                      loading: true,
                    )
                  else if (provider.error != null && data == null)
                    _InsightsMessage(
                      icon: Icons.error_outline,
                      message: 'Could not load insights: ${provider.error}',
                      action: () => provider.load(),
                    )
                  else if (data == null ||
                      (data.productViews == 0 &&
                          data.addToCartEvents == 0 &&
                          data.searches == 0 &&
                          data.completedOrders == 0 &&
                          data.zeroResultSearches == 0))
                    const _InsightsMessage(
                      icon: Icons.query_stats_rounded,
                      message: 'No customer activity has been recorded in this date range yet.',
                    )
                  else ...[
                    if (provider.error != null)
                      _InsightsMessage(
                        icon: Icons.error_outline,
                        message:
                            'Refresh failed; showing the previous results. ${provider.error}',
                      ),
                    if (provider.isLoading)
                      const LinearProgressIndicator(
                        color: AppColors.accentPink,
                      ),
                    _MetricGrid(data: data),
                    const SizedBox(height: 16),
                    _FunnelCard(data: data),
                    const SizedBox(height: 16),
                    _PopularProductsCard(products: data.popularProducts),
                    const SizedBox(height: 12),
                    _SearchOpportunitiesCard(terms: data.zeroResultSearchTerms),
                    const SizedBox(height: 12),
                    _ActivityByHourCard(activityByHour: data.activityByHour),
                    const SizedBox(height: 12),
                    const Text(
                      'Counts are events, not unique customers. Product views count detail-screen opens; cart additions count accepted add actions; completed orders count confirmed secure checkout orders. The funnel compares these event totals in the selected date range and is not a user-level conversion rate.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
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
}

class _MetricGrid extends StatelessWidget {
  final CustomerBehaviorData data;

  const _MetricGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Product views', data.productViews, Icons.visibility_outlined),
      ('Added to cart', data.addToCartEvents, Icons.add_shopping_cart_rounded),
      ('Searches', data.searches, Icons.search_rounded),
      ('Orders completed', data.completedOrders, Icons.receipt_long_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _InsightsMetricCard(
                    label: metric.$1,
                    value: metric.$2,
                    icon: metric.$3,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _InsightsRangePicker extends StatelessWidget {
  final CustomerBehaviorProvider provider;

  const _InsightsRangePicker({required this.provider});

  @override
  Widget build(BuildContext context) {
    const ranges = [(7, '7 days'), (30, '30 days'), (90, '90 days')];
    return SizedBox(
      width: 230,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: ranges.map((range) {
            final selected = provider.rangeDays == range.$1;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: provider.isLoading
                    ? null
                    : () => provider.load(days: range.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    range.$2,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InsightsMetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _InsightsMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.giftBannerBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularProductsCard extends StatelessWidget {
  final List<ProductBehaviorMetric> products;

  const _PopularProductsCard({required this.products});

  @override
  Widget build(BuildContext context) {
    return _InsightsCard(
      title: 'Popular products',
      icon: Icons.star_rounded,
      child: products.isEmpty
          ? const Text(
              'No product activity in this period.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : Column(
              children: products.take(5).toList().asMap().entries.map((entry) {
                final product = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.accentPinkSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child:
                              product.imageUrl == null ||
                                  product.imageUrl!.isEmpty
                              ? const ColoredBox(
                                  color: AppColors.giftBannerBg,
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: AppColors.giftBannerBg,
                                    child: Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${product.views} views · ${product.additions} added',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _SearchOpportunitiesCard extends StatelessWidget {
  final List<SearchTermMetric> terms;

  const _SearchOpportunitiesCard({required this.terms});

  @override
  Widget build(BuildContext context) => _InsightsCard(
    title: 'Search opportunities',
    icon: Icons.search_rounded,
    child: terms.isEmpty
        ? const Text(
            'No searches without results in this period.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        : Wrap(
            spacing: 7,
            runSpacing: 7,
            children: terms.take(8).map((term) {
              return Container(
                constraints: const BoxConstraints(maxWidth: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPinkSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      term.term,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${term.count} searches · no results',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
  );
}

class _FunnelCard extends StatelessWidget {
  final CustomerBehaviorData data;

  const _FunnelCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final addRate = data.productViews == 0
        ? 0
        : (data.addToCartEvents * 100 / data.productViews).round();
    final checkoutRate = data.addToCartEvents == 0
        ? 0
        : (data.completedOrders * 100 / data.addToCartEvents).round();
    final steps = [
      ('Viewed', data.productViews, 100, AppColors.primary),
      ('Added to cart', data.addToCartEvents, addRate, AppColors.accentPink),
      (
        'Checkout completed',
        data.completedOrders,
        checkoutRate,
        AppColors.badgeGreen,
      ),
    ];
    return _InsightsCard(
      title: 'Conversion funnel',
      icon: Icons.filter_alt_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: steps.map((step) {
              final item = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: step.$4,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.$1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${step.$2} · ${step.$3}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: item,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ActivityByHourCard extends StatelessWidget {
  final Map<int, int> activityByHour;

  const _ActivityByHourCard({required this.activityByHour});

  @override
  Widget build(BuildContext context) => _InsightsCard(
    title: 'Activity by hour',
    icon: Icons.schedule_rounded,
    child: activityByHour.isEmpty
        ? const Text(
            'No timestamped activity in this period.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activityByHour.entries
                .toList()
                .sortedByHour()
                .map(
                  (entry) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.giftBannerBg,
                      border: Border.all(color: const Color(0xFFD8C9DD)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.key.toString().padLeft(2, '0')}:00 · ${entry.value}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

extension on List<MapEntry<int, int>> {
  List<MapEntry<int, int>> sortedByHour() =>
      [...this]..sort((a, b) => a.key.compareTo(b.key));
}

class _InsightsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InsightsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _InsightsMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool loading;
  final VoidCallback? action;

  const _InsightsMessage({
    required this.icon,
    required this.message,
    this.loading = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (loading)
            const CircularProgressIndicator(color: AppColors.accentPink)
          else
            Icon(icon, color: AppColors.accentPink, size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}
