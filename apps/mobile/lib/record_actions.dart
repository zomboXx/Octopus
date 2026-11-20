import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'task_editor.dart';

bool focusUsesTask(BrainStore store, String id) =>
    store.focusTaskId == id && store.focusEnd?.isAfter(DateTime.now()) == true;
Future<void> deleteRecord(
  BuildContext context,
  BrainStore store,
  List<Map<String, dynamic>> entries,
  Map<String, dynamic> entry, {
  required String noun,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (identical(entries, store.tasks) && focusUsesTask(store, entry['id'])) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Kết thúc phiên tập trung gắn với công việc này trước khi xóa.',
        ),
      ),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Xóa $noun?'),
      content: Text(
        '${entry['title']} sẽ được bỏ khỏi danh sách và thống kê tương ứng. Bạn có thể hoàn tác trong 10 giây sau khi xóa.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Giữ lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text('Xóa $noun'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final index = entries.indexWhere((r) => r['id'] == entry['id']);
  if (index < 0) return;
  final saved = entries.removeAt(index);
  await store.save();
  if (store.storageError != null) {
    entries.insert(math.min(index, entries.length), saved);
    store.refreshViews();
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(store.storageError!)));
    }
    return;
  }
  if (!messenger.mounted) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Đã xóa $noun.'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () async {
          if (entries.any((r) => r['id'] == saved['id'])) return;
          entries.insert(math.min(index, entries.length), saved);
          await store.save();
          if (store.storageError != null && messenger.mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(store.storageError!)),
            );
          }
        },
      ),
    ),
  );
}

class TaskActions extends StatelessWidget {
  const TaskActions({super.key, required this.store, required this.task});
  final BrainStore store;
  final Map<String, dynamic> task;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Tùy chọn việc ${task['title']}',
    icon: const Icon(Icons.more_horiz),
    onSelected: (action) async {
      if (action == 'edit' || action == 'date') {
        await showDialog<void>(
          context: context,
          builder: (_) => TaskEditor(
            store: store,
            task: task,
            chooseDate: action == 'date',
          ),
        );
        return;
      }
      if (action == 'delete') {
        await deleteRecord(
          context,
          store,
          store.tasks,
          task,
          noun: 'công việc',
        );
        return;
      }
      if (focusUsesTask(store, task['id'])) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kết thúc phiên tập trung gắn với việc này trước khi dời ngày.',
            ),
          ),
        );
        return;
      }
      final target = action == 'tomorrow'
          ? DateTime.now().add(const Duration(days: 1))
          : DateTime.now();
      final ok = await store.updateRecord(store.tasks, task['id'], {
        'date': dayKey(target),
      });
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(store.storageError ?? 'Không còn công việc này.'),
          ),
        );
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit', child: Text('Sửa công việc')),
      if (task['done'] != true) ...[
        const PopupMenuItem(value: 'today', child: Text('Dời sang hôm nay')),
        const PopupMenuItem(
          value: 'tomorrow',
          child: Text('Dời sang ngày mai'),
        ),
        const PopupMenuItem(value: 'date', child: Text('Chọn ngày khác')),
      ],
      const PopupMenuItem(value: 'delete', child: Text('Xóa công việc')),
    ],
  );
}
