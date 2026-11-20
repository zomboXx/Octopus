import 'package:flutter/material.dart';
import 'brain_store.dart';

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    required this.store,
    required this.task,
    this.chooseDate = false,
  });
  final BrainStore store;
  final Map<String, dynamic> task;
  final bool chooseDate;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final title = TextEditingController(),
      minutes = TextEditingController(),
      note = TextEditingController();
  late DateTime date;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    title.text = widget.task['title'];
    minutes.text = '${widget.task['minutes'] ?? 30}';
    note.text = widget.task['note'] ?? '';
    date = DateTime.tryParse(widget.task['date'] ?? '') ?? DateTime.now();
    if (widget.chooseDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pickDate();
      });
    }
  }

  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1900),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      helpText: 'Ngày thực hiện',
    );
    if (value != null && mounted) setState(() => date = value);
  }

  Future<void> save() async {
    final count = int.tryParse(minutes.text) ?? 0;
    if (title.text.trim().isEmpty || title.text.trim().length > 140) {
      setState(() => error = 'Nhập tên công việc, tối đa 140 ký tự.');
      return;
    }
    if (count < 1 || count > 480) {
      setState(() => error = 'Thời lượng cần từ 1 đến 480 phút.');
      return;
    }
    final store = widget.store;
    if (store.focusTaskId == widget.task['id'] &&
        store.focusEnd?.isAfter(DateTime.now()) == true &&
        dayKey(date) != widget.task['date']) {
      setState(
        () => error =
            'Kết thúc phiên tập trung gắn với việc này trước khi dời ngày.',
      );
      return;
    }
    setState(() => busy = true);
    final saved = await store.updateRecord(store.tasks, widget.task['id'], {
      'title': title.text.trim(),
      'minutes': count,
      'note': note.text.trim(),
      'date': dayKey(date),
    });
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      busy = false;
      error = store.storageError ?? 'Công việc này không còn trong danh sách.';
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sửa công việc'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('edit-task-title'),
            controller: title,
            enabled: !busy,
            maxLength: 140,
            decoration: const InputDecoration(labelText: 'Tên công việc'),
          ),
          TextField(
            controller: minutes,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Thời lượng (phút)'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày thực hiện'),
            subtitle: Text('${date.day}/${date.month}/${date.year}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: busy || widget.task['done'] == true ? null : pickDate,
          ),
          if (widget.task['done'] == true)
            const Text(
              'Giữ nguyên ngày và kết quả hoàn thành của công việc này.',
            ),
          TextField(
            controller: note,
            enabled: !busy,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Đang lưu…' : 'Lưu thay đổi'),
      ),
    ],
  );
}
