import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile opens plans with the current VND catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(store: BrainStore())),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Gói Octopus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('39.000 đ/tháng'),
      240,
      scrollable: list,
    );
    expect(find.text('39.000 đ/tháng'), findsOneWidget);
    expect(find.textContaining('USD'), findsNothing);

    final info = find.text('Xem thông tin gói');
    await tester.scrollUntilVisible(info.hitTestable(), 220, scrollable: list);
    await tester.pumpAndSettle();
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('thanh toán sẽ mở sau'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
