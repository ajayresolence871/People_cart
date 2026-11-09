import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_cart/features/home/widgets/shop_by_category_section.dart';

void main() {
  for (final size in [
    const Size(320, 800),
    const Size(393, 852),
    const Size(430, 900),
    const Size(768, 1024),
    const Size(1024, 900),
  ]) {
    testWidgets('Shop by Category fits ${size.width}px wide layout', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShopByCategorySection(
                categories: const [],
                onCategoryTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shop by Category'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
