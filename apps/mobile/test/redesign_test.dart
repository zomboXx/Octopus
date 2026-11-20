import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/main.dart';
import 'package:octopus_mobile/planning_api.dart';
import 'package:octopus_mobile/protection_screen.dart';
import 'octopus_test.dart' show MemoryDevice;

class VoiceDevice extends MemoryDevice {
  bool pending = true;
  int calls = 0;
  @override
  Future<String?> takeWidgetAction() async {
    if (!pending) return null;
    pending = false;
    return 'voice_task';
  }

  @override
  Future<String?> recognizeSpeech() async {
    calls++;
    return 'Ôn DBMS chương 4';
  }
}

void main() {
  test('quick add waits for planned work before moving to tomorrow', () {
    final store = BrainStore(device: MemoryDevice());
    final today = DateTime(2026, 10, 21, 9);
    store.tasks.add({
      'id': 'manual',
      'title': 'Đọc ghi chú',
      'date': dayKey(today),
      'done': true,
    });
    final planned = <String, dynamic>{
      'id': 'planned',
      'title': 'Ôn DBMS',
      'kind': 'focus',
      'start': DateTime(2026, 10, 21, 18).toIso8601String(),
      'end': DateTime(2026, 10, 21, 18, 45).toIso8601String(),
      'done': false,
    };
    store.plan.add(planned);
    expect(dayKey(store.quickTaskDate(now: today)), '2026-10-21');
    planned['done'] = true;
    expect(dayKey(store.quickTaskDate(now: today)), '2026-10-22');
    store.tasks.clear();
    planned['done'] = false;
    expect(dayKey(store.quickTaskDate(now: today)), '2026-10-21');
    planned['done'] = true;
    expect(dayKey(store.quickTaskDate(now: today)), '2026-10-22');
    store.plan.clear();
    expect(dayKey(store.quickTaskDate(now: today)), '2026-10-21');
  });

  testWidgets(
    'voice widget transcription remains editable before saving a task',
    (tester) async {
      final device = VoiceDevice();
      final store = BrainStore(device: device)..onboardingComplete = true;
      store.profile['voiceDisclosureAccepted'] = true;
      await tester.pumpWidget(OctopusApp(store: store));
      await tester.pumpAndSettle();
      expect(device.calls, 1);
      expect(store.tasks, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Ôn DBMS chương 4',
      );
      await tester.enterText(find.byType(TextField).first, 'Ôn DBMS chương 5');
      await tester.tap(find.text('Thêm việc'));
      await tester.pumpAndSettle();
      expect(store.tasks.single['title'], 'Ôn DBMS chương 5');
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'completed planned work and audience survive reload without duplicate focus credit',
    () async {
      final device = MemoryDevice();
      final store = BrainStore(device: device);
      final now = DateTime.now();
      final task = <String, dynamic>{
        'id': 'p1',
        'title': 'DBMS',
        'start': now.toIso8601String(),
        'end': now.add(const Duration(minutes: 30)).toIso8601String(),
        'kind': 'focus',
      };
      store.plan.add(task);
      await store.startFocus(
        30,
        start: now.subtract(const Duration(minutes: 5)),
      );
      store.focusTaskId = 'p1';
      await store.completeWork(
        task,
        reflection: 'Đã giải 5 bài',
        audience: 'selected',
        recipients: ['friend'],
      );
      final credited = store.focusMinutes;
      await store.completeWork(
        task,
        reflection: 'Đã giải 5 bài',
        audience: 'selected',
        recipients: ['friend'],
      );
      expect(store.focusMinutes, credited);
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restored.workOn(now).single['done'], true);
      expect(restored.plan.single['recipients'], ['friend']);
      expect(restored.focusEnd, isNull);
    },
  );
  test('Starter does not require a beta code', () {
    expect(PlanningApi().needsAccessCode, isFalse);
  });
  testWidgets(
    'first focus explains data and permission, decline does not start or grant',
    (tester) async {
      final store = BrainStore(device: MemoryDevice());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => ensureFocusProtection(context, store),
              child: const Text('Start'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cam kết: Octopus'), findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(store.protection['disclosureAccepted'], isNot(true));
      expect(store.focusEnd, isNull);
    },
  );
  testWidgets(
    'redesign: onboarding, tasks, checkout, circles and AI gate at phone size',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
            ),
          ),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await tester.runAsync(() async {
        await font.load();
        await icons.load();
      });
      final store = BrainStore(device: MemoryDevice());
      const shot = Key('redesign');
      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: OctopusApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(shot),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('test/previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }

      await capture('v05-onboarding');
      store.profile = {'name': 'Nguyễn An'};
      store.onboardingComplete = true;
      await store.addTask('Đọc chương 4 · DBMS', 45, DateTime.now());
      await store.addTask('Ôn kiểm thử phần mềm', 30, DateTime.now());
      final now = DateTime.now();
      store.plan.add({
        'id': 'preview-active-session',
        'title': 'Đọc sâu · Cơ sở dữ liệu',
        'subject': 'DBMS',
        'kind': 'focus',
        'start': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'end': now.add(const Duration(minutes: 35)).toIso8601String(),
        'expectedOutput':
            'Đọc chương 4, ghi lại 3 ý chính và tự trả lời câu hỏi.',
      });
      await store.save();
      await tester.pumpAndSettle();
      await capture('v05-home');
      expect(find.text('Bắt đầu tập trung'), findsNothing);
      expect(find.text('Mở Focus'), findsNothing);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('checkout-reflection')),
        'Đã đọc và ghi lại 3 ý chính',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await capture('v05-checkout');
      await tester.ensureVisible(find.text('Hoàn thành & lưu ghi nhận'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn thành & lưu ghi nhận'));
      await tester.pumpAndSettle();
      expect(store.plan.first['done'], true);
      expect(store.plan.first['audience'], 'private');
      await tester.tap(find.text('Nhóm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tạo nhóm'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Cùng vượt kỳ thi');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Mỗi ngày ôn 45 phút',
      );
      await tester.enterText(find.byType(TextField).at(2), 'Minh, Linh');
      await tester.tap(find.text('Tạo nhóm'));
      await tester.pumpAndSettle();
      expect(store.circles.single['members'], hasLength(2));
      await capture('v05-circles');
      await tester.ensureVisible(find.text('Tôi đã giữ cam kết'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tôi đã giữ cam kết'));
      await tester.pumpAndSettle();
      expect(store.checkins, hasLength(1));
      await tester.tap(find.text('Lịch trình'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Lên kế hoạch cùng AI'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lên kế hoạch cùng AI'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Hôm nay').last);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (var i = 0; i < 8; i++) {
        await store.addTask('Việc bổ sung $i', 25, DateTime.now());
      }
      await tester.pumpAndSettle();
      final quickAdd = find.text('Ghi nhanh điều cần làm…');
      expect(quickAdd.hitTestable(), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(quickAdd.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
