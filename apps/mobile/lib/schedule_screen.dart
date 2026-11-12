import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'planning_api.dart';
import 'planning_rules.dart';
import 'schedule_calendar.dart';
import 'task_checkout.dart';
import 'main.dart'
    show Panel, Pill, PageIntro, blue, muted, clockText, dateText;

String minuteText(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.store});
  final BrainStore store;
  Future<void> edit(
    BuildContext context, [
    Map<String, dynamic>? existing,
  ]) async {
    final entry = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CommitmentEditor(store: store, existing: existing),
    );
    if (entry == null) return;
    store.commitments.removeWhere((c) => c['id'] == entry['id']);
    store.commitments.add(entry);
    await store.save();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const PageIntro(
          'Thời gian, theo cách của bạn.',
          'Giữ chỗ cho lịch cố định. Dành phần còn lại cho mục tiêu.',
        ),
        const SizedBox(height: 24),
        Panel(
          color: const Color(0xffeaf1ff),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Pill('01 · LỊCH CỐ ĐỊNH'),
              const SizedBox(height: 12),
              const Text(
                'Những khung giờ không thể đổi',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lịch đi học, đi làm và thời gian riêng lặp lại mỗi tuần. Bạn có thể sửa bất cứ lúc nào.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 12),
              for (final c in store.commitments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['title']),
                  subtitle: Text(
                    '${(c['weekdays'] as List).map((d) => weekdays[d - 1]).join(', ')} · ${minuteText(c['startMinute'])}–${minuteText(c['endMinute'])}',
                  ),
                  onTap: () => edit(context, c),
                  trailing: IconButton(
                    tooltip: 'Xóa lịch cố định',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      store.commitments.remove(c);
                      store.save();
                    },
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Thêm lịch cố định'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => StudyPreferencesEditor(store: store),
          ),
          icon: const Icon(Icons.tune),
          label: Text(
            'Khung học ${minuteText(store.studyPreferences['startMinute'])}–${minuteText(store.studyPreferences['endMinute'])} · ${store.studyPreferences['dailyMinutes']} phút/ngày',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: store.commitments.isEmpty
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudyPlannerScreen(store: store),
                  ),
                ),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Lên kế hoạch cùng AI'),
        ),
        const SizedBox(height: 10),
        if (store.commitments.isEmpty)
          const Text(
            'Nhập lịch đi học / đi làm ở bước 01 trước khi dùng AI. Chưa gửi yêu cầu hay tốn lượt tạo lịch.',
            style: TextStyle(color: blue),
          ),
        const Text(
          'Gợi ý luôn được xem trước. Chỉ thêm vào lịch khi bạn xác nhận. Hiện hỗ trợ múi giờ Việt Nam.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 26),
        ScheduleOverview(
          store: store,
          editFixed: (entry) => edit(context, entry),
          sessionBuilder: (p) => SessionCard(
            key: ValueKey(p['id']),
            session: p,
            showStatus: true,
            trailing: Wrap(
              children: [
                TextButton.icon(
                  onPressed: p['done'] == true
                      ? null
                      : () => checkOutTask(context, store, p),
                  icon: const Icon(Icons.task_alt),
                  label: Text(
                    p['done'] == true ? 'Đã hoàn thành' : 'Check-out',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    store.plan.remove(p);
                    store.save();
                  },
                  child: const Text('Bỏ khỏi lịch'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CommitmentEditor extends StatefulWidget {
  const CommitmentEditor({super.key, required this.store, this.existing});
  final BrainStore store;
  final Map<String, dynamic>? existing;
  @override
  State<CommitmentEditor> createState() => _CommitmentEditorState();
}

class _CommitmentEditorState extends State<CommitmentEditor> {
  final title = TextEditingController();
  Set<int> days = {1};
  int start = 8 * 60, end = 12 * 60;
  String? error;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      title.text = e['title'];
      days = Set<int>.from(e['weekdays']);
      start = e['startMinute'];
      end = e['endMinute'];
    }
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> time(bool first) async {
    final value = first ? start : end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    );
    if (picked != null && mounted) {
      setState(() {
        if (first) {
          start = picked.hour * 60 + picked.minute;
        } else {
          end = picked.hour * 60 + picked.minute;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Lịch cố định hằng tuần' : 'Sửa lịch cố định',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Tên lịch (đi học, đi làm…)',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 5,
            children: List.generate(
              7,
              (i) => FilterChip(
                label: Text(weekdays[i]),
                selected: days.contains(i + 1),
                onSelected: (v) => setState(() {
                  v ? days.add(i + 1) : days.remove(i + 1);
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => time(true),
            child: Text('Bắt đầu · ${minuteText(start)}'),
          ),
          OutlinedButton(
            onPressed: () => time(false),
            child: Text('Kết thúc · ${minuteText(end)}'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final entry = {
            'id':
                widget.existing?['id'] ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            'title': title.text.trim(),
            'weekdays': days.toList()..sort(),
            'startMinute': start,
            'endMinute': end,
          };
          final invalid = commitmentError(entry, widget.store.commitments);
          if (invalid != null) {
            setState(() => error = invalid);
            return;
          }
          Navigator.pop(context, entry);
        },
        child: const Text('Lưu lịch cố định'),
      ),
    ],
  );
}

class StudyPreferencesEditor extends StatefulWidget {
  const StudyPreferencesEditor({super.key, required this.store});
  final BrainStore store;
  @override
  State<StudyPreferencesEditor> createState() => _StudyPreferencesEditorState();
}

class _StudyPreferencesEditorState extends State<StudyPreferencesEditor> {
  late int start, end, session, daily;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.store.studyPreferences;
    start = p['startMinute'];
    end = p['endMinute'];
    session = p['sessionMinutes'];
    daily = p['dailyMinutes'];
  }

  Future<void> time(bool first) async {
    final n = first ? start : end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
    );
    if (picked != null && mounted) {
      setState(() {
        if (first) {
          start = picked.hour * 60 + picked.minute;
        } else {
          end = picked.hour * 60 + picked.minute;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nhịp học của bạn'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () => time(true),
            child: Text('Có thể học từ ${minuteText(start)}'),
          ),
          OutlinedButton(
            onPressed: () => time(false),
            child: Text('Kết thúc trước ${minuteText(end)}'),
          ),
          DropdownButtonFormField<int>(
            initialValue: session,
            decoration: const InputDecoration(
              labelText: 'Thời lượng mỗi phiên',
            ),
            items: [25, 30, 45, 60, 90]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n phút')))
                .toList(),
            onChanged: (n) => session = n!,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: daily,
            decoration: const InputDecoration(labelText: 'Tối đa mỗi ngày'),
            items: [60, 90, 120, 180, 240, 360, 480]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n phút')))
                .toList(),
            onChanged: (n) => daily = n!,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chừa 10 phút giữa các khung gợi ý. Lịch cố định luôn được giữ nguyên.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () async {
          if (end <= start || daily < session) {
            setState(
              () => error = 'Kiểm tra khung giờ và số phút tối đa mỗi ngày.',
            );
            return;
          }
          widget.store.studyPreferences = {
            'startMinute': start,
            'endMinute': end,
            'sessionMinutes': session,
            'dailyMinutes': daily,
          };
          await widget.store.save();
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Lưu nhịp học'),
      ),
    ],
  );
}

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key, required this.store});
  final BrainStore store;
  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final request = TextEditingController(),
      contextInput = TextEditingController(),
      accessCode = TextEditingController();
  Map<String, dynamic>? draft;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    contextInput.text = widget.store.profile['learningContext'] ?? '';
  }

  @override
  void dispose() {
    request.dispose();
    contextInput.dispose();
    accessCode.dispose();
    super.dispose();
  }

  Future<void> generate() async {
    if (widget.store.commitments.isEmpty) {
      setState(() => error = 'Hãy nhập lịch cố định trước khi dùng AI.');
      return;
    }
    if (request.text.trim().isEmpty) {
      setState(() => error = 'Mô tả mục tiêu và ngày cần hoàn thành.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      draft = null;
    });
    try {
      widget.store.profile['learningContext'] = contextInput.text.trim();
      await widget.store.save();
      final data = await PlanningApi().draft(
        widget.store,
        request.text.trim(),
        contextInput.text.trim(),
        accessCode: accessCode.text.trim(),
      );
      if (mounted) setState(() => draft = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Chưa tạo được lịch. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> accept() async {
    if (busy) return;
    final sessions = (draft!['sessions'] as List)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final invalid = planError(sessions, widget.store, DateTime.now());
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    setState(() => busy = true);
    for (final (i, p) in sessions.indexed) {
      widget.store.plan.add({
        ...p,
        'id': '${DateTime.now().microsecondsSinceEpoch}-$i',
        'kind': 'focus',
        'source': 'ai',
      });
    }
    await widget.store.save();
    if (!mounted) return;
    if (widget.store.storageError != null) {
      setState(() => error = widget.store.storageError);
      setState(() => busy = false);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kế hoạch học tập')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const PageIntro(
            'Mục tiêu rõ. Từng buổi vừa sức.',
            'AI dựa trên lịch cố định và nhịp học của riêng bạn.',
          ),
          const SizedBox(height: 22),
          Panel(
            color: const Color(0xffeef1ff),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.store.commitments.length} lịch cố định đã lưu',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final c in widget.store.commitments)
                  Text(
                    '${c['title']} · ${(c['weekdays'] as List).map((d) => weekdays[d - 1]).join(', ')} · ${minuteText(c['startMinute'])}–${minuteText(c['endMinute'])}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'AI chỉ chọn giờ rảnh. Không gọi AI để hỏi lại thời khóa biểu.',
                  style: TextStyle(color: blue, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (PlanningApi().needsAccessCode) ...[
            TextField(
              controller: accessCode,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Mã thử AI của nhóm',
                helperText: 'Không nhập key PoolAI. Mã chỉ giữ trong màn này.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: request,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Bạn muốn đạt điều gì?',
              hintText:
                  'DBMS kiểm tra sau 3 ngày, CNPM sau 4 ngày, KTLT sau 5 ngày. Giúp tôi lên kế hoạch ôn.',
            ),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(
                    () => request.text =
                        'Tôi kiểm tra DBMS trong 3 ngày nữa, CNPM trong 4 ngày nữa và KTLT trong 5 ngày nữa. Hãy lập lịch ôn và nội dung từng buổi.',
                  ),
            child: const Text('Dùng ví dụ DBMS · CNPM · KTLT'),
          ),
          TextField(
            controller: contextInput,
            minLines: 3,
            maxLines: 6,
            maxLength: 6000,
            decoration: const InputDecoration(
              labelText: 'Đề cương, phần còn yếu, cách học yêu thích',
              hintText:
                  'DBMS: JOIN và chuẩn hóa; tôi còn yếu truy vấn lồng. Mỗi buổi cần bài tập và tự kiểm tra…',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Khi tạo kế hoạch, yêu cầu, ngữ cảnh học, khung giờ và tiêu đề lịch được gửi tới dịch vụ AI qua PoolAI. Không gửi họ tên, sinh nhật, ảnh hoặc nhật ký.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy || widget.store.commitments.isEmpty
                ? null
                : generate,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(
              busy ? 'Đang sắp xếp kế hoạch…' : 'Tạo kế hoạch để xem trước',
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                error!,
                key: const Key('planner-error'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (draft != null) ...[
            const SizedBox(height: 26),
            Text(
              draft!['summary'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final q in draft!['questions'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Cần bổ sung: $q',
                  style: const TextStyle(color: blue),
                ),
              ),
            for (final a in draft!['assumptions'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Giả định: $a',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
            const SizedBox(height: 12),
            for (final p in draft!['sessions'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SessionCard(
                  key: ValueKey(p['slotId']),
                  session: Map<String, dynamic>.from(p),
                  trailing: TextButton(
                    onPressed: () =>
                        setState(() => (draft!['sessions'] as List).remove(p)),
                    child: const Text('Bỏ phiên này'),
                  ),
                ),
              ),
            if ((draft!['sessions'] as List).isNotEmpty) ...[
              const Text(
                'Nội dung là gợi ý ôn tập; hãy đối chiếu đề cương môn học. Bạn có thể bỏ phiên chưa phù hợp trước khi xác nhận.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : accept,
                child: const Text('Xác nhận thêm vào lịch'),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

class SessionCard extends StatefulWidget {
  const SessionCard({
    super.key,
    required this.session,
    this.trailing,
    this.showStatus = false,
  });
  final Map<String, dynamic> session;
  final Widget? trailing;
  final bool showStatus;
  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  bool expanded = false;
  Map<String, dynamic> get session => widget.session;
  @override
  Widget build(BuildContext context) {
    final s = DateTime.parse(
      session['start'],
    ).toUtc().add(const Duration(hours: 7));
    final e = DateTime.parse(
      session['end'],
    ).toUtc().add(const Duration(hours: 7));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Pill(session['subject'] ?? 'TẬP TRUNG')),
              const Spacer(),
              Text(dateText(s), style: const TextStyle(color: muted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${clockText(s)} — ${clockText(e)}',
            style: const TextStyle(color: blue, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (widget.showStatus) SessionStatusTags(session: session),
          Text(
            session['title'],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (expanded && session['objectives'] is List) ...[
            const SizedBox(height: 10),
            for (final o in session['objectives']) Text('• $o'),
          ],
          if (expanded && session['steps'] is List) ...[
            const SizedBox(height: 12),
            for (final (i, step) in (session['steps'] as List).indexed)
              Text(
                '${i + 1}. $step',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
          ],
          if (expanded && session['expectedOutput'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Kết quả: ${session['expectedOutput']}',
                style: const TextStyle(fontSize: 13, color: blue),
              ),
            ),
          if (session['steps'] is List)
            TextButton.icon(
              onPressed: () => setState(() => expanded = !expanded),
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(expanded ? 'Thu gọn' : 'Nội dung buổi ôn'),
            ),
          if (widget.trailing != null)
            Align(alignment: Alignment.centerRight, child: widget.trailing),
        ],
      ),
    );
  }
}
