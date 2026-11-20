import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/planning_api.dart';
import 'package:octopus_mobile/schedule_screen.dart';
import 'package:octopus_mobile/time_picker.dart';
import 'octopus_test.dart' show MemoryDevice;

class FirstPlanApi extends PlanningApi {
  @override
  Future<Map<String, dynamic>> quota(BrainStore store) async => {
    'remaining': 5,
    'period': '2026-11',
  };
  int calls = 0;
  @override
  bool get needsAccessCode => false;
  @override
  Future<Map<String, dynamic>> draft(
    BrainStore store,
    String request,
    String learningContext, {
    String accessCode = '',
    String? targetDate,
  }) async {
    calls++;
    return {
      'schemaVersion': 1,
      'status': 'draft',
      'summary': 'Sáu buổi luyện tập',
      'questions': [],
      'assumptions': [],
      'sessions': List.generate(6, (i) {
        final date = DateTime.now().add(Duration(days: i + 1));
        return {
          'slotId': 'slot-$i',
          'subject': 'Tiếng Anh',
          'title': 'Luyện nói ${i + 1}',
          'start': '${dayKey(date)}T18:00:00+07:00',
          'end': '${dayKey(date)}T18:45:00+07:00',
          'examDate': dayKey(DateTime.now().add(const Duration(days: 10))),
          'objectives': ['Hỏi đường'],
          'steps': ['Luyện hội thoại'],
          'expectedOutput': 'Nói được ba câu hỏi đường',
        };
      }),
    };
  }
}

void main() {
  testWidgets(
    '24-hour keyboard entry is exact even when the device uses a 12-hour clock',
    (tester) async {
      TimeOfDay? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: const MediaQueryData(alwaysUse24HourFormat: false),
              child: Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await pickAppTime(
                      context,
                      const TimeOfDay(hour: 12, minute: 0),
                      entryMode: TimePickerEntryMode.input,
                    );
                  },
                  child: const Text('Pick'),
                ),
              ),
            ),
          ),
        ),
      );
      for (final hour in ['10', '11', '00', '12', '23']) {
        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.first, hour);
        await tester.enterText(fields.last, '00');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(selected, TimeOfDay(hour: int.parse(hour), minute: 0));
      }
    },
  );

  testWidgets(
    'deleting a recurring schedule can restore its complete saved weekly interval',
    (tester) async {
      final device = MemoryDevice();
      final original = {
        'id': 'school',
        'title': 'Đi học',
        'weekdays': [1, 3],
        'startMinute': 8 * 60,
        'endMinute': 10 * 60,
      };
      final saved = BrainStore(device: device)..commitments.add(original);
      await saved.save();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: saved,
              builder: (_, child) => ScheduleScreen(store: saved),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Xóa lịch cố định'));
      await tester.pumpAndSettle();
      expect(saved.commitments, isEmpty);
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      final reloaded = BrainStore(device: device);
      await reloaded.load();
      expect(reloaded.commitments.single, original);
    },
  );

  testWidgets(
    'AI preview survives Android Back and reload with exactly the retained sessions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = MemoryDevice(), api = FirstPlanApi();
      final store = BrainStore(device: device);
      Widget app(BrainStore value) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => StudyPlannerScreen(store: value, api: api),
                ),
              ),
              child: const Text('Open planner'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('Open planner'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('planner-goal')),
        'Luyện nói tiếng Anh',
      );
      await tester.tap(find.text('Tạo kế hoạch để xem trước'));
      await tester.pumpAndSettle();
      expect(find.text('Kế hoạch đề xuất · 6 buổi'), findsOneWidget);
      await tester.ensureVisible(find.text('Bỏ phiên này').first);
      await tester.tap(find.text('Bỏ phiên này').first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      final restored = BrainStore(device: device);
      await restored.load();
      expect((restored.planningDraft!['result']['sessions'] as List).length, 5);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(restored));
      await tester.tap(find.text('Open planner'));
      await tester.pumpAndSettle();
      expect(find.text('Kế hoạch đề xuất · 5 buổi'), findsOneWidget);
      expect(api.calls, 1);
      await tester.tap(find.text('Xác nhận thêm vào lịch'));
      await tester.pumpAndSettle();
      final reopened = BrainStore(device: device);
      await reopened.load();
      expect(reopened.plan.length, 5);
      expect(reopened.planningDraft, isNull);
      expect(api.calls, 1);
    },
  );
}
