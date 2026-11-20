import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/main.dart';
import 'package:octopus_mobile/usage_screen.dart';
import 'package:octopus_mobile/usage_day_screen.dart';
import 'package:octopus_mobile/protection_screen.dart';
import 'package:octopus_mobile/usage_reminder_card.dart';
import 'octopus_test.dart' show MemoryDevice;

class UsageDevice extends MemoryDevice {
  bool allowed = true;
  @override
  Future<Map<String, dynamic>> usage() async => {
    'granted': allowed,
    'apps': allowed
        ? [
            {
              'package': 'video.test',
              'name': 'Video app',
              'milliseconds': 14400000,
            },
            {'package': 'study.test', 'name': 'Study', 'milliseconds': 3600000},
          ]
        : [],
    'days': allowed
        ? List.generate(
            7,
            (i) => {
              'date': '2026-10-${13 + i}',
              'milliseconds': i < 3 ? 6000000 : 0,
            },
          )
        : [],
  };
}

class ReminderReviewDevice extends MemoryDevice {
  int previews = 0;
  @override
  Future<void> testUsageReminder() async {
    previews++;
  }
}

class UnavailableGuard extends MemoryDevice {
  int protectionCancellations = 0;
  @override
  Future<Map<String, dynamic>> guardStatus() async => {'accessibility': false};
  @override
  Future<List<Map<String, dynamic>>> installedApps() async => [];
  @override
  Future<void> cancelFocus(String reason, {bool completed = false}) async {
    protectionCancellations++;
  }
}

