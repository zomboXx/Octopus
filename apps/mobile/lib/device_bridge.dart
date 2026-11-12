import 'dart:convert';
import 'package:flutter/services.dart';

/// Android integration is separate from UI. No WebView is used.
class DeviceBridge {
  static const channel = MethodChannel('vn.octopus/device');
  Future<Map<String, dynamic>> guardStatus() async =>
      await channel.invokeMapMethod<String, dynamic>('guardStatus') ?? {};
  Future<List<Map<String, dynamic>>> guardEvents() async =>
      (jsonDecode(await channel.invokeMethod<String>('guardEvents') ?? '[]')
              as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<List<Map<String, dynamic>>> installedApps() async =>
      (await channel.invokeListMethod<dynamic>('installedApps') ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> openAccessibility() =>
      channel.invokeMethod<void>('openAccessibility');
  Future<bool> prepareVpn() async =>
      await channel.invokeMethod<bool>('prepareVpn') ?? false;
  Future<Map<String, dynamic>> wellbeingStatus() async =>
      await channel.invokeMapMethod<String, dynamic>('wellbeingStatus') ?? {};
  Future<Map<String, dynamic>> requestWellbeingPermission() async =>
      await channel.invokeMapMethod<String, dynamic>(
        'requestWellbeingPermission',
      ) ??
      {};
  Future<void> openWellbeingSettings() =>
      channel.invokeMethod<void>('openWellbeingSettings');
  Future<void> requestNotifications() =>
      channel.invokeMethod<void>('requestNotifications');
  Future<void> resumeProtection() =>
      channel.invokeMethod<void>('resumeProtection');
  Future<void> cancelFocus(String reason, {bool completed = false}) =>
      channel.invokeMethod<void>('cancelFocus', {
        'reason': reason,
        'completed': completed,
      });
  Future<String?> readState() => channel.invokeMethod<String>('readState');
  Future<void> writeState(String json) =>
      channel.invokeMethod<void>('writeState', json);
  Future<void> openUsageAccess() =>
      channel.invokeMethod<void>('openUsageAccess');
  Future<Map<String, dynamic>> usage() async {
    final result = await channel.invokeMapMethod<String, dynamic>('usage');
    return result ?? {'granted': false, 'apps': []};
  }

  Future<String?> pickImage() => channel.invokeMethod<String>('pickImage');
  Future<String?> recognizeSpeech() =>
      channel.invokeMethod<String>('recognizeSpeech');
  Future<Map<String, dynamic>> widgetStatus() async =>
      await channel.invokeMapMethod<String, dynamic>('widgetStatus') ?? {};
  Future<bool> pinWidget(String kind) async =>
      await channel.invokeMethod<bool>('pinWidget', kind) ?? false;
  Future<String?> takeWidgetAction() =>
      channel.invokeMethod<String>('takeWidgetAction');
}
