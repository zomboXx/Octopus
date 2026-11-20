import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'device_bridge.dart';

class TrialApi {
  static const baseUrl = String.fromEnvironment('OCTOPUS_TRIAL_API_URL');
  bool get configured => baseUrl.isNotEmpty;

  Future<Map<String, dynamic>> status() => _request('/api/trial/status');

  Future<Map<String, dynamic>> redeem({String? code}) => _request(
    '/api/trial/redeem',
    code == null ? {'firstUse': true} : {'code': code},
  );

  Future<Map<String, dynamic>> _request(
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.host.isEmpty ||
        !(base.scheme == 'https' ||
            (kDebugMode &&
                base.scheme == 'http' &&
                ['127.0.0.1', 'localhost'].contains(base.host)))) {
      throw const FormatException('Chưa kết nối dịch vụ dùng thử.');
    }
    final token = await DeviceBridge.channel.invokeMethod<String>(
      'trialGuestToken',
    );
    if (token == null) {
      throw const FormatException('Chưa tạo được hồ sơ khách.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.openUrl(
        payload == null ? 'GET' : 'POST',
        base.resolve(path),
      );
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (payload != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(payload));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw FormatException(
          data['error'] as String? ?? 'Yêu cầu chưa thành công.',
        );
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }
}
