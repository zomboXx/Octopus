import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'brain_store.dart';
import 'main.dart' show blue, muted;
import 'flow_design.dart';

Future<void> checkOutTask(
  BuildContext context,
  BrainStore store,
  Map<String, dynamic> task, {
  bool completedFromWidget = false,
}) async {
  if (completedFromWidget && task['done'] != true) {
    await store.completeWork(task);
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: flowInk.withValues(alpha: .23),
    builder: (_) => BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: TaskCheckout(store: store, task: task),
        ),
      ),
    ),
  );
}

class TaskCheckout extends StatefulWidget {
  const TaskCheckout({super.key, required this.store, required this.task});
  final BrainStore store;
  final Map<String, dynamic> task;
  @override
  State<TaskCheckout> createState() => _TaskCheckoutState();
}

class _TaskCheckoutState extends State<TaskCheckout> {
  final reflection = TextEditingController();
  String audience = 'private';
  Set<String> recipients = {};
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    reflection.text = widget.task['reflection'] ?? '';
    audience = widget.task['audience'] ?? 'private';
    recipients = Set<String>.from(widget.task['recipients'] ?? []);
  }

  @override
  void dispose() {
    reflection.dispose();
    super.dispose();
  }

  Future<void> save({bool skip = false}) async {
    if (audience == 'selected' && recipients.isEmpty && !skip) {
      setState(() => error = 'Chọn ít nhất một người hoặc giữ riêng tư.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.completeWork(
        widget.task,
        reflection: skip ? '' : reflection.text,
        audience: skip ? 'private' : audience,
        recipients: skip ? [] : recipients.toList(),
      );
      if (!mounted) return;
      if (widget.store.storageError != null) {
        setState(() => error = widget.store.storageError);
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Chưa lưu được. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = <String, String>{};
    for (final circle in widget.store.circles) {
      for (final m in circle['members'] as List) {
        members[m['id']] = m['name'];
      }
    }
    return Padding(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(width: double.infinity, height: 64),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: flowTint,
                    border: Border.all(color: flowCanvas, width: 7),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: blue,
                    size: 30,
                  ),
                ),
                Positioned(
                  right: -8,
                  top: -8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Đóng',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FlowTag(widget.task['title'], icon: Icons.menu_book_outlined),
            const SizedBox(height: 16),
            const Text(
              'Bạn đã làm được gì?',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Một dòng nhìn lại để thấy mình đã tiến bộ.',
              style: TextStyle(color: muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('checkout-reflection'),
              controller: reflection,
              maxLength: 160,
              minLines: 3,
              maxLines: 4,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Ví dụ, đã đọc 10 trang sách và ghi lại 3 ý chính.',
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'GỢI Ý NHANH',
                style: TextStyle(fontSize: 9, color: muted, letterSpacing: .7),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: ['Đã đọc xong', 'Đã ghi chú', 'Đã giải bài tập']
                  .map(
                    (s) => ActionChip(
                      label: Text('+ $s', style: const TextStyle(fontSize: 10)),
                      onPressed: () => setState(() {
                        final next = reflection.text.isEmpty
                            ? s
                            : '${reflection.text}; $s';
                        reflection.text = next.length > 160
                            ? next.substring(0, 160)
                            : next;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              style: const TextStyle(
                fontSize: 12,
                color: flowInk,
                fontFamily: 'Roboto',
              ),
              initialValue: audience,
              decoration: const InputDecoration(
                labelText: 'Ai được xem ghi nhận này?',
              ),
              items: const [
                DropdownMenuItem(value: 'private', child: Text('Chỉ mình tôi')),
                DropdownMenuItem(
                  value: 'group',
                  child: Text('Các nhóm của tôi'),
                ),
                DropdownMenuItem(
                  value: 'selected',
                  child: Text('Người được chọn'),
                ),
              ],
              onChanged: (v) => setState(() => audience = v!),
            ),
            if (audience == 'selected') ...[
              if (members.isEmpty)
                const Text(
                  'Thêm bạn trong mục Nhóm để chọn người xem.',
                  style: TextStyle(color: muted),
                ),
              Wrap(
                spacing: 6,
                children: members.entries
                    .map(
                      (m) => FilterChip(
                        label: Text(m.value),
                        selected: recipients.contains(m.key),
                        onSelected: (v) => setState(() {
                          v ? recipients.add(m.key) : recipients.remove(m.key);
                        }),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (audience != 'private')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Hiện lưu lựa chọn trên máy; chưa gửi nội dung cho bạn bè.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : () => save(),
                icon: const Icon(Icons.check),
                label: Text(
                  saving ? 'Đang lưu…' : 'Hoàn thành & lưu ghi nhận',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            TextButton(
              onPressed: saving ? null : () => save(skip: true),
              child: const Text(
                'Hoàn thành, bỏ qua ghi nhận',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
