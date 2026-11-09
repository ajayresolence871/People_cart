import 'package:flutter/foundation.dart';

import '../models/customer_behavior_data.dart';
import '../services/customer_behavior_service.dart';

class CustomerBehaviorProvider extends ChangeNotifier {
  final CustomerBehaviorDataSource dataSource;
  int rangeDays = 30;
  bool isLoading = false;
  String? error;
  CustomerBehaviorData? data;

  CustomerBehaviorProvider({required this.dataSource});

  Future<void> load({int? days}) async {
    if (days != null) rangeDays = days;
    isLoading = true;
    error = null;
    notifyListeners();
    final to = DateTime.now();
    try {
      data = await dataSource.load(
        from: to.subtract(Duration(days: rangeDays)),
        to: to,
      );
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
