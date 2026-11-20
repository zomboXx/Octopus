import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'brain_store.dart';

Future<void> removeScheduleEntry(
  BuildContext context,
  BrainStore store,
  List<Map<String, dynamic>> entries,
  Map<String, dynamic> entry, {
  required bool recurring,
}) async {
  final index = entries.indexWhere((item) => item['id'] == entry['id']);
  if (index < 0) return;
  final saved = entries.removeAt(index);
  await store.save();
  if (store.storageError != null) {
    entries.insert(math.min(index, entries.length), saved);
    store.refreshViews();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(store.storageError!)));
    }
    return;
  }
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      content: Text(
        '${recurring ? 'Đã xóa lịch lặp hằng tuần' : 'Đã bỏ buổi khỏi lịch'}: ${entry['title']}',
      ),
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () async {
          if (entries.any((item) => item['id'] == saved['id'])) return;
          entries.insert(math.min(index, entries.length), saved);
          await store.save();
          if (store.storageError != null) {
            messenger.showSnackBar(
              SnackBar(content: Text(store.storageError!)),
            );
          }
        },
      ),
    ),
  );
}
