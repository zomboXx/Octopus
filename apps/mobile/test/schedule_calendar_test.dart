import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/schedule_calendar.dart';
import 'package:octopus_mobile/schedule_screen.dart';
import 'octopus_test.dart' show MemoryDevice;

Map<String, dynamic> session(String id, DateTime date, int minute) => {
  'id': id,
  'title': 'Ôn truy vấn $id',
  'subject': 'DBMS',
  'kind': 'focus',
  'start': date.add(Duration(minutes: minute - 420)).toIso8601String(),
  'end': date.add(Duration(minutes: minute - 375)).toIso8601String(),
  'objectives': ['Hiểu nguyên tắc JOIN'],
  'steps': ['Đọc ví dụ', 'Giải ba câu truy vấn'],
  'expectedOutput': 'Ba truy vấn đã tự kiểm tra',
};

void main() {
  test(
    'status boundaries, completion precedence and fixed time reservations',
    () {
      final start = DateTime.parse('2026-10-24T08:00:00+07:00');
      final entry = session('a', DateTime.utc(2026, 10, 24), 480);
      expect(
        scheduleStatus(
          entry,
          start.subtract(const Duration(minutes: 30)),
        ).relative,
        'Còn 30 phút',
      );
      expect(scheduleStatus(entry, start).key, 'active');
      expect(scheduleStatus(entry, start).needsCheckout, true);
      final end = start.add(const Duration(minutes: 45));
      expect(scheduleStatus(entry, end).key, 'overdue');
      expect(scheduleStatus({...entry, 'fixed': true}, end).key, 'ended');
      expect(
        scheduleStatus({...entry, 'fixed': true}, start).needsCheckout,
        false,
      );
      expect(scheduleStatus({...entry, 'done': true}, end).key, 'done');
      expect(
        scheduleStatus({...entry, 'done': true}, end).needsCheckout,
        false,
      );
      expect(scheduleStatus({'title': 'Chưa đặt giờ'}, start).key, 'unplaced');
    },
  );

  test(
    'Vietnam week dates, multiple entries per cell, periods and recurrence do not mutate saved data',
    () {
      expect(
        dayKey(vietnamCalendarDate(DateTime.parse('2026-12-31T18:00:00Z'))),
        '2027-01-01',
      );
      final monday = calendarMonday(DateTime.utc(2027, 1, 3));
      expect(dayKey(monday), '2026-12-28');
      final store = BrainStore(device: MemoryDevice());
      store.plan.addAll([
        session('a', monday, 480),
        session('b', monday, 540),
        session('pm', monday, 780),
        session('night', monday, 1080),
        session('long', monday.add(const Duration(days: 21)), 480),
      ]);
      store.commitments.add({
        'id': 'school',
        'title': 'Đi học',
        'weekdays': [1],
        'startMinute': 420,
        'endMinute': 480,
      });
      final before = jsonEncode([store.plan, store.commitments]);
      final entries = calendarEntries(store, monday, 1);
      expect(entries.where((e) => e['calendarMinute'] < 720), hasLength(3));
      expect(
        entries.where(
          (e) => e['calendarMinute'] >= 720 && e['calendarMinute'] < 1080,
        ),
        hasLength(1),
      );
      expect(entries.where((e) => e['calendarMinute'] >= 1080), hasLength(1));
      final fourWeeks = calendarEntries(store, monday, 4);
      expect(fourWeeks.where((e) => e['fixed'] == true), hasLength(4));
      expect(fourWeeks.where((e) => e['id'] == 'long'), hasLength(1));
      expect(jsonEncode([store.plan, store.commitments]), before);
      store.dispose();
    },
  );

  testWidgets(
    'list/calendar switch, seven columns, multiweek, details and checkout survive small screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
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
      final monday = calendarMonday(vietnamCalendarDate(DateTime.now()));
      final store = BrainStore(device: MemoryDevice());
      store.plan.addAll([
        session('a', monday, 480),
        session('b', monday, 540),
        session('long', monday.add(const Duration(days: 21)), 780),
      ]);
      store.commitments.add({
        'id': 'school',
        'title': 'Đi học',
        'weekdays': [1],
        'startMinute': 420,
        'endMinute': 480,
      });
      store.tasks.add({
        'id': 'manual',
        'title': 'Đọc ghi chú',
        'date': dayKey(monday),
      });
      const shot = Key('calendar-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: AnimatedBuilder(
                  animation: store,
                  builder: (_, _) => ScheduleOverview(
                    store: store,
                    editFixed: (_) {},
                    sessionBuilder: (p) => SessionCard(
                      key: ValueKey(p['id']),
                      session: p,
                      showStatus: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ôn truy vấn a'), findsOneWidget);
      await tester.tap(find.text('Bảng lịch'));
      await tester.pumpAndSettle();
      final table = tester.widget<Table>(
        find.byKey(const ValueKey('calendar-week-0')),
      );
      expect(table.children, hasLength(4));
      expect(table.children.first.children, hasLength(8));
      final cell = find.byKey(ValueKey('cell-${dayKey(monday)}-0'));
      expect(
        find.descendant(of: cell, matching: find.byType(InkWell)),
        findsNWidgets(3),
      );
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
      }

      await capture('v061-calendar');
      await tester.tap(find.byKey(const ValueKey('calendar-event-a')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hiểu nguyên tắc JOIN'), findsOneWidget);
      expect(find.textContaining('Ba truy vấn đã tự kiểm tra'), findsOneWidget);
      await tester.tap(find.text('Check-out công việc'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Hoàn thành, bỏ qua ghi nhận'));
      await tester.tap(find.text('Hoàn thành, bỏ qua ghi nhận'));
      await tester.pumpAndSettle();
      expect(store.plan.first['done'], true);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 tuần').last);
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsNWidgets(4));
      expect(find.byKey(const ValueKey('calendar-event-long')), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Xem rộng'));
      await tester.tap(find.text('Xem rộng'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Đóng bảng rộng'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đầu việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đầu việc'));
      await tester.pumpAndSettle();
      expect(find.text('Đã hoàn thành'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
