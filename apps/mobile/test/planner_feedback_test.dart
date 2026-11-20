import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/planning_api.dart';
import 'package:octopus_mobile/schedule_screen.dart';
import 'octopus_test.dart' show MemoryDevice;

class PendingPlanningApi extends PlanningApi {
  @override
  Future<Map<String, dynamic>> quota(BrainStore store) async => {
    'remaining': 5,
    'period': '2026-11',
  };
  final responses = <Completer<Map<String, dynamic>>>[];
  final requests = <String>[];
  bool cancelled = false;

  @override
  Future<Map<String, dynamic>> draft(
    BrainStore store,
    String request,
    String learningContext, {
    String accessCode = '',
    String? targetDate,
  }) {
    requests.add(request);
    final response = Completer<Map<String, dynamic>>();
    responses.add(response);
    return response.future;
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

void main() {
  Future<void> open(WidgetTester tester, PendingPlanningApi api) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xff2463eb)),
        home: StudyPlannerScreen(
          store: BrainStore(device: MemoryDevice()),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('planner-goal')),
      'Ôn lập trình web phần session',
    );
    expect(find.byKey(const Key('planner-code')), findsNothing);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Tạo kế hoạch để xem trước'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'network failure replaces visible progress with a dialog and preserves the form',
    (tester) async {
      final api = PendingPlanningApi();
      await open(tester, api);
      await submit(tester);
      expect(find.text('Đang tạo kế hoạch'), findsOneWidget);
      expect(find.text('Hủy yêu cầu'), findsOneWidget);
      api.responses.single.completeError(
        const FormatException('Dịch vụ tạm gián đoạn. Hãy thử lại.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đang tạo kế hoạch'), findsNothing);
      expect(find.byKey(const Key('planner-error')), findsOneWidget);
      await tester.tap(find.text('Quay lại chỉnh sửa'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('planner-goal')))
            .controller!
            .text,
        api.requests.single,
      );
      expect(find.byKey(const Key('planner-code')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'clarification can be answered in place and results scroll into view',
    (tester) async {
      final api = PendingPlanningApi();
      await open(tester, api);
      await submit(tester);
      api.responses.single.complete({
        'schemaVersion': 1,
        'status': 'needs_clarification',
        'summary': 'Bạn muốn luyện thêm phần nào?',
        'questions': [
          'Bạn muốn tập cách lưu thông tin đăng nhập hay xử lý đăng xuất?',
        ],
        'assumptions': [],
        'sessions': [],
      });
      await tester.pumpAndSettle();
      expect(find.text('Bổ sung thông tin'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Thông tin bổ sung'),
        'Tập lưu thông tin đăng nhập',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bổ sung và thử lại'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.requests.last, contains('Tập lưu thông tin đăng nhập'));
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      api.responses.last.complete({
        'schemaVersion': 1,
        'status': 'draft',
        'summary': 'Một buổi luyện đăng nhập',
        'questions': [],
        'assumptions': [],
        'sessions': [
          {
            'slotId': 'slot-1',
            'title': 'Lưu thông tin đăng nhập',
            'subject': 'Lập trình web',
            'start': DateTime(
              tomorrow.year,
              tomorrow.month,
              tomorrow.day,
              18,
            ).toIso8601String(),
            'end': DateTime(
              tomorrow.year,
              tomorrow.month,
              tomorrow.day,
              18,
              45,
            ).toIso8601String(),
            'objectives': ['Hiểu cách lưu phiên'],
            'steps': ['Thực hành đăng nhập'],
            'expectedOutput': 'Một trang đăng nhập chạy được',
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Kế hoạch đề xuất · 1 buổi').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Xác nhận thêm vào lịch').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cancelled requests never show a late result', (tester) async {
    final api = PendingPlanningApi();
    await open(tester, api);
    await submit(tester);
    await tester.tap(find.text('Hủy yêu cầu'));
    await tester.pumpAndSettle();
    expect(api.cancelled, isTrue);
    api.responses.single.completeError(const FormatException('Late error'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Tạo kế hoạch để xem trước').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
