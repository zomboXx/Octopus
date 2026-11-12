import 'dart:async';
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'flow_design.dart';
import 'task_checkout.dart';

DateTime vietnamCalendarDate(DateTime now) {
  final vn = now.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(vn.year, vn.month, vn.day);
}

DateTime calendarMonday(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day - date.weekday + 1);

String _clock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _date(DateTime date) => '${date.day}/${date.month}';

String _interval(Duration delta) {
  final minutes = (delta.inMilliseconds / 60000).ceil().clamp(1, 99999999);
  if (minutes < 60) return '$minutes phút';
  if (minutes < 1440) {
    return '${minutes ~/ 60} giờ${minutes % 60 > 0 ? ' ${minutes % 60} phút' : ''}';
  }
  return '${minutes ~/ 1440} ngày${minutes % 1440 ~/ 60 > 0 ? ' ${minutes % 1440 ~/ 60} giờ' : ''}';
}

// One low-saturation palette for day columns in both compact and wide views.
({Color fill, Color header, Color ink}) _dayColors(String day, String today) =>
    day.compareTo(today) < 0
    ? (
        fill: const Color(0xfff1f3f6),
        header: const Color(0xffe6eaf0),
        ink: const Color(0xff59697e),
      )
    : day == today
    ? (
        fill: const Color(0xfffff9e9),
        header: const Color(0xffffedbd),
        ink: const Color(0xff80621c),
      )
    : (
        fill: const Color(0xfff1f6fd),
        header: const Color(0xffe5eefa),
        ink: const Color(0xff476891),
      );

class _CalendarColumns extends StatelessWidget {
  const _CalendarColumns({
    required this.first,
    required this.today,
    required this.leadingWidth,
    required this.child,
  });
  final DateTime first;
  final String today;
  final double leadingWidth;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: leadingWidth, color: const Color(0xfffafaff)),
            for (var d = 0; d < 7; d++)
              Expanded(
                child: ColoredBox(
                  color: _dayColors(
                    dayKey(first.add(Duration(days: d))),
                    today,
                  ).fill,
                ),
              ),
          ],
        ),
      ),
      child,
    ],
  );
}

class ScheduleStatus {
  const ScheduleStatus(this.key, this.label, this.relative, this.needsCheckout);
  final String key, label, relative;
  final bool needsCheckout;
  Color get color => switch (key) {
    'done' => const Color(0xff29825c),
    'overdue' => const Color(0xffb64357),
    'active' => const Color(0xff966000),
    'upcoming' => flowBlue,
    _ => flowMuted,
  };
}

ScheduleStatus scheduleStatus(Map<String, dynamic> entry, DateTime now) {
  if (entry['done'] == true) {
    return const ScheduleStatus('done', 'Đã hoàn thành', '', false);
  }
  final start = DateTime.tryParse(entry['start'] ?? '');
  final end = DateTime.tryParse(entry['end'] ?? '');
  if (start == null || end == null) {
    return const ScheduleStatus('unplaced', 'Chưa đặt giờ', '', false);
  }
  if (now.isBefore(start)) {
    return ScheduleStatus(
      'upcoming',
      'Sắp tới',
      'Còn ${_interval(start.difference(now))}',
      false,
    );
  }
  final fixed = entry['fixed'] == true;
  if (now.isBefore(end)) {
    return ScheduleStatus(
      'active',
      'Đang diễn ra',
      'Còn ${_interval(end.difference(now))} kết thúc',
      !fixed,
    );
  }
  if (fixed) return const ScheduleStatus('ended', 'Đã kết thúc', '', false);
  return ScheduleStatus(
    'overdue',
    'Quá hạn',
    'Đã kết thúc ${_interval(now.difference(end))} trước',
    true,
  );
}

