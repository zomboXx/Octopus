import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'main.dart' show Panel, PageIntro, blue, muted;
import 'protection_screen.dart';

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

class _UsagePanelState extends State<UsagePanel> with WidgetsBindingObserver {
  bool loading = true, granted = false;
  String? error;
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    try {
      final data = await widget.store.device.usage();
      final history = await widget.store.device.guardEvents();
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;
      if (mounted) {
        setState(() {
          granted = data['granted'] == true;
          apps = rows(data['apps']);
          days = rows(data['days']);
          events = history
              .where((e) => (e['at'] as num? ?? 0) >= cutoff)
              .toList();
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Chưa đọc được thống kê Android. Kéo xuống hoặc nhấn làm mới để thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = apps.fold<num>(0, (n, a) => n + (a['milliseconds'] as num));
    final suggestion = restrictionSuggestion(
      apps.where((a) => !hidden.contains(a['package'])).toList(),
      days,
      widget.store,
    );
    final interruptions = events
        .where((e) => e['type'] == 'interruption')
        .length;
    final exits = events.where((e) => e['type'] == 'early_exit').length;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const PageIntro(
            'Thời gian kể câu chuyện.',
            '7 ngày theo lịch trên thiết bị · cập nhật khi bạn mở hoặc làm mới.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới thống kê',
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (!granted && !loading)
            Panel(
              child: Column(
                children: [
                  const Icon(Icons.insights_outlined, size: 44, color: blue),
                  const SizedBox(height: 12),
                  const Text(
                    'Cho phép đọc thời gian dùng ứng dụng',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Android cung cấp thời điểm ứng dụng ở phía trước. Octopus không đọc nội dung và không gửi lịch sử này lên AI.',
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
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TỔNG THỜI GIAN ỨNG DỤNG',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    usageDuration(total),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (days.isNotEmpty) UsageBars(days: days),
                  const SizedBox(height: 12),
                  const Text(
                    'Tính từ các sự kiện mở/đóng app, chia theo ngày địa phương. Ngày trống có thể do Android thiếu lịch sử; không đồng nghĩa dùng 0 phút. Không bao gồm toàn bộ thời gian màn hình sáng.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (total > 0)
              UsageDistribution(apps: apps, total: total)
            else
              const Panel(
                child: Text(
                  'Chưa có lịch sử khả dụng. Hãy dùng vài ứng dụng rồi quay lại; Octopus không tạo số liệu minh họa.',
                ),
              ),
            const SizedBox(height: 16),
            if (days.where((d) => (d['milliseconds'] as num? ?? 0) > 0).length <
                3)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Cần ít nhất 3 ngày có dữ liệu để đề xuất app nên hạn chế. Trong lúc đó, bạn có thể tự chọn danh sách ở mục Bảo vệ tập trung.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            if (suggestion != null)
              Panel(
                color: const Color(0xffeaf1ff),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Một gợi ý cho bạn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${suggestion['name']}: ${usageDuration(suggestion['milliseconds'] as num)} trong ${suggestion['observedDays']} ngày có dữ liệu. Bình quân ít nhất 1 giờ/ngày và chiếm ít nhất 20% thời gian ứng dụng.',
                    ),
                    const Text(
                      'Bạn có muốn thêm app này vào danh sách hạn chế? Đây có thể là công cụ làm việc của bạn, nên Octopus không tự quyết định.',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () async {
                            widget.store.restricted.add(
                              suggestion['package'] as String,
                            );
                            await widget.store.save();
                            if (mounted) setState(() {});
                          },
                          child: const Text('Thêm hạn chế'),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => hidden.add(suggestion['package'] as String),
                          ),
                          child: const Text('Để sau'),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: false,
                      title: const Text(
                        'Không hỏi lại về app này',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (v) async {
                        if (v != true) return;
                        widget.store.dismissedSuggestions.add(
                          suggestion['package'] as String,
                        );
                        await widget.store.save();
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Theo ứng dụng · cả 7 ngày',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            for (final app in apps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  app['name'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${((app['milliseconds'] as num) / math.max(total, 1) * 100).toStringAsFixed(1)}%${widget.store.restricted.contains(app['package']) ? " · Đang hạn chế theo lịch" : ""}',
                ),
                trailing: Text(
                  usageDuration(app['milliseconds'] as num),
                  style: const TextStyle(color: blue),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhìn lại 7 ngày',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                Text('$interruptions lần cảnh báo · $exits lần kết thúc sớm'),
                Text(
                  exits >= 3
                      ? 'Bạn đã kết thúc sớm nhiều lần. Có thể thử phiên 20–25 phút hoặc điều chỉnh giờ học cho phù hợp hơn.'
                      : 'Cảnh báo lặp lại được tính thành từng lần, không phải số phiên thất bại. Chưa có dữ liệu không có nghĩa là không mất tập trung.',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                if (interruptions > 0) ...[
                  const SizedBox(height: 8),
                  for (final e
                      in events
                          .where((e) => e['type'] == 'interruption')
                          .toList()
                          .reversed
                          .take(4))
                    Text(
                      '${DateTime.fromMillisecondsSinceEpoch((e['at'] as num).toInt()).toLocal().toString().substring(5, 16)} · ${e['title']}\n${e['package']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
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
      ),
    );
  }
}

class UsageBars extends StatelessWidget {
  const UsageBars({super.key, required this.days});
  final List<Map<String, dynamic>> days;
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
                child: Tooltip(
                  message:
                      '${d['date']} · ${usageDuration(d['milliseconds'] as num)}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${((d['milliseconds'] as num) / 60000).floor()}p',
                        style: const TextStyle(fontSize: 9, color: muted),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: math
                            .max(2, (d['milliseconds'] as num) / maxValue * 120)
                            .toDouble(),
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: d == days.last
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
                    '7 NGÀY',
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
