import 'activity_history.dart';
import 'package:flutter/material.dart';
import 'app_icon.dart';
import 'brain_store.dart';
import 'flow_design.dart';
import 'usage_screen.dart' show rows, usageDuration;

class UsageDayScreen extends StatefulWidget {
  const UsageDayScreen({super.key, required this.store, required this.date});
  final BrainStore store;
  final String date;
  @override
  State<UsageDayScreen> createState() => _UsageDayScreenState();
}

class _UsageDayScreenState extends State<UsageDayScreen> {
  late Future<Map<String, dynamic>> details;
  @override
  void initState() {
    super.initState();
    details = widget.store.device.usageDay(widget.date);
  }

  String time(num value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(widget.date);
    return Scaffold(
      appBar: AppBar(title: Text('${date.day}/${date.month}/${date.year}')),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (_, child) => FutureBuilder<Map<String, dynamic>>(
          future: details,
          builder: (context, snapshot) {
            final activities = historyRecords(widget.store, date: widget.date);
            final completed = [...widget.store.tasks, ...widget.store.plan]
                .where((entry) {
                  final at = DateTime.tryParse(
                    entry['completedAt'] ?? '',
                  )?.toLocal();
                  return entry['done'] == true &&
                      at != null &&
                      dayKey(at) == widget.date;
                })
                .toList();
            final data = snapshot.data ?? {}, granted = data['granted'] == true;
            final days = rows(data['days']),
                day = days.isEmpty ? <String, dynamic>{} : days.first;
            final apps = granted ? rows(day['apps']) : <Map<String, dynamic>>[];
            final sessions = granted
                ? rows(day['sessions']).reversed.toList()
                : <Map<String, dynamic>>[];
            final total = day['milliseconds'] as num? ?? 0;
            return ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const Text(
                  'Nhật ký của bạn',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Các ghi chép dưới đây luôn xem được, không cần quyền theo dõi ứng dụng.',
                  style: TextStyle(color: flowMuted),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Hoạt động bạn đã ghi',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (activities.isEmpty)
                  const Text('Chưa có hoạt động tự ghi trong ngày này.'),
                for (final activity in activities)
                  ActivityRecordCard(store: widget.store, entry: activity),
                TextButton(
                  onPressed: () => openActivityHistory(context, widget.store),
                  child: const Text('Xem tất cả hoạt động'),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Việc đã hoàn thành',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                if (completed.isEmpty)
                  const Text('Chưa có việc hoàn thành trong ngày này.'),
                for (final entry in completed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: flowBlue,
                    ),
                    title: Text(entry['title']),
                    subtitle: (entry['reflection'] ?? '').toString().isEmpty
                        ? null
                        : Text(entry['reflection']),
                  ),
                const Divider(height: 36),
                const Text(
                  'Thời gian ứng dụng',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                if (snapshot.connectionState != ConnectionState.done) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const Text('Đang đọc thống kê Android…'),
                ] else if (snapshot.hasError)
                  TextButton(
                    onPressed: () => setState(
                      () => details = widget.store.device.usageDay(widget.date),
                    ),
                    child: const Text(
                      'Chưa đọc được thống kê ứng dụng. Thử lại',
                    ),
                  )
                else if (!granted)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Chưa cấp quyền xem thời gian sử dụng ứng dụng. Nhật ký của bạn vẫn hiển thị ở trên.',
                      style: TextStyle(color: flowMuted),
                    ),
                  )
                else ...[
                  Text(
                    total == 0 && apps.isEmpty
                        ? 'Chưa có dữ liệu'
                        : usageDuration(total),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (apps.isEmpty)
                    const FlowCard(
                      child: Text(
                        'Android chưa có lịch sử khả dụng cho ngày này.',
                      ),
                    ),
                  for (final app in apps)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppIdentityIcon(
                        device: widget.store.device,
                        package: app['package'],
                        name: app['name'],
                      ),
                      title: Text(app['name']),
                      trailing: Text(
                        usageDuration(app['milliseconds']),
                        style: const TextStyle(color: flowBlue, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Các lần dùng ứng dụng',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  if (sessions.isEmpty)
                    Text(
                      day['aggregate'] == true
                          ? 'Android còn số liệu tổng hợp, nhưng lịch sử từng lần mở ứng dụng đã hết hạn.'
                          : 'Android chưa cung cấp chi tiết các lần mở ứng dụng.',
                      style: const TextStyle(color: flowMuted, fontSize: 12),
                    ),
                  for (final session in sessions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppIdentityIcon(
                        device: widget.store.device,
                        package: session['package'],
                        name: session['name'],
                        size: 32,
                      ),
                      title: Text(session['name']),
                      subtitle: Text(
                        '${time(session['start'] as num)}–${time(session['end'] as num)}',
                      ),
                      trailing: Text(
                        usageDuration(session['milliseconds']),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
