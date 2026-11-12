import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'device_bridge.dart';

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? profileError(String name, DateTime? birthday, DateTime now) {
  if (name.trim().length < 2 || name.trim().length > 100) {
    return 'Nhập họ tên từ 2 đến 100 ký tự.';
  }
  if (birthday == null) return 'Chọn ngày sinh của bạn.';
  if (birthday.isAfter(DateTime(now.year, now.month, now.day)) ||
      birthday.year < 1900) {
    return 'Ngày sinh không hợp lệ.';
  }
  return null;
}

String? activityError(DateTime start, DateTime end, DateTime now) {
  if (!end.isAfter(start)) return 'Kết thúc cần sau thời gian bắt đầu.';
  if (end.isAfter(now)) return 'Hoạt động đã làm không thể ở tương lai.';
  if (start.isBefore(now.subtract(const Duration(hours: 24)))) {
    return 'Toàn bộ hoạt động cần nằm trong 24 giờ vừa qua.';
  }
  return null;
}

String? focusError(int minutes) => minutes < 1 || minutes > 480
    ? 'Phiên tập trung cần từ 1 đến 480 phút (8 giờ).'
    : null;

class BrainStore extends ChangeNotifier {
  BrainStore({DeviceBridge? device}) : device = device ?? DeviceBridge();
  final DeviceBridge device;
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> plan = [];
  Map<String, dynamic> profile = {};
  bool onboardingComplete = false;
  bool wellbeingReminders = true;
  List<Map<String, dynamic>> commitments = [];
  Map<String, dynamic> studyPreferences = {
    'startMinute': 18 * 60,
    'endMinute': 22 * 60,
    'sessionMinutes': 45,
    'dailyMinutes': 120,
  };
  Set<String> restricted = {};
  Map<String, dynamic> protection = {
    'enabled': false,
    'watchSchedule': true,
    'watchFixed': true,
    'blockInternet': true,
    'sound': true,
  };
  Set<String> dismissedSuggestions = {};
  List<Map<String, dynamic>> circles = [];
  List<Map<String, dynamic>> checkins = [];
  String? focusTaskId;
  DateTime? focusStart, focusEnd;
  int focusMinutes = 0;
  String? storageError;
  Future<void> _writes = Future.value();

  Future<void> load() async {
    try {
      final raw = await device.readState();
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) return;
      List<Map<String, dynamic>> list(String key) => (json[key] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      tasks = list('tasks');
      activities = list('activities');
      plan = list('plan');
      profile = Map<String, dynamic>.from(json['profile'] ?? {});
      onboardingComplete = json['onboardingComplete'] == true;
      wellbeingReminders = json['wellbeingReminders'] != false;
      commitments = list('commitments');
      circles = list('circles');
      checkins = list('checkins');
      focusTaskId = json['focusTaskId'];
      studyPreferences.addAll(
        Map<String, dynamic>.from(json['studyPreferences'] ?? {}),
      );
      for (final task in tasks) {
        task['date'] ??= dayKey(
          DateTime.tryParse(task['createdAt'] ?? '') ?? DateTime.now(),
        );
      }
      restricted = Set<String>.from(json['restricted'] ?? []);
      protection.addAll(Map<String, dynamic>.from(json['protection'] ?? {}));
      dismissedSuggestions = Set<String>.from(
        json['dismissedSuggestions'] ?? [],
      );
      focusStart = DateTime.tryParse(json['focusStart'] ?? '');
      focusEnd = DateTime.tryParse(json['focusEnd'] ?? '');
      focusMinutes = json['focusMinutes'] ?? 0;
      if (focusStart == null || focusEnd == null) {
        focusStart = null;
        focusEnd = null;
      }
    } catch (_) {
      storageError = 'Không đọc được dữ liệu trên máy. Chưa ghi đè dữ liệu cũ.';
    }
  }

