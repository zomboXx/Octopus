import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/main.dart';
import 'package:octopus_mobile/usage_screen.dart';
import 'octopus_test.dart' show MemoryDevice;

class UsageDevice extends MemoryDevice {
  bool allowed = true;
  @override
  Future<Map<String, dynamic>> usage() async => {
    'granted': allowed,
    'apps': allowed
        ? [
            {
              'package': 'video.test',
              'name': 'Video app',
              'milliseconds': 14400000,
            },
            {'package': 'study.test', 'name': 'Study', 'milliseconds': 3600000},
          ]
        : [],
    'days': allowed
        ? List.generate(
            7,
            (i) => {
              'date': '2026-10-${13 + i}',
              'milliseconds': i < 3 ? 6000000 : 0,
            },
          )
        : [],
  };
}

class UnavailableGuard extends MemoryDevice {
  @override
  Future<Map<String, dynamic>> guardStatus() async => {'accessibility': false};
  @override
  Future<List<Map<String, dynamic>>> installedApps() async => [];
}

void main() {
  test(
    'suggestions require enough observed days and respect permanent opt-out after restore',
    () async {
      final device = UsageDevice(), store = BrainStore();
      final data = await device.usage();
      final apps = rows(data['apps']), days = rows(data['days']);
      expect(restrictionSuggestion(apps, days.take(2).toList(), store), isNull);
      expect(
        restrictionSuggestion(apps, days, store)?['package'],
        'video.test',
      );
      final saved = BrainStore(device: device)
        ..dismissedSuggestions.add('video.test');
      saved.protection['enabled'] = true;
      await saved.save();
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restrictionSuggestion(apps, days, restored), isNull);
      expect(restored.protection['enabled'], isTrue);
    },
  );
  testWidgets(
    'real usage shape renders both charts and permission revocation hides data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = UsageDevice();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UsagePanel(store: BrainStore(device: device)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UsageBars), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(UsageDistribution), 200);
      expect(find.byType(UsageDistribution), findsOneWidget);
      expect(tester.takeException(), isNull);
      device.allowed = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(UsageBars), findsNothing);
      expect(find.byType(UsageDistribution), findsNothing);
      expect(find.text('Mở quyền sử dụng'), findsOneWidget);
    },
  );
  testWidgets(
    'focus does not silently start a timer when Android protection is missing',
    (tester) async {
      final store = BrainStore(device: UnavailableGuard())
        ..onboardingComplete = true;
      await tester.pumpWidget(OctopusApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tập trung'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu phiên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu phiên'));
      await tester.pumpAndSettle();
      expect(store.focusEnd, isNull);
      expect(
        find.text('Bạn cấp quyền. Bạn giữ quyền kiểm soát.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
