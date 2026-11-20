import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/planning_rules.dart';
import 'package:octopus_mobile/main.dart';
import 'package:octopus_mobile/schedule_screen.dart';
import 'octopus_test.dart' show MemoryDevice;

class ActionDevice extends MemoryDevice {
  String? action;
  @override
  Future<String?> takeWidgetAction() async {
    final value = action;
    action = null;
    return value;
  }
}

class UnpinnedWidgetDevice extends MemoryDevice {
  bool failNextWrite = false;

  @override
  Future<Map<String, dynamic>> widgetStatus() async => {
    'supported': true,
    'tasks': false,
    'focus': false,
  };

  @override
  Future<bool> pinWidget(String kind) async => false;

  @override
  Future<void> writeState(String json) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Storage unavailable');
    }
    await super.writeState(json);
  }
}

void main() {
  testWidgets(
    'widget action adds tomorrow after completed day and starts one focus session',
    (tester) async {
      final device = ActionDevice()..action = 'add_task';
      final store = BrainStore(device: device)..onboardingComplete = true;
      store.protection['enabled'] = true;
      store.protection['disclosureAccepted'] = true;
      store.tasks.add({
        'id': 'done',
        'title': 'Done today',
        'date': dayKey(DateTime.now()),
        'done': true,
      });
      await tester.pumpWidget(OctopusApp(store: store));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Tomorrow from widget',
      );
      await tester.tap(find.text('Thêm việc'));
      await tester.pumpAndSettle();
      expect(
        store.tasks.last['date'],
        dayKey(DateTime.now().add(const Duration(days: 1))),
      );
      device.action = 'start_focus';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(store.focusEnd!.difference(store.focusStart!).inMinutes, 30);
      final end = store.focusEnd;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(store.focusEnd, end);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'structured plan renders compact cards and expandable study steps',
    (tester) async {
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
      final draft = jsonDecode(
        File('test/fixtures/study-plan.json').readAsStringSync(),
      );
      final first = Map<String, dynamic>.from(draft['sessions'][0]);
      const shot = Key('schedule-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: blue),
            ),
            home: Scaffold(
              backgroundColor: background,
              appBar: AppBar(title: const Text('Lịch ôn tập · Xem trước')),
              body: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const PageIntro(
                    'Từng buổi. Từng bước tiến.',
                    'Ví dụ từ GPT-5.4 mini · chưa lưu vào lịch',
                  ),
                  const SizedBox(height: 20),
                  for (final p in (draft['sessions'] as List).take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SessionCard(session: Map<String, dynamic>.from(p)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(first['steps'][0]), findsNothing);
      Future<void> capture(String file) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(shot),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'test/previews/$file.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('android-study-plan');
      await tester.tap(find.text('Nội dung buổi ôn').first);
      await tester.pumpAndSettle();
      expect(find.text('1. ${first['steps'][0]}'), findsOneWidget);
      await capture('android-study-detail');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'profile and quick task date, including midnight and old tasks',
    () async {
      final now = DateTime(2026, 10, 19, 10);
      expect(profileError('', null, now), isNotNull);
      expect(profileError('Nguyễn An', DateTime(2027), now), isNotNull);
      expect(profileError('Nguyễn An', DateTime(2005, 1, 1), now), isNull);
      final store = BrainStore(device: MemoryDevice());
      expect(dayKey(store.quickTaskDate(now: now)), '2026-10-19');
      store.tasks.add({'date': '2026-10-18', 'done': false});
      expect(dayKey(store.quickTaskDate(now: now)), '2026-10-19');
      store.tasks.add({'date': '2026-10-19', 'done': true});
      expect(dayKey(store.quickTaskDate(now: now)), '2026-10-20');
      expect(
        dayKey(store.quickTaskDate(now: DateTime(2026, 10, 20))),
        '2026-10-20',
      );
      store.profile = {
        'name': 'Nguyễn An',
        'birthday': '2005-01-01',
        'authMode': 'guest',
      };
      store.commitments = [
        {
          'id': 'a',
          'title': 'Đi học',
          'weekdays': [1],
          'startMinute': 1080,
          'endMinute': 1140,
        },
      ];
      await store.save();
      final loaded = BrainStore(device: store.device);
      await loaded.load();
      expect(loaded.profile, store.profile);
      expect(loaded.commitments, store.commitments);
    },
  );

  test('reject recurring overlaps and stale AI draft after timetable edit', () {
    final store = BrainStore(device: MemoryDevice());
    final entry = {
      'id': 'a',
      'title': 'Đi học',
      'weekdays': [1],
      'startMinute': 1080,
      'endMinute': 1140,
    };
    expect(commitmentError(entry, []), isNull);
    expect(commitmentError({...entry, 'id': 'b'}, [entry]), isNotNull);
    expect(
      commitmentError(
        {
          ...entry,
          'id': 'b',
          'weekdays': [2],
        },
        [entry],
      ),
      isNull,
    );
    final sessions = [
      {
        'title': 'DBMS',
        'start': '2026-10-19T11:00:00Z',
        'end': '2026-10-19T11:45:00Z',
        'examDate': '2026-10-22',
      },
    ];
    final now = DateTime.utc(2026, 10, 19, 9);
    expect(planError(sessions, store, now), isNull);
    store.commitments.add(entry);
    expect(planError(sessions, store, now), isNotNull);
    store.commitments.clear();
    store.plan.addAll(sessions);
    expect(planError(sessions, store, now), isNotNull);
  });

  testWidgets(
    'first run saves the guest profile and can finish without any widgets',
    (tester) async {
      final device = UnpinnedWidgetDevice();
      final store = BrainStore(device: device);
      await tester.pumpWidget(OctopusApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập họ tên từ 2 đến 100 ký tự.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Nguyễn An',
      );
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ngày sinh của bạn.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('profile-birthday')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-birthday')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '01/01/2005');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(store.profile['birthday'], '2005-01-01');
      for (final provider in ['Google', 'Facebook', 'Số điện thoại']) {
        await tester.scrollUntilVisible(find.text(provider), 200);
        expect(find.widgetWithText(OutlinedButton, provider), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Dùng không đăng nhập'));
      await tester.tap(find.text('Dùng không đăng nhập'));
      await tester.pumpAndSettle();
      final start = find.text('Bắt đầu dùng Octopus');
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(of: start, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
      );
      final addWidget = find.text('Thêm widget nhịp hôm nay (4×2)');
      await tester.scrollUntilVisible(
        addWidget,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(addWidget);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      ScaffoldMessenger.of(tester.element(start)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      device.failNextWrite = true;
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(store.onboardingComplete, isFalse);
      expect(
        find.text('Chưa lưu được thay đổi trên máy. Hãy thử lại.'),
        findsOneWidget,
      );
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(store.onboardingComplete, isTrue);
      expect(store.profile['authMode'], 'guest');
      final reloaded = BrainStore(device: device);
      await reloaded.load();
      expect(reloaded.onboardingComplete, isTrue);
      expect(find.textContaining('Một ngày có chủ đích.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
