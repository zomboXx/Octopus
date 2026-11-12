// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/main.dart';
import 'guard_test.dart' show driver;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Launcher widgets: text, focus countdown, complete and voice cancellation',
    (tester) async {
      final store = BrainStore();
      await store.load();
      final original = await store.device.readState();
      store.onboardingComplete = true;
      store.profile = {'name': 'Widget Test', 'voiceDisclosureAccepted': true};
      store.plan.clear();
      store.tasks.clear();
      store.commitments.clear();
      store.focusEnd = null;
      store.focusStart = null;
      store.protection.addAll({
        'enabled': true,
        'disclosureAccepted': true,
        'sound': false,
      });
      await store.addTask('Widget reading', 30, DateTime.now());
      await store.addTask('Next revision', 25, DateTime.now());
      var passed = false;
      try {
        await tester.pumpWidget(OctopusApp(store: store));
        await tester.pumpAndSettle();
        await driver('permissions');
        final status = await store.device.widgetStatus();
        for (final kind in ['tasks', 'focus']) {
          if (status[kind] != true) {
            await store.device.pinWidget(kind);
            await driver('pin_$kind');
          }
        }
        await driver('widget_add');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'Added from launcher',
        );
        await tester.tap(find.text('Thêm việc'));
        await tester.pumpAndSettle();
        expect(
          store.tasks.any((t) => t['title'] == 'Added from launcher'),
          true,
        );
        await driver('widget_focus');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(store.focusEnd, isNotNull);
        expect(store.focusEnd!.difference(store.focusStart!).inMinutes, 30);
        await driver('widget_complete');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(store.tasks.first['done'], true);
        expect(store.focusEnd, isNull);
        expect(
          (await store.device.guardEvents()).any(
            (e) => e['type'] == 'work_completed',
          ),
          true,
        );
        // Completion performs native cancellation and multiple state writes
        // before opening checkout. Wait for that UI boundary, not only a frame.
        for (
          var i = 0;
          i < 25 && find.text('Bạn đã làm được gì?').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã làm được gì?'), findsOneWidget);
        await tester.ensureVisible(find.text('Hoàn thành, bỏ qua ghi nhận'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hoàn thành, bỏ qua ghi nhận'));
        await tester.pumpAndSettle();
        final count = store.tasks.length;
        await driver('widget_voice');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await driver('speech_cancel');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          store.tasks.length,
          count,
          reason: 'Cancelling speech must not create a task',
        );
        final now = DateTime.now();
        store.plan = [
          {
            'id': 'widget-overdue',
            'kind': 'focus',
            'title': 'Phiên còn dang dở',
            'start': now
                .subtract(const Duration(minutes: 120))
                .toIso8601String(),
            'end': now.subtract(const Duration(minutes: 90)).toIso8601String(),
          },
          {
            'id': 'widget-now',
            'kind': 'focus',
            'title': 'Ôn DBMS · truy vấn lồng',
            'start': now
                .subtract(const Duration(minutes: 10))
                .toIso8601String(),
            'end': now.add(const Duration(minutes: 25)).toIso8601String(),
          },
          {
            'id': 'widget-next',
            'kind': 'focus',
            'title': 'Ôn CNPM',
            'start': now.add(const Duration(minutes: 45)).toIso8601String(),
            'end': now.add(const Duration(minutes: 75)).toIso8601String(),
          },
        ];
        await store.save();
        expect(
          (await store.device.guardStatus())['activeTitle'],
          'Ôn DBMS · truy vấn lồng',
        );
        await driver('widget_schedule');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        print(
          'WIDGET_FLOW_OK text=true focus=30m countdown=true complete=true voice_cancel=true schedule=true',
        );
        passed = true;
      } catch (e, stack) {
        print('WIDGET_TEST_FAILURE $e\n$stack');
        rethrow;
      } finally {
        if (original != null) await store.device.writeState(original);
        try {
          await driver('done');
        } catch (e) {
          print('WIDGET_CLEANUP_DRIVER $e');
          if (passed) rethrow;
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
