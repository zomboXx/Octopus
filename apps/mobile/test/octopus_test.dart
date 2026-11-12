import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/device_bridge.dart';
import 'package:octopus_mobile/main.dart';

class MemoryDevice extends DeviceBridge {
  String? saved;
  @override
  Future<Map<String, dynamic>> wellbeingStatus() async => {
    'allowed': true,
    'sound': true,
    'headsUp': true,
  };
  @override
  Future<Map<String, dynamic>> requestWellbeingPermission() =>
      wellbeingStatus();
  @override
  Future<void> openWellbeingSettings() async {}

  @override
  Future<Map<String, dynamic>> guardStatus() async => {
    'accessibility': true,
    'vpnPrepared': true,
  };
  @override
  Future<List<Map<String, dynamic>>> guardEvents() async => [];
  @override
  Future<void> resumeProtection() async {}
  @override
  Future<void> cancelFocus(String reason, {bool completed = false}) async {}
  @override
  Future<String?> readState() async => saved;
  @override
  Future<void> writeState(String json) async {
    saved = json;
  }

  @override
  Future<String?> takeWidgetAction() async => null;
  @override
  Future<Map<String, dynamic>> widgetStatus() async => {
    'supported': true,
    'tasks': true,
    'focus': true,
  };
  @override
  Future<Map<String, dynamic>> usage() async => {'granted': false, 'apps': []};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rolling 24h and focus cap', () {
    final now = DateTime(2026, 10, 18, 12);
    expect(
      activityError(now.subtract(const Duration(hours: 24)), now, now),
      null,
    );
    expect(
      activityError(
        now.subtract(const Duration(hours: 24, seconds: 1)),
        now,
        now,
      ),
      isNotNull,
    );
    expect(activityError(now, now, now), isNotNull);
    expect(
      activityError(
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(seconds: 1)),
        now,
      ),
      isNotNull,
    );
    expect(focusError(480), null);
    expect(focusError(481), isNotNull);
    expect(focusError(0), isNotNull);
  });
  test('local state restores and focus time is credited only once', () async {
    final device = MemoryDevice(), store = BrainStore(device: MemoryDevice());
    final first = BrainStore(device: device);
    first.tasks.add({'title': 'Read', 'done': true});
    final start = DateTime(2026, 10, 18, 8);
    await first.startFocus(30, start: start);
    final restored = BrainStore(device: device);
    await restored.load();
    expect(restored.tasks.single['title'], 'Read');
    expect(restored.focusEnd, start.add(const Duration(minutes: 30)));
    await restored.finishFocus(now: start.add(const Duration(minutes: 90)));
    await restored.finishFocus(now: start.add(const Duration(minutes: 95)));
    expect(restored.focusMinutes, 30);
    expect(() => store.startFocus(481), throwsArgumentError);
  });
  testWidgets('mobile navigation, permissions state and native form layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await tester.runAsync(() => loader.load());
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(() => icons.load());
    final store = BrainStore(device: MemoryDevice())..onboardingComplete = true;
    const shot = Key('capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: shot,
        child: OctopusApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Một ngày có chủ đích.'), findsOneWidget);
    expect(tester.takeException(), null);
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(shot),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('test/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('android-home');
    await tester.tap(find.widgetWithText(TextButton, 'Thêm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Regression task');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm việc'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    expect(store.tasks.single['title'], 'Regression task');
    await tester.tap(find.text('Lịch trình'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm lịch cố định'), findsOneWidget);
    await tester.tap(find.text('Thêm lịch cố định'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lịch đi học');
    await tester.tap(find.text('Lưu lịch cố định'));
    await tester.pumpAndSettle();
    expect(store.commitments.single['title'], 'Lịch đi học');
    await tester.tap(find.text('Tập trung'));
    await tester.pumpAndSettle();
    expect(find.text('30:00'), findsOneWidget);
    await capture('android-focus');
    await tester.tap(find.text('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.text('Mở quyền sử dụng'), findsOneWidget);
    expect(find.text('THỐNG KÊ TỪ THIẾT BỊ'), findsNothing);
    await tester.tap(find.text('Nhóm'));
    await tester.pumpAndSettle();
    expect(find.text('LƯU TRÊN MÁY · CHƯA ĐỒNG BỘ'), findsOneWidget);
    await tester.tap(find.text('Hôm nay').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ghi hoạt động'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Chạy bộ thử nghiệm');
    await tester.ensureVisible(find.text('Lưu hoạt động'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.tap(find.text('Lưu hoạt động'));
    await tester.pumpAndSettle();
    expect(store.activities.single['title'], 'Chạy bộ thử nghiệm');
    expect(store.activities.single['audience'], 'private');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
