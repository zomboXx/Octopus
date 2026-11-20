import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/task_editor.dart';
import 'package:octopus_mobile/record_actions.dart';
import 'package:octopus_mobile/activity_history.dart';
import 'package:octopus_mobile/usage_day_screen.dart';
import 'package:octopus_mobile/usage_screen.dart';
import 'octopus_test.dart' show MemoryDevice;

class JournalDevice extends MemoryDevice {
  bool failSave = false, failUsage = false;
  int usageRequests = 0;
  @override
  Future<void> writeState(String value) async {
    if (failSave) throw StateError('disk full');
    await super.writeState(value);
  }

  @override
  Future<Map<String, dynamic>> usageWeek(String start) async => {
    'granted': false,
    'days': [],
    'apps': [],
  };
  @override
  Future<Map<String, dynamic>> usageDay(String date) async {
    usageRequests++;
    if (failUsage) throw StateError('no history');
    return {'granted': false};
  }
}

void main() {
  testWidgets(
    'editing a completed task retains identity, completion and recipient metadata',
    (tester) async {
      final device = JournalDevice();
      final value = BrainStore(device: device),
          task = <String, dynamic>{
            'id': 'task',
            'title': 'Nhập nhầm',
            'minutes': 30,
            'date': dayKey(DateTime.now()),
            'done': true,
            'completedAt': DateTime.now().toIso8601String(),
            'reflection': 'Đã xong',
            'audience': 'selected',
            'recipients': ['member'],
            'custom': 'keep',
          };
      final before = Map<String, dynamic>.from(task);
      value.tasks.add(task);
      await value.save();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskEditor(store: value, task: task),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('edit-task-title')),
        'Tên đã sửa',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Thời lượng (phút)'),
        '60',
      );
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restored.tasks.single, {
        ...before,
        'title': 'Tên đã sửa',
        'minutes': 60,
        'note': '',
      });
      expect(restored.tasks.single['recipients'], ['member']);
    },
  );
  testWidgets(
    'task move and delete undo save the same record; active focus rejects a move',
    (tester) async {
      final device = JournalDevice();
      final value = BrainStore(device: device),
          task = <String, dynamic>{
            'id': 'task',
            'title': 'Đọc sách',
            'minutes': 30,
            'date': dayKey(DateTime.now()),
            'done': false,
          };
      value.tasks.add(task);
      await value.save();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskActions(store: value, task: task),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Tùy chọn việc Đọc sách'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dời sang ngày mai'));
      await tester.pumpAndSettle();
      expect(task['date'], dayKey(DateTime.now().add(const Duration(days: 1))));
      value.focusTaskId = 'task';
      value.focusEnd = DateTime.now().add(const Duration(minutes: 30));
      await tester.tap(find.byTooltip('Tùy chọn việc Đọc sách'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dời sang hôm nay'));
      await tester.pumpAndSettle();
      expect(task['date'], dayKey(DateTime.now().add(const Duration(days: 1))));
      value.focusTaskId = null;
      value.focusEnd = null;
      await tester.tap(find.byTooltip('Tùy chọn việc Đọc sách'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa công việc'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa công việc'));
      await tester.pumpAndSettle();
      expect(value.tasks, isEmpty);
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restored.tasks.single, task);
    },
  );
  testWidgets(
    'all activities remain searchable and editable when old, without Usage Access',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = JournalDevice();
      final value = BrainStore(device: device),
          old = <String, dynamic>{
            'id': 'old',
            'title': 'Đọc sách ở thư viện',
            'note': 'Ba ý chính',
            'start': '2026-10-01T08:00:45.123',
            'end': '2026-10-01T09:00:50.456',
            'audience': 'group',
            'recipients': [],
            'image': null,
            'custom': 'keep',
          };
      value.activities.addAll([
        old,
        ...List.generate(
          2,
          (i) => {
            'id': 'new-$i',
            'title': 'Hoạt động mới $i',
            'start': DateTime.now()
                .subtract(Duration(hours: i + 2))
                .toIso8601String(),
            'end': DateTime.now()
                .subtract(Duration(hours: i + 1))
                .toIso8601String(),
          },
        ),
      ]);
      await value.save();
      await tester.pumpWidget(
        MaterialApp(home: ActivityHistoryScreen(store: value)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm hoạt động'),
        'thư viện',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 3 hoạt động'), findsOneWidget);
      expect(device.usageRequests, 0);
      await tester.tap(
        find.byTooltip('Tùy chọn hoạt động Đọc sách ở thư viện'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sửa hoạt động'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên hoạt động'),
        'Đọc và ghi chú',
      );
      await tester.ensureVisible(find.text('Lưu hoạt động'));
      await tester.tap(find.text('Lưu hoạt động'));
      await tester.pumpAndSettle();
      final restored = BrainStore(device: device);
      await restored.load();
      final record = restored.activities.first;
      expect(record['title'], 'Đọc và ghi chú');
      expect(record['start'], '2026-10-01T08:00:45.123');
      expect(record['end'], '2026-10-01T09:00:50.456');
      expect(record['custom'], 'keep');
      expect(record['audience'], 'group');
    },
  );
  testWidgets(
    'local day notes survive denied permission and Android statistics errors',
    (tester) async {
      final device = JournalDevice();
      final actual = BrainStore(device: device)
        ..activities.add({
          'id': 'note',
          'title': 'Ghi chép riêng',
          'note': 'Nội dung vẫn đọc được',
          'start': '2026-11-18T08:00:00',
          'end': '2026-11-18T09:00:00',
        });
      for (final fail in [false, true]) {
        device.failUsage = fail;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: UsageDayScreen(store: actual, date: '2026-11-18'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ghi chép riêng'), findsOneWidget);
        expect(find.text('Nội dung vẫn đọc được'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UsagePanel(store: actual)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhật ký của bạn'), findsOneWidget);
      expect(find.text('Xem tất cả hoạt động (1)'), findsOneWidget);
    },
  );
  test(
    'failed writes restore the complete old record and never change the stored copy',
    () async {
      final device = JournalDevice();
      final actual = BrainStore(device: device)
        ..tasks.add({
          'id': 't',
          'title': 'Old',
          'date': '2026-11-19',
          'minutes': 30,
          'done': false,
        });
      await actual.save();
      device.failSave = true;
      expect(
        await actual.updateRecord(actual.tasks, 't', {
          'title': 'New',
          'note': 'changed',
        }),
        false,
      );
      expect(actual.tasks.single['title'], 'Old');
      expect(actual.tasks.single.containsKey('note'), false);
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restored.tasks, actual.tasks);
    },
  );
}
