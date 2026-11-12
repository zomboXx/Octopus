// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/device_bridge.dart';

Future<void> driver(String phase) async {
  final marker = File('${Directory.systemTemp.path}/octopus-guard-phase');
  final ack = File('${Directory.systemTemp.path}/octopus-guard-ack');
  if (ack.existsSync()) ack.deleteSync();
  await marker.writeAsString(phase, flush: true);
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(deadline)) {
    if (ack.existsSync() && ack.readAsStringSync().trim() == phase) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError(
    'Driver did not acknowledge $phase. Run scripts/guard-automation.py on the dedicated AVD.',
  );
}

Future<Map<String, dynamic>> waitStatus(
  DeviceBridge device,
  bool Function(Map<String, dynamic>) match, {
  int seconds = 15,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  var status = <String, dynamic>{};
  do {
    status = await device.guardStatus();
    if (match(status)) return status;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  } while (DateTime.now().isBefore(end));
  throw StateError('Guard condition timed out: $status');
}

Future<bool> networkWorks() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .getUrl(Uri.parse('http://10.0.2.2:4188/health'))
        .timeout(const Duration(seconds: 4));
    final response = await request.close().timeout(const Duration(seconds: 4));
    await response.drain<void>().timeout(const Duration(seconds: 4));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real Android: usage, background schedule, 30/60 alert, VPN, expiry and revocation',
    (tester) async {
      final device = DeviceBridge();
      final original = await device.readState();
      final store = BrainStore(device: device);
      await store.load();
      // No HomeShell timer: expiry must be enforced natively while the UI is absent.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Native guard integration test')),
        ),
      );
      try {
        await driver('permissions');
        await waitStatus(
          device,
          (s) => s['accessibility'] == true && s['vpnPrepared'] == true,
        );
        expect(
          await networkWorks(),
          isTrue,
          reason: 'Baseline network must work before testing the VPN',
        );
        store.protection = {
          'enabled': true,
          'watchSchedule': true,
          'watchFixed': true,
          'blockInternet': true,
          'sound': true,
        };
        store.restricted = {'com.android.chrome'};
        store.focusStart = null;
        store.focusEnd = null;
        store.commitments = [];
        final now = DateTime.now();
        store.plan = [
          {
            'id': 'guard-test',
            'kind': 'study',
            'title': 'Ôn DBMS · kiểm thử nền',
            'start': now.add(const Duration(seconds: 8)).toIso8601String(),
            'end': now.add(const Duration(minutes: 8)).toIso8601String(),
          },
        ];
        await store.save();
        await device.resumeProtection();
        await driver('schedule_chrome');
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(
          (await device.guardStatus())['overlayVisible'],
          isFalse,
          reason: 'No alert before the scheduled start',
        );
        await waitStatus(
          device,
          (s) => s['alertActive'] == true && s['overlayVisible'] == true,
        );
        final alertStart = DateTime.now();
        expect(
          await networkWorks(),
          isTrue,
          reason: 'Scheduled work must keep study resources online',
        );
        await driver('capture_schedule');
        await waitStatus(
          device,
          (s) => s['alertActive'] == false && s['overlayVisible'] == false,
          seconds: 35,
        );
        final warningSeconds = DateTime.now().difference(alertStart).inSeconds;
        expect(warningSeconds, inInclusiveRange(25, 34));
        await Future<void>.delayed(const Duration(seconds: 52));
        expect(
          (await device.guardStatus())['overlayVisible'],
          isFalse,
          reason: 'No interruption during 60s cooldown',
        );
        await waitStatus(device, (s) => s['alertActive'] == true, seconds: 15);
        expect(
          DateTime.now().difference(alertStart).inSeconds,
          inInclusiveRange(85, 97),
        );
        print(
          'GUARD_SCHEDULE_OK red=${warningSeconds}s repeat=${DateTime.now().difference(alertStart).inSeconds}s',
        );
        await driver('return_app');
        await waitStatus(device, (s) => s['overlayVisible'] == false);
        store.plan = [];
        await store.startFocus(1);
        await waitStatus(device, (s) => s['networkBlocked'] == true);
        expect(
          await networkWorks(),
          isFalse,
          reason:
              'The app UID must actually lose Internet through the local VPN',
        );
        await driver('focus_chrome');
        await waitStatus(device, (s) => s['alertActive'] == true);
        await driver('capture_focus');
        await waitStatus(
          device,
          (s) => s['alertActive'] == false && s['overlayVisible'] == true,
          seconds: 35,
        );
        await driver('capture_shield');
        expect(
          (await device.guardStatus())['networkBlocked'],
          isTrue,
          reason: 'Cooldown does not reopen Internet',
        );
        await driver('dialer');
        await waitStatus(device, (s) => s['overlayVisible'] == false);
        expect((await device.guardStatus())['networkBlocked'], isTrue);
        await driver('focus_chrome_again');
        await waitStatus(device, (s) => s['overlayVisible'] == true);
        await waitStatus(
          device,
          (s) => s['networkBlocked'] == false && s['overlayVisible'] == false,
          seconds: 35,
        );
        expect(
          await networkWorks(),
          isTrue,
          reason: 'Native expiry must restore network without Flutter timer',
        );
        await driver('return_after_expiry');
        await store.finishFocus();
        await store.startFocus(5);
        await waitStatus(device, (s) => s['networkBlocked'] == true);
        await device.cancelFocus('Test urgent work');
        await waitStatus(device, (s) => s['networkBlocked'] == false);
        expect(await networkWorks(), isTrue);
        await store.finishFocus();
        final usage = await device.usage();
        expect(usage['granted'], isTrue);
        expect((usage['days'] as List).length, 7);
        final totalDays = (usage['days'] as List).fold<num>(
          0,
          (n, d) => n + (d['milliseconds'] as num),
        );
        final totalApps = (usage['apps'] as List).fold<num>(
          0,
          (n, a) => n + (a['milliseconds'] as num),
        );
        expect(totalDays, totalApps);
        final chrome = (usage['apps'] as List).where(
          (a) => a['package'] == 'com.android.chrome',
        );
        expect(chrome, isNotEmpty);
        expect(chrome.first['milliseconds'] as num, greaterThan(60000));
        final history = await device.guardEvents();
        expect(
          history.where((e) => e['type'] == 'interruption').length,
          greaterThanOrEqualTo(3),
        );
        expect(
          history.any(
            (e) => e['type'] == 'early_exit' && e['note'] == 'Test urgent work',
          ),
          isTrue,
        );
        store.protection['watchSchedule'] = false;
        final fixedNow = DateTime.now();
        final minute = fixedNow.hour * 60 + fixedNow.minute;
        store.commitments = [
          {
            'id': 'fixed-guard',
            'title': 'Fixed timetable test',
            'weekdays': [fixedNow.weekday],
            'startMinute': minute,
            'endMinute': (minute + 2).clamp(1, 1440),
          },
        ];
        await store.save();
        await driver('fixed_chrome');
        await waitStatus(
          device,
          (s) =>
              s['alertActive'] == true &&
              s['activeTitle'] == 'Fixed timetable test',
        );
        await driver('return_fixed');
        store.commitments = [];
        await store.save();
        await driver('revoke_accessibility');
        await waitStatus(device, (s) => s['accessibility'] == false);
        await driver('restore_accessibility');
        await waitStatus(device, (s) => s['accessibility'] == true);
        print(
          'GUARD_NATIVE_OK usage_days=7 chrome_ms=${chrome.first['milliseconds']} network=blocked/restored dialer=allowed early_exit=logged accessibility=revoke/restore',
        );
        await File(
          '${Directory.systemTemp.path}/octopus-guard-result.json',
        ).writeAsString(
          jsonEncode({
            'ok': true,
            'warningSeconds': warningSeconds,
            'usage': usage,
            'history': history,
          }),
          flush: true,
        );
      } finally {
        await device.writeState(original ?? '{"version":1}');
        await driver('done');
        await waitStatus(device, (s) => s['accessibility'] == false);
      }
      // External activities suspend the integration binding's frame scheduling.
      // Restore it before letting the harness dispose the semantics tree.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