class WeeklyUsageDevice extends MemoryDevice {
  final weeks = <String>[];
  String? openedDay;
  bool notifications = false;
  @override
  Future<Map<String, dynamic>> usageWeek(String start) async {
    weeks.add(start);
    final monday = DateTime.parse(start);
    final days = List.generate(
      7,
      (i) => {
        'date': dayKey(monday.add(Duration(days: i))),
        'milliseconds': (i + 1) * 600000,
        'apps': [
          {
            'package': 'video.test',
            'name': 'Video app',
            'milliseconds': (i + 1) * 600000,
          },
        ],
      },
    );
    return {
      'granted': true,
      'days': days,
      'apps': [
        {
          'package': 'video.test',
          'name': 'Video app',
          'milliseconds': 16800000,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> usageDay(String date) async {
    openedDay = date;
    return {
      'granted': true,
      'days': [
        {
          'date': date,
          'milliseconds': 600000,
          'apps': [
            {
              'package': 'video.test',
              'name': 'Video app',
              'milliseconds': 600000,
            },
          ],
          'sessions': [],
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> guardStatus() async => {
    'accessibility': true,
    'vpnPrepared': true,
    'notifications': notifications,
  };
  @override
  Future<void> requestNotifications() async {
    notifications = true;
  }

  @override
  Future<List<Map<String, dynamic>>> installedApps() async => [
    {'package': 'study.test', 'name': 'Study app'},
    {'package': 'video.test', 'name': 'Video app'},
  ];
}

void main() {
  testWidgets('strong reminders are opt-in, persist, and can be previewed', (
    tester,
  ) async {
    final device = ReminderReviewDevice();
    final store = BrainStore(device: device);
    expect(store.protection['usageReminderStrong'], isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UsageReminderCard(store: store)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nhắc mạnh hơn'));
    await tester.tap(find.text('Nhắc mạnh hơn'));
    await tester.pumpAndSettle();
    final restored = BrainStore(device: device);
    await restored.load();
    expect(restored.protection['usageReminderStrong'], isTrue);
    await tester.ensureVisible(find.text('Gửi thông báo thử'));
    await tester.tap(find.text('Gửi thông báo thử'));
    await tester.pumpAndSettle();
    expect(device.previews, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'weekly navigation requests the selected week and a day column opens its app details',
    (tester) async {
      final device = WeeklyUsageDevice();
      final store = BrainStore(device: device);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UsagePanel(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final current = usageWeekStart(DateTime.now());
      expect(device.weeks.single, dayKey(current));
      await tester.tap(find.byTooltip('Tuần trước'));
      await tester.pumpAndSettle();
      final previous = current.subtract(const Duration(days: 7));
      expect(device.weeks.last, dayKey(previous));
      final bar = find.byTooltip('${dayKey(previous)} · 10 phút');
      await tester.ensureVisible(bar);
      await tester.pumpAndSettle();
      await tester.tap(bar);
      await tester.pumpAndSettle();
      expect(find.byType(UsageDayScreen), findsOneWidget);
      expect(device.openedDay, dayKey(previous));
      expect(find.text('Video app'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'notification permission row refreshes its state after the system request completes',
    (tester) async {
      final device = WeeklyUsageDevice();
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectionScreen(store: BrainStore(device: device)),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.text('Cho phép thông báo');
      await tester.scrollUntilVisible(row, 220);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(device.notifications, isTrue);
      expect(
        find.text(
          'Đã cho phép. Nhắc nghỉ và nhắc dùng app lâu được bật riêng.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'guard summary distinguishes enabled permission, broken connection, disabled protection and a waiting schedule',
    () {
      final store = BrainStore();
      expect(
        guardSummary(store, {
          'accessibilityEnabled': true,
          'accessibility': false,
        }),
        'Dịch vụ Trợ năng đang ngắt',
      );
      expect(guardSummary(store, {'accessibility': true}), 'Bảo vệ đang tắt');
      store.protection['enabled'] = true;
      expect(
        guardSummary(store, {'accessibility': true}),
        'Đã bật · chờ lịch hoặc phiên tập trung',
      );
      expect(
        guardSummary(store, {
          'accessibility': true,
          'activeTitle': 'Học tiếng Anh',
        }),
        'Đang bảo vệ tập trung',
      );
    },
  );

  testWidgets(
    'unfinished past work stays visible and a task can move to today',
    (tester) async {
      final device = MemoryDevice();
      final store = BrainStore(device: device)..onboardingComplete = true;
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10);
      await store.addTask('Việc cũ', 20, yesterday);
      await store.addTask('Việc đã xong', 20, yesterday);
      store.tasks.last['done'] = true;
      store.plan.add({
        'id': 'old-plan',
        'title': 'Phiên cũ',
        'kind': 'study',
        'start': yesterday.toIso8601String(),
        'end': yesterday.add(const Duration(minutes: 30)).toIso8601String(),
      });

      await tester.pumpWidget(OctopusApp(store: store));
      await tester.pumpAndSettle();
      final move = find.text('Dời sang hôm nay');
      await tester.scrollUntilVisible(
        move,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Chưa xong từ trước (2)'), findsOneWidget);
      expect(find.text('Việc đã xong'), findsNothing);
      await tester.ensureVisible(move);
      await tester.pumpAndSettle();
      await tester.tap(move);
      await tester.pumpAndSettle();
      expect(store.tasks.first['date'], dayKey(now));
      expect(store.overdueWork(now).single.item['id'], 'old-plan');
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restored.workOn(now).single['title'], 'Việc cũ');
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'suggestions require enough observed days and respect permanent opt-out after restore',
    () async {
      final device = UsageDevice(), store = BrainStore();
      final data = await device.usage();
      final apps = rows(data['apps']), days = rows(data['days']);
      expect(restrictionSuggestion(apps, days.take(2).toList(), store), isNull);
      expect(
        restrictionSuggestion(apps, days, store)?['package'],
        'video.test',
      );
      final saved = BrainStore(device: device)
        ..dismissedSuggestions.add('video.test');
      saved.protection['enabled'] = true;
      await saved.save();
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restrictionSuggestion(apps, days, restored), isNull);
      expect(restored.protection['enabled'], isTrue);
    },
  );
  testWidgets(
    'real usage shape renders both charts and permission revocation hides data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = UsageDevice();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UsagePanel(store: BrainStore(device: device)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UsageBars), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(UsageDistribution), 200);
      expect(find.byType(UsageDistribution), findsOneWidget);
      expect(tester.takeException(), isNull);
      device.allowed = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(UsageBars), findsNothing);
      expect(find.byType(UsageDistribution), findsNothing);
      expect(find.text('Mở quyền sử dụng'), findsOneWidget);
    },
  );
  testWidgets(
    'protected focus asks for permission and a plain timer works without it',
    (tester) async {
      final device = UnavailableGuard();
      final store = BrainStore(device: device)..onboardingComplete = true;
      await tester.pumpWidget(OctopusApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tập trung'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu phiên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu phiên'));
      await tester.pumpAndSettle();
      expect(store.focusEnd, isNull);
      expect(
        find.text('Bạn cấp quyền. Bạn giữ quyền kiểm soát.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      final timer = find.text('Chỉ đếm giờ');
      await tester.ensureVisible(timer);
      await tester.pumpAndSettle();
      await tester.tap(timer);
      await tester.pumpAndSettle();
      expect(find.text('Đang đếm giờ'), findsOneWidget);
      expect(store.focusEnd, isNotNull);
      final restored = BrainStore(device: device);
      await restored.load();
      expect(restored.focusEnd, store.focusEnd);
      expect(restored.focusProtected, isFalse);
      await tester.ensureVisible(find.text('Kết thúc phiên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kết thúc phiên'));
      await tester.pumpAndSettle();
      expect(store.focusEnd, isNull);
      expect(device.protectionCancellations, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
