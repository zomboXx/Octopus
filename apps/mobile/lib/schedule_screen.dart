import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'planning_api.dart';
import 'planning_rules.dart';
import 'schedule_calendar.dart';
import 'task_checkout.dart';
import 'time_picker.dart';
import 'schedule_actions.dart';
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
                    onPressed: () => removeScheduleEntry(
                      context,
                      store,
                      store.commitments,
                      c,
                      recurring: true,
                    ),
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
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => StudyPlannerScreen(store: store)),
          ),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(
            store.planningDraft == null
                ? 'Lên kế hoạch cùng AI'
                : 'Tiếp tục bản nháp AI',
          ),
        ),
        const SizedBox(height: 10),
        if (store.commitments.isEmpty)
          const Text(
            'Bạn có thể bắt đầu ngay. Thêm lịch bận nếu cần tránh giờ đi học hoặc đi làm.',
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
                  onPressed: () => removeScheduleEntry(
                    context,
                    store,
                    store.plan,
                    p,
                    recurring: false,
                  ),
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
    final picked = await pickAppTime(
      context,
      TimeOfDay(hour: value ~/ 60, minute: value % 60),
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
    final picked = await pickAppTime(
      context,
      TimeOfDay(hour: n ~/ 60, minute: n % 60),
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
  const StudyPlannerScreen({super.key, required this.store, this.api});
  final BrainStore store;
  final PlanningApi? api;
  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final request = TextEditingController(),
      contextInput = TextEditingController(),
      accessCode = TextEditingController();
  final goalFocus = FocusNode(), codeFocus = FocusNode();
  final resultKey = GlobalKey();
  late final PlanningApi api;
  Map<String, dynamic>? draft;
  DateTime? targetDate;
  bool busy = false;
  int operation = 0;
  int initialSessionCount = 0;
  bool quotaLoading = true;
  String? quotaError;

  @override
  void initState() {
    super.initState();
    api = widget.api ?? PlanningApi();
    request.text = widget.store.profile['lastAIRequest'] ?? '';
    contextInput.text = widget.store.profile['learningContext'] ?? '';
    final saved = widget.store.planningDraft;
    if (saved != null && saved['result'] is Map) {
      request.text = saved['request'] as String? ?? request.text;
      contextInput.text =
          saved['learningContext'] as String? ?? contextInput.text;
      targetDate = DateTime.tryParse(saved['targetDate'] as String? ?? '');
      draft = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(saved['result'])),
      );
      initialSessionCount =
          saved['initialSessionCount'] as int? ??
          (draft!['sessions'] as List).length;
    }
    unawaited(loadQuota());
  }

  Future<void> loadQuota() async {
    try {
      final value = await api.quota(widget.store);
      if (!mounted) return;
      setState(() {
        widget.store.aiQuota = value;
        quotaError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => quotaError =
              'Chưa kiểm tra được số lượt. Bạn có thể thử tạo kế hoạch hoặc kiểm tra lại.',
        );
      }
    } finally {
      if (mounted) setState(() => quotaLoading = false);
    }
  }

  @override
  void dispose() {
    operation++;
    api.cancel();
    request.dispose();
    contextInput.dispose();
    accessCode.dispose();
    goalFocus.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  Future<void> persistDraft() async {
    widget.store.planningDraft = draft == null
        ? null
        : {
            'request': request.text.trim(),
            'learningContext': contextInput.text.trim(),
            'targetDate': targetDate == null ? null : dayKey(targetDate!),
            'initialSessionCount': initialSessionCount,
            'result': draft,
          };
    await widget.store.save();
  }

  void invalidateDraft() {
    draft = null;
    widget.store.planningAttempt = null;
    if (widget.store.planningDraft != null) {
      widget.store.planningDraft = null;
      unawaited(widget.store.save());
    }
  }

  Future<void> removeDraftSession(dynamic session) async {
    final previous = jsonDecode(jsonEncode(draft)) as Map<String, dynamic>;
    setState(() {
      busy = true;
      (draft!['sessions'] as List).remove(session);
    });
    await persistDraft();
    if (!mounted) return;
    if (widget.store.storageError != null) draft = previous;
    setState(() => busy = false);
    if (widget.store.storageError != null) {
      await showFailure(widget.store.storageError!);
    }
  }

  Future<void> discardDraft() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bỏ bản nháp AI?'),
        content: const Text(
          'Các buổi chưa xác nhận sẽ bị bỏ. Tạo kế hoạch AI mới có thể dùng thêm một lượt Starter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Giữ bản nháp'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Bỏ bản nháp'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    final previous = draft;
    setState(() {
      busy = true;
      draft = null;
      widget.store.planningAttempt = null;
    });
    await persistDraft();
    if (!mounted) return;
    if (widget.store.storageError != null) draft = previous;
    setState(() => busy = false);
    if (widget.store.storageError != null) {
      await showFailure(widget.store.storageError!);
    }
  }

  Future<void> showFailure(String message, {FocusNode? focus}) async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.info_outline, color: blue),
        title: const Text('Chưa tạo được kế hoạch'),
        content: SingleChildScrollView(
          child: Text(message, key: const Key('planner-error')),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Quay lại chỉnh sửa'),
          ),
        ],
      ),
    );
    if (mounted) focus?.requestFocus();
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: targetDate?.isBefore(first) == false
          ? targetDate!
          : DateTime(now.year, now.month, now.day + 7),
      firstDate: first,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Bạn muốn hoàn thành trước ngày nào?',
    );
    if (picked != null && mounted) {
      setState(() {
        targetDate = picked;
        invalidateDraft();
      });
    }
  }

  Future<void> generate() async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    if (request.text.trim().isEmpty) {
      await showFailure(
        'Nhập điều bạn muốn học hoặc luyện tập, ví dụ luyện nói tiếng Anh khi đi du lịch.',
        focus: goalFocus,
      );
      return;
    }
    if (api.needsAccessCode && accessCode.text.trim().isEmpty) {
      await showFailure(
        'Nhập mã dùng thử do nhóm Octopus cung cấp.',
        focus: codeFocus,
      );
      return;
    }
    if (targetDate != null && !targetDate!.isAfter(DateTime.now())) {
      await showFailure(
        'Hạn hoàn thành đã qua. Hãy chọn lại ngày từ ngày mai trở đi.',
      );
      return;
    }
    final run = ++operation;
    setState(() {
      busy = true;
      draft = null;
    });
    final navigator = Navigator.of(context);
    late final DialogRoute<void> progress;
    progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: _PlanningProgressDialog(
          onCancel: () {
            operation++;
            api.cancel();
            navigator.removeRoute(progress);
            if (mounted) setState(() => busy = false);
          },
        ),
      ),
    );
    unawaited(navigator.push(progress));
    Map<String, dynamic>? data;
    String? failure;
    try {
      widget.store.profile['lastAIRequest'] = request.text.trim();
      widget.store.profile['learningContext'] = contextInput.text.trim();
      await widget.store.save();
      if (widget.store.storageError != null) {
        throw FormatException(widget.store.storageError!);
      }
      if (operation != run) return;
      data = await api.draft(
        widget.store,
        request.text.trim(),
        contextInput.text.trim(),
        accessCode: accessCode.text.trim(),
        targetDate: targetDate == null ? null : dayKey(targetDate!),
      );
    } catch (e) {
      failure = e is FormatException
          ? e.message
          : 'Dịch vụ chưa tạo được kế hoạch. Hãy thử lại sau ít phút.';
    } finally {
      if (progress.isActive) navigator.removeRoute(progress);
      if (mounted && operation == run) setState(() => busy = false);
    }
    if (!mounted || operation != run) return;
    if (failure != null) {
      unawaited(loadQuota());
      await showFailure(
        failure,
        focus: failure.toLowerCase().contains('mã') ? codeFocus : null,
      );
      return;
    }
    if (data!['status'] != 'draft' || (data['sessions'] as List).isEmpty) {
      final supplement = await showDialog<String>(
        context: context,
        builder: (_) => _PlannerFeedbackDialog(data: data!),
      );
      if (!mounted) return;
      if (supplement != null && supplement.isNotEmpty) {
        if (request.text.length + supplement.length + 1 > 4000) {
          await showFailure(
            'Hãy rút gọn mục tiêu trước khi bổ sung thông tin.',
            focus: goalFocus,
          );
          return;
        }
        request.text = '${request.text.trim()}\n$supplement';
        await generate();
      } else {
        goalFocus.requestFocus();
      }
      return;
    }
    setState(() {
      draft = data;
      initialSessionCount = (data!['sessions'] as List).length;
    });
    await persistDraft();
    if (!mounted) return;
    if (widget.store.storageError != null) {
      await showFailure(
        'Kế hoạch đã tạo nhưng chưa lưu được bản nháp. ${widget.store.storageError}',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resultContext = resultKey.currentContext;
      if (resultContext != null) {
        Scrollable.ensureVisible(
          resultContext,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  Future<void> accept() async {
    if (busy || draft == null) return;
    final sessions = (draft!['sessions'] as List)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final invalid = planError(sessions, widget.store, DateTime.now());
    if (invalid != null) {
      await showFailure(invalid);
      return;
    }
    setState(() => busy = true);
    final added = [
      for (final (i, p) in sessions.indexed)
        {
          ...p,
          'id': '${DateTime.now().microsecondsSinceEpoch}-$i',
          'kind': 'focus',
          'source': 'ai',
        },
    ];
    widget.store.plan.addAll(added);
    final savedDraft = widget.store.planningDraft;
    widget.store.planningDraft = null;
    await widget.store.save();
    if (widget.store.storageError != null) {
      widget.store.plan.removeWhere(added.contains);
      widget.store.planningDraft = savedDraft;
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (widget.store.storageError != null) {
      await showFailure(widget.store.storageError!);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ready = draft != null && (draft!['sessions'] as List).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Kế hoạch học và luyện tập')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: FilledButton.icon(
            onPressed: busy || (draft != null && !ready)
                ? null
                : ready
                ? accept
                : generate,
            icon: Icon(
              ready ? Icons.check_rounded : Icons.auto_awesome_outlined,
            ),
            label: Text(
              busy
                  ? 'Đang xử lý…'
                  : ready
                  ? 'Xác nhận thêm vào lịch'
                  : draft != null
                  ? 'Không còn buổi để thêm'
                  : 'Tạo kế hoạch để xem trước',
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageIntro(
                'Bạn muốn học điều gì?',
                'Chọn một mục tiêu. Octopus chia thành các buổi vừa với thời gian của bạn.',
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('planner-goal'),
                controller: request,
                focusNode: goalFocus,
                enabled: !busy,
                onChanged: (_) => setState(invalidateDraft),
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Bạn muốn đạt điều gì?',
                  hintText:
                      'Ví dụ, luyện nói tiếng Anh để tự tin khi đi du lịch.',
                  alignLabelWithHint: true,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          request.text =
                              'Tôi muốn học 20 câu tiếng Anh để hỏi đường và gọi món khi đi du lịch.';
                          invalidateDraft();
                        }),
                  child: const Text('Dùng ví dụ học tiếng Anh'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : chooseDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        targetDate == null
                            ? 'Hạn hoàn thành (tùy chọn)'
                            : 'Trước ${dateText(targetDate!)}/${targetDate!.year}',
                      ),
                    ),
                  ),
                  if (targetDate != null)
                    IconButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              targetDate = null;
                              invalidateDraft();
                            }),
                      tooltip: 'Bỏ hạn hoàn thành',
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Có thể ghi ngày trong mục tiêu hoặc chọn ở trên. Nếu chưa có hạn, Octopus lên kế hoạch cho 7 ngày tới.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('planner-context'),
                controller: contextInput,
                enabled: !busy,
                onChanged: (_) => setState(invalidateDraft),
                minLines: 2,
                maxLines: 5,
                maxLength: 6000,
                decoration: const InputDecoration(
                  labelText: 'Bạn đã biết gì, muốn tập thêm gì? (tùy chọn)',
                  hintText:
                      'Ví dụ, tôi biết từ vựng cơ bản nhưng còn ngại nói. Tôi thích luyện qua hội thoại ngắn.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                color: const Color(0xffeef1ff),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khung học ${minuteText(widget.store.studyPreferences['startMinute'])}–${minuteText(widget.store.studyPreferences['endMinute'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${widget.store.studyPreferences['dailyMinutes']} phút mỗi ngày · ${widget.store.commitments.length} lịch bận đã lưu',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kế hoạch tránh các lịch bận đã lưu và hỗ trợ xếp giờ trong 7 ngày tới.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Panel(
                color: const Color(0xffeaf1ff),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Starter · 5 lượt lập kế hoạch mỗi tháng',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quotaLoading
                          ? 'Đang kiểm tra lượt còn lại…'
                          : quotaError ??
                                (widget.store.aiQuota['remaining'] == null
                                    ? 'Không cần nhập mã để bắt đầu.'
                                    : 'Còn ${widget.store.aiQuota['remaining']}/5 lượt trong tháng ${widget.store.aiQuota['period']}.'),
                    ),
                    const Text(
                      'Chỉ tính lượt khi có kế hoạch để xem trước. Mở lại bản nháp và xác nhận lịch không tốn thêm lượt.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const Text(
                      'Lượt Starter gắn với bản cài trên thiết bị này.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    if (quotaError != null)
                      TextButton(
                        onPressed: loadQuota,
                        child: const Text('Kiểm tra lại'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (api.needsAccessCode) ...[
                TextField(
                  key: const Key('planner-code'),
                  controller: accessCode,
                  focusNode: codeFocus,
                  enabled: !busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Mã thử AI của nhóm',
                    helperText: 'Nhập mã dùng thử do nhóm Octopus cung cấp.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Khi tạo kế hoạch, mục tiêu, thông tin học, khung giờ và lịch bận được gửi tới dịch vụ AI qua PoolAI. Hồ sơ cá nhân, ảnh và nhật ký được giữ trên điện thoại.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (draft != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Kế hoạch đề xuất · ${(draft!['sessions'] as List).length} buổi',
                  key: resultKey,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (draft!['sessions'] as List).length < initialSessionCount
                      ? 'Bạn đang giữ ${(draft!['sessions'] as List).length} trong $initialSessionCount buổi đề xuất. Chỉ các buổi còn lại được thêm khi xác nhận.'
                      : draft!['summary'] ?? '',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bản nháp được lưu trên máy. Bạn có thể quay lại Lịch trình rồi mở tiếp, không cần gọi AI lần nữa.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: busy ? null : discardDraft,
                    child: const Text('Bỏ bản nháp'),
                  ),
                ),
                for (final a in draft!['assumptions'])
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      a,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                const SizedBox(height: 14),
                for (final p in draft!['sessions'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SessionCard(
                      key: ValueKey(p['slotId']),
                      session: Map<String, dynamic>.from(p),
                      trailing: TextButton(
                        onPressed: busy ? null : () => removeDraftSession(p),
                        child: const Text('Bỏ phiên này'),
                      ),
                    ),
                  ),
                const Text(
                  'Bạn có thể bỏ buổi chưa phù hợp. Kiểm tra nội dung và khung giờ trước khi xác nhận.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannerFeedbackDialog extends StatefulWidget {
  const _PlannerFeedbackDialog({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_PlannerFeedbackDialog> createState() => _PlannerFeedbackDialogState();
}

class _PlannerFeedbackDialogState extends State<_PlannerFeedbackDialog> {
  final answer = TextEditingController();
  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outside = widget.data['reason'] == 'out_of_scope';
    return AlertDialog(
      icon: Icon(
        outside ? Icons.lightbulb_outline : Icons.chat_bubble_outline,
        color: blue,
      ),
      title: Text(
        outside ? 'Chuyển ý tưởng thành mục tiêu học' : 'Bổ sung thông tin',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.data['summary'] ?? 'Hãy mô tả thêm điều bạn muốn học.'),
            for (final q in widget.data['questions']) ...[
              const SizedBox(height: 12),
              Text(q),
            ],
            if (!outside) ...[
              const SizedBox(height: 16),
              TextField(
                controller: answer,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Thông tin bổ sung',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chỉnh mục tiêu'),
        ),
        if (!outside)
          FilledButton(
            onPressed: () => Navigator.pop(context, answer.text.trim()),
            child: const Text('Bổ sung và thử lại'),
          ),
      ],
    );
  }
}

class _PlanningProgressDialog extends StatefulWidget {
  const _PlanningProgressDialog({required this.onCancel});
  final VoidCallback onCancel;
  @override
  State<_PlanningProgressDialog> createState() =>
      _PlanningProgressDialogState();
}

class _PlanningProgressDialogState extends State<_PlanningProgressDialog> {
  Timer? timer;
  int seconds = 0;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đang tạo kế hoạch'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          seconds < 30
              ? 'AI đang đọc mục tiêu và xếp các buổi phù hợp với lịch của bạn.'
              : 'Dịch vụ đang phản hồi chậm. Lần truy cập đầu có thể cần khoảng một phút để khởi động.',
        ),
        const SizedBox(height: 10),
        Text(
          'Đã chờ $seconds giây',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: widget.onCancel, child: const Text('Hủy yêu cầu')),
    ],
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
