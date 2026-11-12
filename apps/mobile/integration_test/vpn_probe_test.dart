// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/device_bridge.dart';
import 'guard_test.dart' as harness;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('VPN blocks new connections after Android installs its routes', (
    tester,
  ) async {
    final device = DeviceBridge();
    final original = await device.readState();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('VPN probe'))),
    );
    try {
      await harness.driver('permissions');
      await harness.waitStatus(
        device,
        (s) => s['accessibility'] == true && s['vpnPrepared'] == true,
      );
      expect(await harness.networkWorks(), isTrue);
      final store = BrainStore()..protection['enabled'] = true;
      await store.startFocus(5);
      await harness.waitStatus(device, (s) => s['networkBlocked'] == true);
      await Future<void>.delayed(const Duration(seconds: 2));
      final works = await harness.networkWorks();
      print('VPN_PROBE works=$works status=${await device.guardStatus()}');
      await harness.driver('capture_vpn');
      expect(works, isFalse);
      expect((await device.guardStatus())['droppedPackets'], greaterThan(0));
      await store.finishFocus();
      await harness.waitStatus(device, (s) => s['networkBlocked'] == false);
      expect(await harness.networkWorks(), isTrue);
    } finally {
      await device.writeState(original ?? '{"version":1}');
      await harness.driver('done');
      await harness.waitStatus(device, (s) => s['accessibility'] == false);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}
