import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'flow_design.dart';
import 'main.dart' show clockText, dateText;
import 'task_checkout.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.store,
    required this.day,
    required this.changeDay,
    required this.addTask,
    required this.activity,
    required this.voice,
    required this.activityCard,
  });
  final BrainStore store;
  final int day;
  final ValueChanged<int> changeDay;
  final VoidCallback addTask, activity, voice;
  final Widget Function(Map<String, dynamic>) activityCard;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day + day);
    final entries = store.workOn(date);
    final done = entries.where((t) => t['done'] == true).length;
    final progress = entries.isEmpty ? 0.0 : done / entries.length;
    final rawName = (store.profile['name'] as String? ?? '').trim();
    final name = rawName.isEmpty ? 'bạn' : rawName.split(RegExp(r'\s+')).last;
    final greeting = now.hour < 12
        ? 'Chào buổi sáng'
        : now.hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              Text(
                '$greeting, $name',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                entries.isEmpty
                    ? 'Một ngày có chủ đích. Bắt đầu bằng một việc nhỏ.'
                    : done == entries.length
                    ? 'Bạn đã hoàn thành những điều quan trọng. Nghỉ một chút nhé.'
                    : 'Còn ${entries.length - done} việc cần làm. Cứ từng bước, theo nhịp của bạn.',
                style: const TextStyle(
                  color: flowMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FlowCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3.5,
                              backgroundColor: flowTint,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: flowBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nhịp ngày',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$done / ${entries.length} việc đã hoàn thành',
                            style: const TextStyle(
                              fontSize: 11,
                              color: flowMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: activity,
                      icon: const Icon(Icons.add_rounded, color: flowBlue),
                      tooltip: 'Ghi hoạt động',
                      style: IconButton.styleFrom(backgroundColor: flowTint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      day == 0 ? 'Việc hôm nay' : 'Việc ngày mai',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                  Text(
                    dateText(date),
                    style: const TextStyle(color: flowMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: addTask,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Thêm'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final d in [0, 1]) ...[
                    ChoiceChip(
                      label: Text(d == 0 ? 'Hôm nay' : 'Ngày mai'),
                      selected: day == d,
                      showCheckmark: false,
                      onSelected: (_) => changeDay(d),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: day == d ? Colors.white : flowMuted,
                      ),
                      selectedColor: flowBlue,
                      backgroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: day == d ? flowBlue : flowLine),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                FlowCard(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const Icon(
                        Icons.wb_sunny_outlined,
                        color: flowBlue,
                        size: 32,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Chừa chỗ cho điều quan trọng.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Chọn 2–3 việc bạn muốn hoàn thành.\nLịch đã xác nhận cũng sẽ có mặt ở đây.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: flowMuted),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: addTask,
                        child: const Text('Thêm việc đầu tiên'),
                      ),
                    ],
                  ),
                )
              else
                FlowCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 3,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        _task(context, entries[i], now),
                        if (i < entries.length - 1)
                          const Divider(height: 1, color: flowLine),
                      ],
                    ],
                  ),
                ),
              if (store.activities.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Những điều đã làm',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...store.activities.reversed.take(2).map(activityCard),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: flowLine),
              boxShadow: [
                BoxShadow(
                  color: flowBlue.withValues(alpha: .04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: flowBlue,
                ),
                Expanded(
                  child: TextButton(
                    onPressed: addTask,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text(
                      'Ghi nhanh điều cần làm…',
                      style: TextStyle(color: flowMuted, fontSize: 12),
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: voice,
                  icon: const Icon(Icons.mic_none_rounded, size: 21),
                  tooltip: 'Thêm việc bằng giọng nói',
                  style: IconButton.styleFrom(backgroundColor: flowBlue),
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _task(BuildContext context, Map<String, dynamic> task, DateTime now) {
    final start = DateTime.tryParse(task['start'] ?? '')?.toLocal();
    final end = DateTime.tryParse(task['end'] ?? '')?.toLocal();
    final completed = task['done'] == true;
    final active =
        !completed &&
        start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
    final minutes =
        task['minutes'] ??
        (end != null && start != null ? end.difference(start).inMinutes : 30);
    return Padding(
      key: ValueKey('work:${task['id']}'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 29,
            height: 29,
            child: Checkbox(
              value: completed,
              shape: const CircleBorder(),
              side: const BorderSide(color: Color(0xffb4c2e4), width: 1.3),
              onChanged: (v) async {
                if (v == true) {
                  await checkOutTask(context, store, task);
                } else {
                  task['done'] = false;
                  task.remove('completedAt');
                  await store.save();
                }
              },
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FlowTag(
                        completed
                            ? 'Đã hoàn thành'
                            : active
                            ? 'Đang đến giờ'
                            : task['subject'] ?? 'Việc của bạn',
                        filled: active,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      start != null ? clockText(start) : 'Linh hoạt',
                      style: const TextStyle(fontSize: 10, color: flowMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: -.2,
                    color: completed ? flowMuted : flowInk,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if ((task['expectedOutput'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    task['expectedOutput'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: flowMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: flowMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$minutes phút',
                      style: const TextStyle(fontSize: 10, color: flowMuted),
                    ),
                    if (active) ...[
                      const Spacer(),
                      InkWell(
                        onTap: () => checkOutTask(context, store, task),
                        borderRadius: BorderRadius.circular(20),
                        child: const FlowTag(
                          'Check-out',
                          icon: Icons.check_rounded,
                          filled: true,
                        ),
                      ),
                    ],
                  ],
                ),
                if ((task['reflection'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      task['reflection'],
                      style: const TextStyle(fontSize: 11, color: flowBlue),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
