import 'brain_store.dart';

bool overlaps(
  DateTime start,
  DateTime end,
  DateTime otherStart,
  DateTime otherEnd,
) => start.isBefore(otherEnd) && end.isAfter(otherStart);

String? commitmentError(
  Map<String, dynamic> entry,
  List<Map<String, dynamic>> others,
) {
  final days = (entry['weekdays'] as List? ?? []).cast<int>();
  final start = entry['startMinute'] as int? ?? -1,
      end = entry['endMinute'] as int? ?? -1;
  if ((entry['title'] as String? ?? '').trim().isEmpty) {
    return 'Nhập tên lịch cố định.';
  }
  if (days.isEmpty || days.any((d) => d < 1 || d > 7)) {
    return 'Chọn ít nhất một ngày trong tuần.';
  }
  if (start < 0 || end > 1440 || end <= start) {
    return 'Giờ kết thúc cần sau giờ bắt đầu. Lịch qua đêm cần tách thành hai khung.';
  }
  if (others.any(
    (e) =>
        e['id'] != entry['id'] &&
        (e['weekdays'] as List).any(days.contains) &&
        start < e['endMinute'] &&
        end > e['startMinute'],
  )) {
    return 'Khung giờ này trùng với một lịch cố định khác.';
  }
  return null;
}

/// Recheck against current state when accepting a draft, including edits made
/// while the network request was in flight. Remote data is never auto-applied.
String? planError(
  List<Map<String, dynamic>> sessions,
  BrainStore store,
  DateTime now,
) {
  final all = <(DateTime, DateTime)>[];
  final daily = <String, int>{};
  for (final old in store.plan) {
    final s = DateTime.parse(old['start']), e = DateTime.parse(old['end']);
    all.add((s, e));
    if (old['kind'] != 'break') {
      daily.update(
        dayKey(s.toUtc().add(const Duration(hours: 7))),
        (n) => n + e.difference(s).inMinutes,
        ifAbsent: () => e.difference(s).inMinutes,
      );
    }
  }
  for (final p in sessions) {
    final s = DateTime.tryParse(p['start'] ?? ''),
        e = DateTime.tryParse(p['end'] ?? '');
    if (s == null ||
        e == null ||
        !e.isAfter(s) ||
        s.isBefore(now) ||
        e.difference(s).inMinutes > 480) {
      return 'Lịch có thời gian không hợp lệ hoặc đã qua.';
    }
    if (all.any((v) => overlaps(s, e, v.$1, v.$2))) {
      return 'Lịch bị trùng giờ. Hãy tạo lại gợi ý theo lịch mới nhất.';
    }
    // This preview currently plans only in Vietnam's timezone, UTC+07.
    final local = s.toUtc().add(const Duration(hours: 7)),
        finish = e.toUtc().add(const Duration(hours: 7));
    final startMinute = local.hour * 60 + local.minute,
        endMinute = finish.hour * 60 + finish.minute;
    if (dayKey(local) != dayKey(finish) ||
        startMinute < store.studyPreferences['startMinute'] ||
        endMinute > store.studyPreferences['endMinute']) {
      return 'Phiên học nằm ngoài khung giờ bạn đã chọn.';
    }
    for (final c in store.commitments) {
      if ((c['weekdays'] as List).contains(local.weekday) &&
          startMinute < c['endMinute'] &&
          endMinute > c['startMinute']) {
        return 'Phiên học trùng lịch cố định. Hãy tạo lại gợi ý.';
      }
    }
    final exam = DateTime.tryParse(p['examDate'] ?? '');
    if (exam == null || dayKey(local).compareTo(dayKey(exam)) >= 0) {
      return 'Buổi học cần diễn ra trước hạn hoàn thành. Hãy kiểm tra hạn rồi tạo lại kế hoạch.';
    }
    final key = dayKey(local), length = e.difference(s).inMinutes;
    daily.update(key, (n) => n + length, ifAbsent: () => length);
    if (daily[key]! > store.studyPreferences['dailyMinutes']) {
      return 'Vượt số phút học tối đa mỗi ngày.';
    }
    all.add((s, e));
  }
  return null;
}
