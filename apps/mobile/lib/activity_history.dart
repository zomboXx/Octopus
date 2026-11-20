import 'dart:io';
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'flow_design.dart';
import 'main.dart' show ActivityEditor;
import 'record_actions.dart';
import 'usage_day_screen.dart';

DateTime? activityEnd(Map<String, dynamic> entry) =>
    DateTime.tryParse(entry['end'] ?? '')?.toLocal();
List<Map<String, dynamic>> historyRecords(
  BrainStore store, {
  String query = '',
  String? date,
}) {
  final search = query.trim().toLowerCase();
  final result = store.activities
      .where(
        (a) =>
            (date == null ||
                dayKey(activityEnd(a) ?? DateTime(1900)) == date) &&
            (search.isEmpty ||
                '${a['title']} ${a['note'] ?? ''}'.toLowerCase().contains(
                  search,
                )),
      )
      .toList();
  result.sort(
    (a, b) => (activityEnd(b) ?? DateTime(1900)).compareTo(
      activityEnd(a) ?? DateTime(1900),
    ),
  );
  return result;
}

void openActivityHistory(BuildContext context, BrainStore store) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ActivityHistoryScreen(store: store)),
    );
void editActivity(
  BuildContext context,
  BrainStore store,
  Map<String, dynamic> entry,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: flowCanvas,
  builder: (_) => ActivityEditor(store: store, existing: entry),
);

class ActivityRecordCard extends StatelessWidget {
  const ActivityRecordCard({
    super.key,
    required this.store,
    required this.entry,
  });
  final BrainStore store;
  final Map<String, dynamic> entry;
  String stamp(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return 'Chưa có thời gian';
    return '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'HOẠT ĐỘNG TỰ GHI',
                  style: TextStyle(fontSize: 11, color: flowMuted),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn hoạt động ${entry['title']}',
                onSelected: (value) {
                  if (value == 'edit') {
                    editActivity(context, store, entry);
                  } else {
                    deleteRecord(
                      context,
                      store,
                      store.activities,
                      entry,
                      noun: 'hoạt động',
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa hoạt động')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa hoạt động')),
                ],
              ),
            ],
          ),
          Text(
            entry['title'] ?? '',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${stamp(entry['start'])} – ${stamp(entry['end'])}',
            style: const TextStyle(fontSize: 12, color: flowMuted),
          ),
          if ((entry['note'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(entry['note'], style: const TextStyle(height: 1.5)),
            ),
          if (entry['image'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Image.file(
                File(entry['image']),
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: 900,
                errorBuilder: (_, error, stack) =>
                    const Text('Ảnh hiện không còn trên thiết bị.'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            entry['audience'] == null || entry['audience'] == 'private'
                ? 'Chỉ mình tôi'
                : 'Quyền xem lưu cục bộ · chưa chia sẻ',
            style: const TextStyle(fontSize: 11, color: flowMuted),
          ),
        ],
      ),
    ),
  );
}

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key, required this.store});
  final BrainStore store;
  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  String query = '';
  DateTime? date;
  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhật ký hoạt động')),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (_, child) {
        final records = historyRecords(
          widget.store,
          query: query,
          date: date == null ? null : dayKey(date!),
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Toàn bộ hoạt động bạn đã ghi. Không cần quyền theo dõi ứng dụng.',
                    style: TextStyle(color: flowMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: 'Tìm hoạt động',
                      hintText: 'Tên hoạt động hoặc ghi chú',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: chooseDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          date == null
                              ? 'Lọc theo ngày'
                              : '${date!.day}/${date!.month}/${date!.year}',
                        ),
                      ),
                      if (date != null)
                        TextButton(
                          onPressed: () => setState(() => date = null),
                          child: const Text('Mọi ngày'),
                        ),
                    ],
                  ),
                  Text(
                    '${records.length} / ${widget.store.activities.length} hoạt động',
                    style: const TextStyle(color: flowMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chưa có hoạt động phù hợp. Thử đổi từ khóa hoặc ngày.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: records.length,
                      itemBuilder: (_, i) {
                        final current = activityEnd(records[i]);
                        final previous = i == 0
                            ? null
                            : activityEnd(records[i - 1]);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (i == 0 ||
                                current != null &&
                                    previous != null &&
                                    dayKey(current) != dayKey(previous))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  current == null
                                      ? 'Chưa rõ ngày'
                                      : '${current.day}/${current.month}/${current.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ActivityRecordCard(
                              store: widget.store,
                              entry: records[i],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class LocalJournalPanel extends StatelessWidget {
  const LocalJournalPanel({super.key, required this.store, required this.week});
  final BrainStore store;
  final DateTime week;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, child) {
      final end = DateTime(week.year, week.month, week.day + 7);
      final count = store.activities.where((entry) {
        final date = activityEnd(entry);
        return date != null && !date.isBefore(week) && date.isBefore(end);
      }).length;
      return FlowCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhật ký của bạn',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$count hoạt động đã ghi trong tuần. Nhật ký luôn xem được khi chưa cấp quyền sử dụng ứng dụng.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (i) {
                final date = DateTime(week.year, week.month, week.day + i);
                return ActionChip(
                  tooltip: 'Xem nhật ký ngày ${dayKey(date)}',
                  label: Text('${date.day}/${date.month}'),
                  onPressed: date.isAfter(DateTime.now())
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UsageDayScreen(
                              store: store,
                              date: dayKey(date),
                            ),
                          ),
                        ),
                );
              }),
            ),
            TextButton(
              onPressed: () => openActivityHistory(context, store),
              child: Text('Xem tất cả hoạt động (${store.activities.length})'),
            ),
          ],
        ),
      );
    },
  );
}