  Future<void> save() async {
    final payload = jsonEncode({
      'version': 1,
      'wellbeingReminders': wellbeingReminders,
      'tasks': tasks,
      'activities': activities,
      'plan': plan,
      'profile': profile,
      'onboardingComplete': onboardingComplete,
      'commitments': commitments,
      'circles': circles,
      'checkins': checkins,
      'focusTaskId': focusTaskId,
      'studyPreferences': studyPreferences,
      'restricted': restricted.toList(),
      'protection': protection,
      'dismissedSuggestions': dismissedSuggestions.toList(),
      'focusStart': focusStart?.toIso8601String(),
      'focusEnd': focusEnd?.toIso8601String(),
      'focusMinutes': focusMinutes,
    });
    _writes = _writes.then((_) async {
      try {
        await device.writeState(payload);
        storageError = null;
      } catch (_) {
        storageError = 'Chưa lưu được thay đổi trên máy. Hãy thử lại.';
      }
      notifyListeners();
    });
    notifyListeners();
    await _writes;
  }

  Future<void> startFocus(int minutes, {DateTime? start}) async {
    final invalid = focusError(minutes);
    if (invalid != null) throw ArgumentError(invalid);
    if (focusEnd != null) return;
    focusStart = start ?? DateTime.now();
    focusEnd = focusStart!.add(Duration(minutes: minutes));
    final pending = workOn(focusStart!).where((t) => t['done'] != true);
    focusTaskId = pending.isEmpty ? null : pending.first['id'];
    await save();
  }

  List<Map<String, dynamic>> tasksOn(DateTime date) => tasks
      .where((t) => (t['date'] ?? dayKey(DateTime.now())) == dayKey(date))
      .toList();

  List<Map<String, dynamic>> workOn(DateTime date) {
    final entries = [
      ...tasksOn(date),
      ...plan.where((p) {
        final start = DateTime.tryParse(p['start'] ?? '')?.toLocal();
        return p['kind'] != 'break' &&
            start != null &&
            dayKey(start) == dayKey(date);
      }),
    ];
    entries.sort(
      (a, b) => (a['start'] ?? '${a['date']}T23:59').toString().compareTo(
        (b['start'] ?? '${b['date']}T23:59').toString(),
      ),
    );
    return entries;
  }

  Map<String, dynamic>? workById(String? id) {
    if (id == null) return null;
    for (final item in [...tasks, ...plan]) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  Future<void> completeWork(
    Map<String, dynamic> item, {
    String reflection = '',
    String audience = 'private',
    List<String> recipients = const [],
  }) async {
    item['done'] = true;
    item['completedAt'] ??= DateTime.now().toIso8601String();
    item['reflection'] = reflection.trim();
    item['audience'] = audience;
    item['recipients'] = audience == 'selected' ? recipients : <String>[];
    if (focusTaskId == item['id'] && focusEnd != null) {
      await device.cancelFocus(
        'Đã hoàn thành: ${item['title']}',
        completed: true,
      );
      await finishFocus();
    }
    await save();
  }

  DateTime quickTaskDate({DateTime? now}) {
    final today = now ?? DateTime.now();
    final entries = workOn(today);
    return entries.isNotEmpty && entries.every((t) => t['done'] == true)
        ? DateTime(today.year, today.month, today.day + 1)
        : today;
  }

  Future<void> addTask(String title, int minutes, DateTime date) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var sequence = 0;
    var id = '$stamp';
    while (workById(id) != null) {
      id = '$stamp-${++sequence}';
    }
    tasks.add({
      'id': id,
      'title': title,
      'minutes': minutes,
      'done': false,
      'date': dayKey(date),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await save();
  }

  Future<void> finishFocus({DateTime? now}) async {
    if (focusStart == null || focusEnd == null) return;
    final time = now ?? DateTime.now();
    final end = time.isBefore(focusEnd!) ? time : focusEnd!;
    focusMinutes += end.difference(focusStart!).inMinutes.clamp(0, 480);
    focusStart = null;
    focusEnd = null;
    focusTaskId = null;
    await save();
  }
}
