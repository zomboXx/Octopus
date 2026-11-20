import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'brain_store.dart';

class PlanningApi {
  PlanningApi({String? endpoint}) : endpoint = endpoint ?? baseUrl;
  final String endpoint;
  HttpClient? _client;
  void cancel() => _client?.close(force: true);
  static const baseUrl = String.fromEnvironment('OCTOPUS_API_URL');
  bool get configured => endpoint.isNotEmpty;
  bool get needsAccessCode => const bool.fromEnvironment(
    'OCTOPUS_API_REQUIRE_CODE',
  );
  String requestId() {
    final rng = Random.secure();
    final hex = List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<String> token(BrainStore store) async {
    final value = await store.device.planningGuestToken();
    if (value == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw const FormatException(
        'Chưa tạo được hồ sơ Starter trên thiết bị. Hãy mở lại Octopus.',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> quota(BrainStore store) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(endpoint).resolve('/v1/plans'));
      req.followRedirects = false;
      req.headers.set(
        HttpHeaders.authorizationHeader,
        'Guest ${await token(store)}',
      );
      final response = await req.close().timeout(const Duration(seconds: 20));
      final data =
          jsonDecode(
                await utf8.decoder
                    .bind(response)
                    .join()
                    .timeout(const Duration(seconds: 10)),
              )
              as Map<String, dynamic>;
      if (response.statusCode != 200 || data['quota'] is! Map) {
        throw const FormatException('Chưa kiểm tra được lượt Starter.');
      }
      return Map<String, dynamic>.from(data['quota']);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> draft(
    BrainStore store,
    String request,
    String learningContext, {
    String accessCode = '',
    String? targetDate,
  }) async {
    if (store.focusEnd?.isAfter(DateTime.now()) == true &&
        store.focusProtected &&
        store.protection['blockInternet'] == true &&
        (await store.device.guardStatus())['networkBlocked'] == true) {
      throw const FormatException(
        'Phiên tập trung đang chặn mạng. Hãy tạo kế hoạch sau khi kết thúc phiên.',
      );
    }
    if (!configured) {
      throw const FormatException(
        'Dịch vụ lập kế hoạch chưa sẵn sàng trong bản này. Hãy cập nhật ứng dụng.',
      );
    }
    if (needsAccessCode && accessCode.trim().isEmpty) {
      throw const FormatException(
        'Nhập mã dùng thử do nhóm Octopus cung cấp để tạo kế hoạch.',
      );
    }
    final base = Uri.parse(endpoint);
    if (base.scheme != 'https' &&
        !(base.scheme == 'http' &&
            ['127.0.0.1', 'localhost', '10.0.2.2'].contains(base.host))) {
      throw const FormatException('Địa chỉ API cần dùng HTTPS.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _client = client;
    try {
      final req = await client.postUrl(base.resolve('/v1/plans'));
      req.followRedirects = false;
      req.headers.contentType = ContentType.json;
      if (needsAccessCode) {
        req.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${accessCode.trim()}',
        );
      } else {
        req.headers.set(
          HttpHeaders.authorizationHeader,
          'Guest ${await token(store)}',
        );
      }
      // Full name, birthday, activity photos and diary are deliberately absent.
      final payload = {
        'request': request,
        'timezone': 'Asia/Ho_Chi_Minh',
        'preferences': store.studyPreferences,
        'commitments': store.commitments,
        'existingPlan': store.plan
            .map(
              (p) => {
                'start': DateTime.parse(p['start']).toUtc().toIso8601String(),
                'end': DateTime.parse(p['end']).toUtc().toIso8601String(),
                'kind': p['kind'],
              },
            )
            .toList(),
        'learningContext': learningContext,
        'targetDate': targetDate,
      };
      final fingerprint = jsonEncode(payload);
      if (store.planningAttempt?['fingerprint'] != fingerprint) {
        store.planningAttempt = {'fingerprint': fingerprint, 'id': requestId()};
        await store.save();
        if (store.storageError != null) {
          throw FormatException(store.storageError!);
        }
      }
      req.headers.set('X-Octopus-Request-Id', store.planningAttempt!['id']);
      req.write(fingerprint);
      final response = await req.close().timeout(const Duration(seconds: 100));
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));
      if (body.length > 250000) {
        throw const FormatException(
          'Kết quả quá lớn. Hãy thử yêu cầu ngắn hơn.',
        );
      }
      Map<String, dynamic> data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        throw const FormatException(
          'Dịch vụ đang tạm gián đoạn. Hãy thử lại sau ít phút.',
        );
      }
      if (response.statusCode != 200) {
        throw FormatException(
          data['error'] is String
              ? data['error']
              : 'Dịch vụ chưa tạo được kế hoạch. Hãy thử lại sau ít phút.',
        );
      }
      if (data['schemaVersion'] != 1 ||
          data['sessions'] is! List ||
          data['questions'] is! List ||
          data['assumptions'] is! List) {
        throw const FormatException('Kết quả chưa đúng định dạng lịch.');
      }
      if (data['quota'] is Map) {
        store.aiQuota = Map<String, dynamic>.from(data['quota']);
      }
      return data;
    } on SocketException {
      throw const FormatException(
        'Không kết nối được dịch vụ lập lịch. Kiểm tra kết nối và thử lại.',
      );
    } on TimeoutException {
      throw const FormatException(
        'Dịch vụ phản hồi quá lâu. Hãy thử lại sau ít phút. Nội dung bạn nhập vẫn được giữ tại đây.',
      );
    } on HttpException {
      throw const FormatException(
        'Kết nối bị gián đoạn. Kiểm tra mạng và thử lại.',
      );
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }
}