List<Map<String, dynamic>> calendarEntries(
  BrainStore store,
  DateTime monday,
  int weeks,
) {
  final first = dayKey(monday),
      last = dayKey(monday.add(Duration(days: weeks * 7 - 1)));
  final entries = <Map<String, dynamic>>[];
  for (final p in store.plan) {
    final start = DateTime.tryParse(p['start'] ?? '');
    if (start == null) continue;
    final vn = start.toUtc().add(const Duration(hours: 7)), day = dayKey(vn);
    if (day.compareTo(first) >= 0 && day.compareTo(last) <= 0) {
      entries.add({
        ...p,
        'calendarDay': day,
        'calendarMinute': vn.hour * 60 + vn.minute,
      });
    }
  }
  for (var d = 0; d < weeks * 7; d++) {
    final date = monday.add(Duration(days: d));
    for (final c in store.commitments) {
      if (!(c['weekdays'] as List).contains(date.weekday)) continue;
      final start = date
          .add(Duration(minutes: c['startMinute'] as int))
          .subtract(const Duration(hours: 7));
      final end = date
          .add(Duration(minutes: c['endMinute'] as int))
          .subtract(const Duration(hours: 7));
      entries.add({
        'id': 'fixed:${c['id']}:${dayKey(date)}',
        'title': c['title'],
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'calendarDay': dayKey(date),
        'calendarMinute': c['startMinute'],
        'fixed': true,
        'commitment': c,
      });
    }
  }
  entries.sort(
    (a, b) => DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])),
  );
  return entries;
}

class SessionStatusTags extends StatelessWidget {
  const SessionStatusTags({super.key, required this.session, this.now});
  final Map<String, dynamic> session;
  final DateTime? now;
  @override
  Widget build(BuildContext context) {
    final status = scheduleStatus(session, now ?? DateTime.now());
    Widget tag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 3),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          tag(status.label, status.color),
          if (status.needsCheckout) tag('Chưa check-out', flowMuted),
          if (status.relative.isNotEmpty)
            Text(
              status.relative,
              style: const TextStyle(fontSize: 10, color: flowMuted),
            ),
        ],
      ),
    );
  }
}

class ScheduleOverview extends StatefulWidget {
  const ScheduleOverview({
    super.key,
    required this.store,
    required this.sessionBuilder,
    required this.editFixed,
  });
  final BrainStore store;
  final Widget Function(Map<String, dynamic>) sessionBuilder;
  final ValueChanged<Map<String, dynamic>> editFixed;
  @override
  State<ScheduleOverview> createState() => _ScheduleOverviewState();
}

