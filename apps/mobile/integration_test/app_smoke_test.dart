// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/main.dart';
import 'package:octopus_mobile/device_bridge.dart';
import 'package:octopus_mobile/usage_screen.dart';
import 'package:octopus_mobile/today_screen.dart';

Future<void> uiCapture(String phase) async {
  final ack = File('${Directory.systemTemp.path}/octopus-ui-ack');
  if (ack.existsSync()) ack.deleteSync();
  await File(
    '${Directory.systemTemp.path}/octopus-ui-shot',
  ).writeAsString(phase, flush: true);
  final end = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(end)) {
    if (ack.existsSync() && ack.readAsStringSync().trim() == phase) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('UI helper did not acknowledge $phase');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: task, activity, focus, platform persistence and usage', (
    tester,
  ) async {
    final store = BrainStore();
    await store.load();
    store.tasks.removeWhere((t) => t['title'] == 'Emulator smoke task');
    store.activities.removeWhere((a) => a['title'] == 'Emulator walk');
    store.commitments.removeWhere((c) => c['title'] == 'Emulator timetable');
    store.protection['enabled'] = true;
    store.protection['disclosureAccepted'] = true;
    await store.save();
    if (!store.onboardingComplete) {
      store.profile = {
        'name': 'Nguyễn An',
        'birthday': '2005-01-01',
        'authMode': 'guest',
      };
      // Profile form is covered by widget tests; pinning uses Android's real dialog.
      await store.save();
    }
    await tester.pumpWidget(OctopusApp(store: store));
    await tester.pumpAndSettle();
    if (!store.onboardingComplete) {
      await tester.tap(find.text('Dùng không đăng nhập'));
      await tester.pumpAndSettle();
      for (final kind in ['tasks', 'focus']) {
        var status = await store.device.widgetStatus();
        if (status[kind] != true) {
          final label = kind == 'tasks'
              ? 'Thêm widget nhịp hôm nay (4×2)'
              : 'Thêm widget ghi nhanh (2×2)';
          await tester.scrollUntilVisible(
            find.text(label),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text(label));
          await tester.runAsync(() async {
            final deadline = DateTime.now().add(const Duration(seconds: 60));
            do {
              await Future<void>.delayed(const Duration(seconds: 1));
              status = await store.device.widgetStatus();
            } while (status[kind] != true && DateTime.now().isBefore(deadline));
          });
          expect(
            status[kind],
            isTrue,
            reason: 'Launcher must actually pin $kind widget',
          );
          await tester.pumpAndSettle();
        }
      }
      await tester.scrollUntilVisible(
        find.text('Kiểm tra widget đã thêm'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Kiểm tra widget đã thêm'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bắt đầu dùng Octopus'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Bắt đầu dùng Octopus'));
      await tester.pumpAndSettle();
    }
    expect(find.byType(TodayScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Thêm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Emulator smoke task');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm việc'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final saved = jsonDecode((await store.device.readState())!);
    expect(
      (saved['tasks'] as List).any((t) => t['title'] == 'Emulator smoke task'),
      isTrue,
    );
    await uiCapture('v05_home');
    final smokeTask = store.tasks.firstWhere(
      (t) => t['title'] == 'Emulator smoke task',
    );
    final smokeRow = find.byKey(ValueKey('work:${smokeTask['id']}'));
    await tester.scrollUntilVisible(
      smokeRow,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: smokeRow, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('checkout-reflection')),
      'Đã hoàn thành bài kiểm tra giao diện',
    );
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpAndSettle();
    await uiCapture('v05_checkout');
    await tester.ensureVisible(find.text('Hoàn thành & lưu ghi nhận'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành & lưu ghi nhận'));
    await tester.pumpAndSettle();
    expect(smokeTask['done'], isTrue);
    expect(smokeTask['audience'], 'private');

    await tester.tap(find.text('Lịch trình'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thêm lịch cố định'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm lịch cố định'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Emulator timetable');
    await tester.tap(find.text('Lưu lịch cố định'));
    await tester.pumpAndSettle();
    expect(
      store.commitments.any((c) => c['title'] == 'Emulator timetable'),
      isTrue,
    );
    await tester.tap(find.text('Hôm nay').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ghi hoạt động'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Emulator walk');
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.ensureVisible(find.text('Lưu hoạt động'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu hoạt động'));
    await tester.pumpAndSettle();
    expect(store.activities.any((a) => a['title'] == 'Emulator walk'), isTrue);

    await tester.tap(find.text('Tập trung'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TextField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).first, '481');
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.ensureVisible(find.text('Bắt đầu phiên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu phiên'));
    await tester.pumpAndSettle();
    expect(store.focusEnd, isNull);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).first, '30');
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.ensureVisible(find.text('Bắt đầu phiên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu phiên'));
    await tester.pump(const Duration(seconds: 2));
    expect(store.focusEnd, isNotNull);
    final restored = BrainStore();
    await restored.load();
    expect(restored.focusEnd, store.focusEnd);
    await tester.tap(find.text('Kết thúc phiên'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Smoke test completed');
    await tester.tap(find.text('Ghi nhận và kết thúc'));
    await tester.pumpAndSettle();
    expect(store.focusEnd, isNull);

    await tester.tap(find.text('Nhóm'));
    await tester.pumpAndSettle();
    await uiCapture('v05_circles');
    final usage = await store.device.usage();
    expect(usage['granted'], isA<bool>());
    expect(usage['apps'], isA<List>());
    // The harness changes the permission only on this dedicated emulator.
    if (usage['granted'] == true) {
      expect(usage['from'], isA<int>());
      expect(usage['to'], isA<int>());
      expect(usage['from'] as int, lessThan(usage['to'] as int));
      // A fresh installation need not appear in Android's aggregate yet.
      // Validate returned rows without treating missing data as zero usage.
      for (final row in usage['apps'] as List) {
        expect(row['package'], isA<String>());
        expect((row['package'] as String).isNotEmpty, isTrue);
        expect(row['milliseconds'], isA<num>());
        expect(row['milliseconds'] as num, greaterThan(0));
      }
    }
    expect(tester.takeException(), isNull);
    print(
      'ANDROID_NATIVE_RESULT granted=${usage['granted']} apps=${(usage['apps'] as List).length}',
    );
    await tester.tap(find.text('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.byType(UsageBars), findsOneWidget);
    await uiCapture('usage_bars');
    await tester.scrollUntilVisible(
      find.byType(UsageDistribution),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await uiCapture('usage_donut');
    store.tasks.removeWhere((t) => t['title'] == 'Emulator smoke task');
    store.activities.removeWhere((a) => a['title'] == 'Emulator walk');
    // Retain fixed schedule for the following live AI flow.
    await store.save();
    await uiCapture('guard_off');
    await tester.pumpAndSettle();
  });
  if (const String.fromEnvironment('OCTOPUS_API_URL').isNotEmpty) {
    testWidgets(
      'Android → local API → PoolAI → preview → confirmed schedule',
      (tester) async {
        final store = BrainStore();
        await store.load();
        final previousPlan = List<Map<String, dynamic>>.from(store.plan);
        final previousCommitments = List<Map<String, dynamic>>.from(
          store.commitments,
        );
        final previousPreferences = Map<String, dynamic>.from(
          store.studyPreferences,
        );
        final previousContext = store.profile['learningContext'];
        store.plan.clear();
        // Keep the live model test independent of existing emulator data.
        store.commitments = [
          {
            'id': 'live-ai-timetable',
            'title': 'Lịch học thử nghiệm',
            'weekdays': [1, 2, 3, 4, 5],
            'startMinute': 8 * 60,
            'endMinute': 12 * 60,
          },
        ];
        store.studyPreferences = {
          'startMinute': 18 * 60,
          'endMinute': 22 * 60,
          'sessionMinutes': 45,
          'dailyMinutes': 120,
        };
        await store.save();
        try {
          await tester.pumpWidget(OctopusApp(store: store));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Lịch trình'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Lên kế hoạch cùng AI'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Lên kế hoạch cùng AI'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Dùng ví dụ DBMS · CNPM · KTLT'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Dùng ví dụ DBMS · CNPM · KTLT'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.widgetWithText(
              TextField,
              'Đề cương, phần còn yếu, cách học yêu thích',
            ),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(
            find.widgetWithText(
              TextField,
              'Đề cương, phần còn yếu, cách học yêu thích',
            ),
            'DBMS: JOIN và chuẩn hóa. CNPM: yêu cầu, kiểm thử. KTLT: mảng và con trỏ. Cần bài tập và chữa lỗi.',
          );
          await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          await tester.scrollUntilVisible(
            find.text('Tạo kế hoạch để xem trước'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Tạo kế hoạch để xem trước'));
          await tester.pump();
          final deadline = DateTime.now().add(const Duration(seconds: 110));
          while (find.text('Đang sắp xếp kế hoạch…').evaluate().isNotEmpty &&
              DateTime.now().isBefore(deadline)) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 1)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          final planningError = find.byKey(const Key('planner-error'));
          if (planningError.evaluate().isNotEmpty) {
            final message = tester.widget<Text>(planningError).data;
            await uiCapture('ai_error');
            fail('Planning API returned an error: $message');
          }
          expect(
            store.plan,
            isEmpty,
            reason: 'AI must not save a plan without confirmation',
          );
          await tester.scrollUntilVisible(
            find.text('Xác nhận thêm vào lịch'),
            500,
            maxScrolls: 100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await uiCapture('ai_preview');
          await tester.tap(find.text('Xác nhận thêm vào lịch'));
          await tester.pumpAndSettle();
          expect(store.plan, isNotEmpty);
          expect(
            store.plan.every(
              (p) => p['objectives'] is List && p['steps'] is List,
            ),
            isTrue,
          );
          final restored = BrainStore();
          await restored.load();
          expect(restored.plan.length, store.plan.length);
          print(
            'ANDROID_AI_RESULT model=gpt-5.4-mini sessions=${store.plan.length} confirmed=true',
          );
          expect(tester.takeException(), isNull);
        } finally {
          store.plan = previousPlan;
          store.commitments = previousCommitments;
          store.studyPreferences = previousPreferences;
          if (previousContext == null) {
            store.profile.remove('learningContext');
          } else {
            store.profile['learningContext'] = previousContext;
          }
          await store.save();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  testWidgets('Android document picker returns a readable app-private image', (
    tester,
  ) async {
    // scripts/picker-automation.py selects the fixture on the dedicated emulator.
    final device = DeviceBridge();
    print('ANDROID_PICKER_WAITING');
    final path = await device.pickImage().timeout(const Duration(seconds: 90));
    expect(path, isNotNull);
    expect(path, contains('/files/activity_images/'));
    final image = File(path!);
    final bytes = await image.readAsBytes();
    expect(bytes.take(4).toList(), [137, 80, 78, 71]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Image.file(image, cacheWidth: 400))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await image.delete();
    print('ANDROID_PICKER_RESULT bytes=${bytes.length}');
  });
}
