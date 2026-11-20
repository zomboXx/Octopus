import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_mobile/brain_store.dart';
import 'package:octopus_mobile/planning_api.dart';
import 'octopus_test.dart' show MemoryDevice;

class StarterDevice extends MemoryDevice {
  bool networkBlocked = false;
  @override
  Future<String?> planningGuestToken() async => 'a' * 64;
  @override
  Future<Map<String, dynamic>> guardStatus() async => {
    'networkBlocked': networkBlocked,
  };
}

void main() {
  test(
    'native Starter sends a guest identity without a code, retries the saved request ID, and uses actual VPN status',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ids = <String>[], payloads = <Map<String, dynamic>>[];
      var used = 0;
      server.listen((req) async {
        expect(req.headers.value('authorization'), 'Guest ${'a' * 64}');
        req.response.headers.contentType = ContentType.json;
        if (req.method == 'GET') {
          req.response.write(
            jsonEncode({
              'quota': {
                'remaining': 5 - used,
                'used': used,
                'limit': 5,
                'period': '2026-11',
              },
            }),
          );
        } else {
          ids.add(req.headers.value('x-octopus-request-id')!);
          payloads.add(jsonDecode(await utf8.decoder.bind(req).join()));
          if (ids.length == 1) {
            req.response.statusCode = 502;
            req.response.write(jsonEncode({'error': 'Dịch vụ tạm gián đoạn.'}));
          } else {
            used = 1;
            req.response.write(
              jsonEncode({
                'schemaVersion': 1,
                'status': 'draft',
                'sessions': [],
                'questions': [],
                'assumptions': [],
                'quota': {
                  'remaining': 4,
                  'used': 1,
                  'limit': 5,
                  'period': '2026-11',
                },
              }),
            );
          }
        }
        await req.response.close();
      });
      addTearDown(() => server.close(force: true));
      final device = StarterDevice(),
          store = BrainStore(device: StarterDevice());
      final api = PlanningApi(endpoint: 'http://127.0.0.1:${server.port}');
      final value = BrainStore(device: device)
        ..profile['name'] = 'Private name';
      expect((await api.quota(value))['remaining'], 5);
      await expectLater(
        api.draft(value, 'Luyện tiếng Anh', ''),
        throwsA(isA<FormatException>()),
      );
      final restored = BrainStore(device: device);
      await restored.load();
      restored.focusEnd = DateTime.now().add(const Duration(minutes: 30));
      restored.focusProtected = true;
      restored.protection['blockInternet'] = true;
      await api.draft(restored, 'Luyện tiếng Anh', '');
      expect(ids.length, 2);
      expect(ids[0], ids[1]);
      expect(restored.aiQuota['remaining'], 4);
      expect(jsonEncode(payloads), isNot(contains('Private name')));
      expect(payloads.first['commitments'], isEmpty);
      device.networkBlocked = true;
      await expectLater(
        api.draft(restored, 'Luyện tiếng Anh', ''),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('đang chặn mạng'),
          ),
        ),
      );
      expect(ids.length, 2);
      expect(store.commitments, isEmpty);
    },
  );
}
