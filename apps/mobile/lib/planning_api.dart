import 'dart:convert';
import 'dart:io';
import 'brain_store.dart';

class PlanningApi {
  static const baseUrl = String.fromEnvironment('OCTOPUS_API_URL');
  static const requireBetaCode = bool.fromEnvironment(
    'OCTOPUS_API_REQUIRE_CODE',
  );
  bool get configured => baseUrl.isNotEmpty;
  bool get needsAccessCode =>
      requireBetaCode || Uri.tryParse(baseUrl)?.scheme == 'https';
  Future<Map<String, dynamic>> draft(
    BrainStore store,
    String request,
    String learningContext, {
    String accessCode = '',
  }) async {
    if (store.commitments.isEmpty) {
      throw const FormatException(
        'Nhập lịch cố định trước khi tạo kế hoạch AI.',
      );
    }
    if (store.focusEnd?.isAfter(DateTime.now()) == true &&
        store.protection['blockInternet'] == true) {
      throw const FormatException(
        'Phiên tập trung đang chặn mạng. Hãy tạo kế hoạch sau khi kết thúc phiên.',
      );
    }
    if (!configured) {
      throw const FormatException(
        'Chưa kết nối dịch vụ lập lịch. Khởi chạy bản phát triển với OCTOPUS_API_URL.',
      );
    }
    if (needsAccessCode && accessCode.trim().isEmpty) {
      throw const FormatException(
        'Nhập mã thử AI của nhóm, không nhập key PoolAI.',
      );
    }
    final base = Uri.parse(baseUrl);
    if (base.scheme != 'https' &&
        !(base.scheme == 'http' &&
            ['127.0.0.1', 'localhost', '10.0.2.2'].contains(base.host))) {
      throw const FormatException('Địa chỉ API cần dùng HTTPS.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(base.resolve('/v1/plans'));
      req.headers.contentType = ContentType.json;
      if (needsAccessCode) {
        req.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${accessCode.trim()}',
        );
      }
      // Full name, birthday, activity photos and diary are deliberately absent.
      req.write(
        jsonEncode({
          'request': request,
          'now': DateTime.now().toUtc().toIso8601String(),
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
        }),
      );
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
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw FormatException(
          data['error'] is String
              ? data['error']
              : 'Dịch vụ chưa trả được kế hoạch.',
        );
      }
      if (data['schemaVersion'] != 1 ||
          data['sessions'] is! List ||
          data['questions'] is! List ||
          data['assumptions'] is! List) {
        throw const FormatException('Kết quả chưa đúng định dạng lịch.');
      }
      return data;
    } on SocketException {
      throw const FormatException(
        'Không kết nối được dịch vụ lập lịch. Kiểm tra kết nối và thử lại.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
