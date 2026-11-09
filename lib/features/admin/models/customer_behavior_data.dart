class ProductBehaviorMetric {
  final String productId;
  final String name;
  final int count;
  final int views;
  final int additions;
  final String? imageUrl;

  const ProductBehaviorMetric({
    required this.productId,
    required this.name,
    required this.count,
    this.views = 0,
    this.additions = 0,
    this.imageUrl,
  });
}

class SearchTermMetric {
  final String term;
  final int count;

  const SearchTermMetric({required this.term, required this.count});
}

class CustomerBehaviorData {
  final int productViews;
  final int addToCartEvents;
  final int searches;
  final int completedOrders;
  final int zeroResultSearches;
  final List<ProductBehaviorMetric> mostViewedProducts;
  final List<ProductBehaviorMetric> mostAddedProducts;
  final List<SearchTermMetric> zeroResultSearchTerms;
  final List<SearchTermMetric> topSearchTerms;
  final Map<int, int> activityByHour;
  final DateTime from;
  final DateTime to;

  const CustomerBehaviorData({
    required this.productViews,
    required this.addToCartEvents,
    required this.searches,
    required this.completedOrders,
    required this.zeroResultSearches,
    required this.mostViewedProducts,
    required this.mostAddedProducts,
    this.zeroResultSearchTerms = const [],
    required this.topSearchTerms,
    required this.activityByHour,
    required this.from,
    required this.to,
  });

  List<ProductBehaviorMetric> get popularProducts {
    final byId = <String, ProductBehaviorMetric>{};
    for (final metric in mostViewedProducts) {
      byId[metric.productId] = ProductBehaviorMetric(
        productId: metric.productId,
        name: metric.name,
        count: metric.views + metric.additions,
        views: metric.views == 0 ? metric.count : metric.views,
        additions: metric.additions,
        imageUrl: metric.imageUrl,
      );
    }
    for (final metric in mostAddedProducts) {
      final existing = byId[metric.productId];
      final views = existing?.views ?? metric.views;
      final additions = metric.additions == 0 ? metric.count : metric.additions;
      byId[metric.productId] = ProductBehaviorMetric(
        productId: metric.productId,
        name: metric.name,
        count: views + additions,
        views: views,
        additions: additions,
        imageUrl: metric.imageUrl ?? existing?.imageUrl,
      );
    }
    return byId.values.toList()..sort((first, second) {
      final byCount = second.count.compareTo(first.count);
      return byCount != 0 ? byCount : second.views.compareTo(first.views);
    });
  }
}
