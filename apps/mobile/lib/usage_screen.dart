import 'activity_history.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'main.dart' show Panel, PageIntro, blue, muted;
import 'protection_screen.dart';
import 'app_icon.dart';
import 'usage_day_screen.dart';
import 'usage_reminder_card.dart';

String usageDuration(num ms) {
  final minutes = (ms / 60000).floor();
  if (minutes == 0 && ms > 0) return '<1 phút';
  return minutes < 60
      ? '$minutes phút'
      : '${minutes ~/ 60} giờ ${minutes % 60} phút';
}

List<Map<String, dynamic>> rows(dynamic value) =>
    (value as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

/// Transparent local heuristic, not a diagnosis or an inference about intent.
Map<String, dynamic>? restrictionSuggestion(
  List<Map<String, dynamic>> apps,
  List<Map<String, dynamic>> days,
  BrainStore store,
) {
  final observed = days
      .where((d) => (d['milliseconds'] as num? ?? 0) > 0)
      .length;
  if (observed < 3) return null;
  final total = apps.fold<num>(0, (n, a) => n + (a['milliseconds'] as num));
  for (final app in apps) {
    final pkg = app['package'] as String;
    if (store.restricted.contains(pkg) ||
        store.dismissedSuggestions.contains(pkg) ||
        pkg == 'vn.octopus.mobile' ||
        pkg.contains('launcher') ||
        pkg.contains('dialer') ||
        pkg == 'com.miui.home' ||
        pkg == 'com.android.settings') {
      continue;
    }
    final time = app['milliseconds'] as num;
    if (time / observed >= 60 * 60000 && total > 0 && time / total >= .2) {
      return {...app, 'observedDays': observed};
    }
  }
  return null;
}

class UsagePanel extends StatefulWidget {
  const UsagePanel({super.key, required this.store});
  final BrainStore store;
  @override
  State<UsagePanel> createState() => _UsagePanelState();
}

DateTime usageWeekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

class _UsagePanelState extends State<UsagePanel> with WidgetsBindingObserver {
  bool loading = true, granted = false;
  String? error;
  DateTime week = usageWeekStart(DateTime.now());
  int requestId = 0;
  List<Map<String, dynamic>> apps = [], days = [], events = [];
  final hidden = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    requestId++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final run = ++requestId, selected = week;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.store.device.usageWeek(dayKey(selected));
      final history = await widget.store.device.guardEvents();
      if (!mounted || run != requestId) return;
      final end = DateTime(
        selected.year,
        selected.month,
        selected.day + 7,
      ).millisecondsSinceEpoch;
      setState(() {
        granted = data['granted'] == true;
        apps = granted ? rows(data['apps']) : [];
        days = granted ? rows(data['days']) : [];
        events = history.where((event) {
          final at = event['at'] as num? ?? 0;
          return at >= selected.millisecondsSinceEpoch && at < end;
        }).toList();
      });
    } catch (_) {
      if (mounted && run == requestId) {
        setState(
          () => error = 'Chưa tải được tuần đã chọn. Nhấn làm mới để thử lại.',
        );
      }
    } finally {
      if (mounted && run == requestId) setState(() => loading = false);
    }
  }

  void changeWeek(int offset) {
    setState(() {
      week = DateTime(week.year, week.month, week.day + offset * 7);
      apps = [];
      days = [];
      events = [];
    });
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final total = apps.fold<num>(
      0,
      (n, app) => n + (app['milliseconds'] as num),
    );
    final suggestion = restrictionSuggestion(
      apps.where((app) => !hidden.contains(app['package'])).toList(),
      days,
      widget.store,
    );
    final current = usageWeekStart(DateTime.now());
    final last = DateTime(week.year, week.month, week.day + 6);
    final interruptions = events
        .where((event) => event['type'] == 'interruption')
        .length;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const PageIntro(
            'Thời gian của bạn',
            'Chọn một tuần. Chạm vào từng ngày để xem ứng dụng và hoạt động.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                onPressed: loading ? null : () => changeWeek(-1),
                tooltip: 'Tuần trước',
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${week.day}/${week.month} – ${last.day}/${last.month}/${last.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (week != current)
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() => week = current);
                                refresh();
                              },
                        child: const Text('Về tuần này'),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loading || !week.isBefore(current)
                    ? null
                    : () => changeWeek(1),
                tooltip: 'Tuần sau',
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                onPressed: loading ? null : refresh,
                tooltip: 'Làm mới thống kê',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          LocalJournalPanel(store: widget.store, week: week),
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          if (!granted && !loading)
            Panel(
              child: Column(
                children: [
                  const Icon(Icons.insights_outlined, size: 40, color: blue),
                  const SizedBox(height: 12),
                  const Text(
                    'Cho phép xem thời gian sử dụng',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Octopus đọc tên ứng dụng và thời gian dùng từ Android. Lịch sử được xử lý trên điện thoại.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await widget.store.device.openUsageAccess();
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => error =
                                'Mở Cài đặt → Quyền truy cập dữ liệu sử dụng → Octopus.',
                          );
                        }
                      }
                    },
                    child: const Text('Mở quyền sử dụng'),
                  ),
                  TextButton(
                    onPressed: refresh,
                    child: const Text('Kiểm tra lại quyền'),
                  ),
                ],
              ),
            ),
          if (granted) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thời gian ứng dụng trong tuần',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usageDuration(total),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (days.isNotEmpty)
                    UsageBars(
                      days: days,
                      onDaySelected: (day) {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UsageDayScreen(
                              store: widget.store,
                              date: day['date'] as String,
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chạm một cột để xem ngày đó. Lịch sử phụ thuộc dữ liệu Android còn lưu.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  if (days.any((day) => day['aggregate'] == true))
                    const Text(
                      'Một số ngày dùng số liệu tổng hợp của Android vì lịch sử từng lần mở app đã hết hạn.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            UsageReminderCard(store: widget.store),
            const SizedBox(height: 16),
            if (suggestion != null)
              RestrictionSuggestionCard(
                store: widget.store,
                app: suggestion,
                onChanged: () {
                  if (mounted) setState(() {});
                },
                onSkip: () =>
                    setState(() => hidden.add(suggestion['package'] as String)),
              ),
            if (total > 0) ...[
              const SizedBox(height: 16),
              UsageDistribution(apps: apps, total: total),
              const SizedBox(height: 20),
              const Text(
                'Ứng dụng trong tuần',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              for (final app in apps)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppIdentityIcon(
                    device: widget.store.device,
                    package: app['package'] as String,
                    name: app['name'] as String,
                  ),
                  title: Text(
                    app['name'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${((app['milliseconds'] as num) / math.max(total, 1) * 100).toStringAsFixed(0)}% thời gian${widget.store.restricted.contains(app['package']) ? " · Đã hạn chế" : ""}',
                  ),
                  trailing: Text(
                    usageDuration(app['milliseconds'] as num),
                    style: const TextStyle(color: blue, fontSize: 12),
                  ),
                ),
            ] else if (!loading && error == null)
              const Panel(
                child: Text(
                  'Android chưa có dữ liệu khả dụng cho tuần này. Bạn có thể chọn tuần khác.',
                ),
              ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhịp tập trung trong tuần',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$interruptions lần nhắc quay lại · ${events.where((event) => event['type'] == 'early_exit').length} lần kết thúc sớm',
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProtectionScreen(store: widget.store),
                      ),
                    ),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Quản lý bảo vệ và danh sách hạn chế'),
                  ),
                  if (widget.store.dismissedSuggestions.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        widget.store.dismissedSuggestions.clear();
                        await widget.store.save();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Cho phép gợi ý lại các app đã ẩn'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RestrictionSuggestionCard extends StatelessWidget {
  const RestrictionSuggestionCard({
    super.key,
    required this.store,
    required this.app,
    required this.onChanged,
    required this.onSkip,
  });
  final BrainStore store;
  final Map<String, dynamic> app;
  final VoidCallback onChanged, onSkip;
  @override
  Widget build(BuildContext context) => Panel(
    color: const Color(0xffedf3ff),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bạn muốn dành ít thời gian hơn ở đây?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            AppIdentityIcon(
              device: store.device,
              package: app['package'] as String,
              name: app['name'] as String,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    usageDuration(app['milliseconds'] as num),
                    style: const TextStyle(
                      fontSize: 20,
                      color: blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Trung bình ${usageDuration((app['milliseconds'] as num) / (app['observedDays'] as int))}/ngày có dữ liệu.',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: () async {
                store.restricted.add(app['package'] as String);
                await store.save();
                if (context.mounted && store.storageError != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(store.storageError!)));
                }
                onChanged();
              },
              child: const Text('Thêm hạn chế'),
            ),
            TextButton(onPressed: onSkip, child: const Text('Để sau')),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Vì sao có gợi ý này?',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            const Text(
              'Ứng dụng chiếm ít nhất 20% thời gian và trung bình từ 1 giờ/ngày, với ít nhất 3 ngày có dữ liệu. Bạn quyết định app nào phù hợp để hạn chế.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            TextButton(
              onPressed: () async {
                store.dismissedSuggestions.add(app['package'] as String);
                await store.save();
                onChanged();
              },
              child: const Text('Ẩn gợi ý cho ứng dụng này'),
            ),
          ],
        ),
      ],
    ),
  );
}