class _ScheduleOverviewState extends State<ScheduleOverview> {
  bool calendar = false;
  int weeks = 1;
  late DateTime monday = calendarMonday(vietnamCalendarDate(DateTime.now()));
  Timer? clock;
  final ticks = ValueNotifier<int>(0);
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
        ticks.value++;
      }
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    ticks.dispose();
    super.dispose();
  }

  Future<void> details(Map<String, dynamic> entry) async {
    final s = DateTime.tryParse(
      entry['start'] ?? '',
    )?.toUtc().add(const Duration(hours: 7));
    final e = DateTime.tryParse(
      entry['end'] ?? '',
    )?.toUtc().add(const Duration(hours: 7));
    final fixed = entry['fixed'] == true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chi tiết hoạt động'),
        content: SizedBox(
          width: 390,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  s == null
                      ? '${entry['date'] ?? ''} · Chưa đặt giờ'
                      : '${_date(s)} · ${_clock(s)}–${_clock(e!)}',
                  style: const TextStyle(color: flowMuted, fontSize: 12),
                ),
                SessionStatusTags(session: entry),
                if (fixed)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text(
                      'Khung giờ lặp lại, không phải một đầu việc cần check-out. Giờ đã qua hiển thị “Đã kết thúc”.',
                      style: TextStyle(color: flowMuted, fontSize: 12),
                    ),
                  ),
                if (entry['objectives'] is List) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Mục tiêu buổi học',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final text in entry['objectives'])
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        '• $text',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
                if (entry['steps'] is List) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Các bước thực hiện',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final (i, text) in (entry['steps'] as List).indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        '${i + 1}. $text',
                        style: const TextStyle(color: flowMuted, fontSize: 13),
                      ),
                    ),
                ],
                if (entry['expectedOutput'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Đầu ra cần đạt: ${entry['expectedOutput']}',
                      style: const TextStyle(color: flowBlue, fontSize: 13),
                    ),
                  ),
                if ((entry['reflection'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Nhìn lại: ${entry['reflection']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng chi tiết'),
          ),
          if (fixed)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.editFixed(
                  Map<String, dynamic>.from(entry['commitment']),
                );
              },
              child: const Text('Chỉnh lịch cố định'),
            ),
          if (!fixed && entry['done'] != true)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final original = widget.store.workById(entry['id']);
                if (original != null) {
                  await checkOutTask(context, widget.store, original);
                }
                if (mounted) setState(() {});
              },
              child: const Text('Check-out công việc'),
            ),
        ],
      ),
    );
  }

  Widget event(Map<String, dynamic> p, bool expanded) {
    final status = scheduleStatus(p, DateTime.now());
    final vn = DateTime.parse(p['start']).toUtc().add(const Duration(hours: 7));
    final label = (p['subject'] ?? p['title']).toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        label: '${p['title']}, ${_date(vn)} ${_clock(vn)}, ${status.label}',
        button: true,
        child: Material(
          color: status.color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            key: ValueKey('calendar-event-${p['id']}'),
            onTap: () => details(p),
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 44),
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 7 : 2,
                vertical: expanded ? 8 : 5,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: status.color.withValues(alpha: .65),
                    width: 2,
                  ),
                ),
              ),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _clock(vn),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: expanded ? 10 : 7.5,
                        color: status.color,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: expanded ? 12 : 8,
                        height: 1.4,
                        color: status.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (p['subject'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          p['title'],
                          maxLines: expanded ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: expanded ? 10 : 7,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (p['fixed'] == true)
                      Text(
                        'Cố định',
                        style: TextStyle(
                          fontSize: expanded ? 9 : 6,
                          color: flowMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget tables({bool expanded = false}) {
    final entries = calendarEntries(widget.store, monday, weeks);
    final today = dayKey(vietnamCalendarDate(DateTime.now()));
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                for (final entry in [
                  (day: '0000', label: 'Ngày đã qua'),
                  (day: today, label: 'Hôm nay'),
                  (day: '9999', label: 'Ngày sắp tới'),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _dayColors(entry.day, today).header,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: _dayColors(
                              entry.day,
                              today,
                            ).ink.withValues(alpha: .35),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entry.label,
                        style: const TextStyle(fontSize: 9, color: flowMuted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        for (var w = 0; w < weeks; w++) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text(
                '${weeks > 1 ? 'Tuần ${w + 1} · ' : ''}${_date(monday.add(Duration(days: w * 7)))} – ${_date(monday.add(Duration(days: w * 7 + 6)))}',
                style: const TextStyle(fontSize: 11, color: flowMuted),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _CalendarColumns(
              first: monday.add(Duration(days: w * 7)),
              today: today,
              leadingWidth: expanded ? 55 : 29,
              child: Table(
                key: ValueKey('calendar-week-$w'),
                columnWidths: {0: FixedColumnWidth(expanded ? 55 : 29)},
                border: TableBorder.all(color: flowLine, width: .7),
                defaultVerticalAlignment: TableCellVerticalAlignment.top,
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Text(
                          'Buổi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: expanded ? 11 : 8,
                            color: flowMuted,
                          ),
                        ),
                      ),
                      for (var d = 0; d < 7; d++)
                        Builder(
                          builder: (_) {
                            final date = monday.add(Duration(days: w * 7 + d)),
                                selected = dayKey(date) == today;
                            final colors = _dayColors(dayKey(date), today);
                            return Container(
                              color: colors.header,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    [
                                      'T2',
                                      'T3',
                                      'T4',
                                      'T5',
                                      'T6',
                                      'T7',
                                      'CN',
                                    ][d],
                                    style: TextStyle(
                                      fontSize: expanded ? 12 : 9,
                                      color: colors.ink,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _date(date),
                                    style: TextStyle(
                                      fontSize: expanded ? 11 : 8,
                                      color: colors.ink,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  for (var r = 0; r < 3; r++)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 13,
                            left: 1,
                            right: 1,
                          ),
                          child: Column(
                            children: [
                              Text(
                                ['Sáng', 'Chiều', 'Tối'][r],
                                style: TextStyle(
                                  fontSize: expanded ? 12 : 8,
                                  color: flowMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ['00–12h', '12–18h', '18–24h'][r],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: expanded ? 9 : 6,
                                  color: flowMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var d = 0; d < 7; d++)
                          Builder(
                            builder: (_) {
                              final day = dayKey(
                                monday.add(Duration(days: w * 7 + d)),
                              );
                              final values = entries
                                  .where(
                                    (p) =>
                                        p['calendarDay'] == day &&
                                        ((p['calendarMinute'] as int) < 720
                                                ? 0
                                                : (p['calendarMinute'] as int) <
                                                      1080
                                                ? 1
                                                : 2) ==
                                            r,
                                  )
                                  .toList();
                              return ConstrainedBox(
                                key: ValueKey('cell-$day-$r'),
                                constraints: const BoxConstraints(
                                  minHeight: 88,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(expanded ? 6 : 2),
                                  child: values.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.only(top: 15),
                                          child: Text(
                                            '·',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xffd5dceb),
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: values
                                              .map((p) => event(p, expanded))
                                              .toList(),
                                        ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  void expand() => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: SizedBox(
        width: 1000,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bảng lịch của bạn',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng bảng rộng',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Vuốt ngang để xem hết 7 ngày.',
                style: TextStyle(fontSize: 11, color: flowMuted),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 840,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([widget.store, ticks]),
                        builder: (_, _) => tables(expanded: true),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final plan = [...widget.store.plan]
      ..sort(
        (a, b) =>
            DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])),
      );
    final last = monday.add(Duration(days: weeks * 7 - 1));
    final unplaced = widget.store.tasks
        .where(
          (p) =>
              (p['date'] as String).compareTo(dayKey(monday)) >= 0 &&
              (p['date'] as String).compareTo(dayKey(last)) <= 0,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch trình của bạn',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xffe9edfb),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (final option in [false, true])
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => calendar = option),
                    style: TextButton.styleFrom(
                      backgroundColor: calendar == option
                          ? Colors.white
                          : Colors.transparent,
                      foregroundColor: calendar == option
                          ? flowBlue
                          : flowMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      option
                          ? Icons.calendar_month_outlined
                          : Icons.checklist_rounded,
                      size: 16,
                    ),
                    label: Text(
                      option ? 'Bảng lịch' : 'Đầu việc',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!calendar) ...[
          if (plan.isEmpty)
            const FlowCard(
              child: Text(
                'Chưa có phiên học nào. Thêm lịch cố định, rồi mô tả mục tiêu của bạn.',
                style: TextStyle(color: flowMuted),
              ),
            ),
          for (final p in plan)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.sessionBuilder(p),
            ),
        ] else ...[
          Row(
            children: [
              IconButton(
                tooltip: 'Tuần trước',
                onPressed: () => setState(
                  () => monday = monday.subtract(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.chevron_left, color: flowBlue),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_date(monday)} – ${_date(last)} / ${last.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => monday = calendarMonday(
                          vietnamCalendarDate(DateTime.now()),
                        ),
                      ),
                      child: const Text(
                        'Về tuần này',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tuần sau',
                onPressed: () => setState(
                  () => monday = monday.add(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.chevron_right, color: flowBlue),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'Số tuần ',
                style: TextStyle(fontSize: 11, color: flowMuted),
              ),
              DropdownButton<int>(
                value: weeks,
                underline: const SizedBox(),
                items: [1, 2, 4]
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: Text(
                          '$n tuần',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (n) => setState(() => weeks = n!),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: expand,
                icon: const Icon(Icons.open_in_full, size: 13),
                label: const Text('Xem rộng', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const Text(
            'Giờ Việt Nam · Chạm vào một buổi để xem chi tiết.',
            style: TextStyle(fontSize: 10, color: flowMuted),
          ),
          tables(),
          Wrap(
            spacing: 9,
            runSpacing: 7,
            children: [
              for (final status in [
                const ScheduleStatus('upcoming', 'Sắp tới', '', false),
                const ScheduleStatus('active', 'Đang diễn ra', '', false),
                const ScheduleStatus('overdue', 'Quá hạn', '', true),
                const ScheduleStatus('done', 'Hoàn thành', '', false),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: status.color),
                    const SizedBox(width: 4),
                    Text(
                      status.label,
                      style: const TextStyle(fontSize: 9, color: flowMuted),
                    ),
                  ],
                ),
            ],
          ),
          if (unplaced.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FlowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Việc chưa đặt giờ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Những việc này chưa có giờ bắt đầu nên chưa xếp vào buổi.',
                      style: TextStyle(fontSize: 10, color: flowMuted),
                    ),
                    for (final p in unplaced)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          p['title'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          p['date'],
                          style: const TextStyle(fontSize: 10),
                        ),
                        onTap: () => details(p),
                        trailing: const Icon(Icons.chevron_right, size: 17),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Lịch cố định lặp theo cấu hình hiện tại. Có thể xem nhiều tuần; AI hiện lập lịch trong 7 ngày tới.',
            style: TextStyle(fontSize: 10, color: flowMuted),
          ),
        ],
      ],
    );
  }
}
