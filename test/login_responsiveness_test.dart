import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:people_cart/features/profile/screens/login_screen.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(1440, 900)]) {
    testWidgets('login layout fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-submit-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