class UsageBars extends StatelessWidget {
  const UsageBars({super.key, required this.days, this.onDaySelected});
  final List<Map<String, dynamic>> days;
  final ValueChanged<Map<String, dynamic>>? onDaySelected;
  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<num>(
      1,
      (n, d) => math.max(n, d['milliseconds'] as num),
    );
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Semantics(
                label:
                    '${d['date']}: ${usageDuration(d['milliseconds'] as num)}',
                button: onDaySelected != null && d['future'] != true,
                child: InkWell(
                  onTap: onDaySelected == null || d['future'] == true
                      ? null
                      : () => onDaySelected!(d),
                  borderRadius: BorderRadius.circular(8),
                  child: Tooltip(
                    message:
                        '${d['date']} · ${usageDuration(d['milliseconds'] as num)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          d['future'] == true || d['available'] == false
                              ? '—'
                              : '${((d['milliseconds'] as num) / 60000).floor()}p',
                          style: const TextStyle(fontSize: 9, color: muted),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: math
                              .max(
                                2,
                                (d['milliseconds'] as num) / maxValue * 120,
                              )
                              .toDouble(),
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            color: d['date'] == dayKey(DateTime.now())
                                ? blue
                                : const Color(0xffb9cff9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (d['date'] as String).substring(8),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const chartColors = [
  Color(0xff004ac6),
  Color(0xff6f7be8),
  Color(0xff41a89a),
  Color(0xffedb45f),
  Color(0xffc67ca0),
  Color(0xffcbd4e1),
];

class UsageDistribution extends StatelessWidget {
  const UsageDistribution({super.key, required this.apps, required this.total});
  final List<Map<String, dynamic>> apps;
  final num total;
  @override
  Widget build(BuildContext context) {
    final portions = apps
        .take(5)
        .map((a) => {'name': a['name'], 'value': a['milliseconds']})
        .toList();
    final rest =
        total - portions.fold<num>(0, (n, a) => n + (a['value'] as num));
    if (rest > 0) portions.add({'name': 'Ứng dụng khác', 'value': rest});
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thời gian đang dành cho đâu?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 155,
              height: 155,
              child: CustomPaint(
                painter: _Donut(
                  portions
                      .map((p) => (p['value'] as num).toDouble() / total)
                      .toList(),
                ),
                child: const Center(
                  child: Text(
                    'TRONG TUẦN',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < portions.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: chartColors[i]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      portions[i]['name'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${((portions[i]['value'] as num) / total * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Donut extends CustomPainter {
  _Donut(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var angle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] * math.pi * 2;
      canvas.drawArc(
        rect.deflate(14),
        angle,
        sweep,
        false,
        Paint()
          ..color = chartColors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut oldDelegate) =>
      oldDelegate.values != values;
}
