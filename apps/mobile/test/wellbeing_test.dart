import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/wellbeing_card.dart';
import 'octopus_test.dart' show MemoryDevice;

class PermissionDevice extends MemoryDevice {
  bool allowed = false;
  int requests = 0;
  int settings = 0;
  @override
  Future<Map<String, dynamic>> wellbeingStatus() async => {
    'allowed': allowed,
    'sound': allowed,
    'headsUp': allowed,
  };
  @override
  Future<Map<String, dynamic>> requestWellbeingPermission() async {
    requests++;
    allowed = true;
    return wellbeingStatus();
  }

  @override
  Future<void> openWellbeingSettings() async {
    settings++;
  }
}

void main() {
  test(
    'old guest state enables reminders by default and the opt-out survives reload',
    () async {
      final device = MemoryDevice()..saved = '{"version":1}';
      final store = BrainStore(device: device);
      await store.load();
      expect(store.wellbeingReminders, true);
      store.wellbeingReminders = false;
      await store.save();
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restored.wellbeingReminders, false);
      expect(restored.focusEnd, isNull);
      store.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'long-session consent is optional, not repeated, and settings fit a small phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final device = PermissionDevice();
      final actual = BrainStore(device: device);
      int finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Builder(
                builder: (context) => Column(
                  children: [
                    WellbeingCard(store: actual),
                    TextButton(
                      onPressed: () async {
                        await prepareWellbeingReminders(context, actual, 40);
                        finished++;
                      },
                      child: const Text('Short'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await prepareWellbeingReminders(context, actual, 90);
                        finished++;
                      },
                      child: const Text('Long'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Short'));
      await tester.tap(find.text('Short'));
      await tester.pumpAndSettle();
      expect(finished, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(device.requests, 0);
      await tester.tap(find.text('Long'));
      await tester.pumpAndSettle();
      expect(find.text('Nhắc chăm sóc bản thân'), findsOneWidget);
      await tester.tap(find.text('Bắt đầu không thông báo'));
      await tester.pumpAndSettle();
      expect(finished, 2);
      expect(device.requests, 0);
      await tester.tap(find.text('Long'));
      await tester.pumpAndSettle();
      expect(finished, 3);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(find.text('Cho phép thông báo & âm thanh'));
      await tester.tap(find.text('Cho phép thông báo & âm thanh'));
      await tester.pumpAndSettle();
      expect(device.requests, 1);
      expect(find.text('Thông báo đã bật · Cài đặt âm thanh'), findsOneWidget);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(actual.wellbeingReminders, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      actual.dispose();
    },
  );
}
