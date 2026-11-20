import 'activity_history.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'brain_store.dart';
import 'onboarding.dart';
import 'schedule_screen.dart';
import 'protection_screen.dart';
import 'usage_screen.dart';
import 'today_screen.dart';
import 'task_checkout.dart';
import 'circles_screen.dart';
import 'flow_design.dart';
import 'wellbeing_card.dart';
import 'time_picker.dart';

const blue = flowBlue,
    ink = flowInk,
    muted = flowMuted,
    background = flowCanvas;
String clockText(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String dateText(DateTime d) => '${d.day}/${d.month}';
String stamp(DateTime d) => '${dateText(d)} · ${clockText(d)}';
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = BrainStore();
  await store.load();
  runApp(OctopusApp(store: store));
}

class OctopusApp extends StatelessWidget {
  const OctopusApp({super.key, required this.store});
  final BrainStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Octopus',
    debugShowCheckedModeBanner: false,
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        primary: blue,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, height: 1.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff4f4ff),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xfff3f4ff),
        selectedColor: const Color(0xffe1eaff),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    ),
    home: AppEntry(store: store),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final BrainStore store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  int taskDay = 0;
  bool handlingAction = false;
  String displayedDay = dayKey(DateTime.now());
  Timer? timer;
  BrainStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => widgetAction());
  }

  void tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final day = dayKey(now);
    final dayChanged = day != displayedDay;
    displayedDay = day;
    final end = store.focusEnd;
    if (end != null && !now.isBefore(end)) {
      unawaited(store.finishFocus());
    } else if (dayChanged || (tab == 2 && end != null)) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      tick();
      widgetAction();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> widgetAction() async {
    if (handlingAction) return;
    handlingAction = true;
    try {
      final action = await store.device.takeWidgetAction();
      if (!mounted || action == null) return;
      if (action == 'add_task') {
        final date = store.quickTaskDate();
        setState(() {
          tab = 0;
          taskDay = dayKey(date) == dayKey(DateTime.now()) ? 0 : 1;
        });
        addTask(date: date);
      } else if (action == 'voice_task') {
        setState(() => tab = 0);
        await voiceTask();
      } else if (action.startsWith('complete:')) {
        setState(() => tab = 0);
        final item = store.workById(action.substring(9));
        if (item != null && item['done'] != true) {
          await checkOutTask(context, store, item, completedFromWidget: true);
        }
      } else if (action == 'wellbeing') {
        setState(() => tab = 2);
        await showWellbeingReminder(context);
      } else if (action == 'usage') {
        setState(() => tab = 3);
      } else if (action == 'focus' || action == 'start_focus') {
        setState(() => tab = 2);
        if (action == 'start_focus') {
          if (store.focusEnd != null &&
              !store.focusEnd!.isAfter(DateTime.now())) {
            await store.finishFocus();
          }
          if (!mounted || !await ensureFocusProtection(context, store)) return;
          await store.startFocus(30);
        }
      } else {
        setState(() {
          tab = 0;
          if (action == 'tasks') taskDay = 0;
        });
      }
    } catch (_) {
      /* Non-Android widget previews have no platform channel. */
    } finally {
      handlingAction = false;
    }
  }

  void activity() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: background,
    builder: (_) => ActivityEditor(store: store),
  );
  void addTask({DateTime? date, String initialText = ''}) async {
    final selected = date ?? DateTime.now();
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => WorkEntryDialog(
        title: 'Việc ngày ${dateText(selected)}',
        initialText: initialText,
        label: 'Bạn muốn làm gì?',
        confirmLabel: 'Thêm việc',
        withDuration: true,
      ),
    );
    if (draft == null || !mounted) return;
    await store.addTask(draft['title'], draft['minutes'], selected);
  }

  void about() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Octopus · Android 0.6.8'),
      content: const Text(
        'App cài trên điện thoại, giao diện Flutter và kết nối API Android bằng Kotlin.\n\nCông việc, hoạt động, ảnh và lựa chọn lưu trên thiết bị này. Chưa đồng bộ hoặc gửi cho người khác.\n\nScreen time đọc sự kiện sử dụng Android. Focus dùng Trợ năng để chặn app và VPN cục bộ để chặn mạng khi đã cấp quyền. Nhóm và check-in lưu cục bộ; chưa đồng bộ bạn bè. Starter có 5 lượt lập kế hoạch AI mỗi tháng trên bản cài này; không cần nhập mã. Đăng nhập chưa kết nối.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 58,
        titleSpacing: 0,
        leadingWidth: 66,
        leading: IconButton(
          tooltip: 'Hồ sơ và widget',
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => ProfileScreen(store: store)),
          ),
          icon: const OctopusLogo(size: 38),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'octopus',
              style: TextStyle(
                color: blue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
            Text(
              [
                'Nhịp hôm nay',
                'Thời gian của bạn',
                'Khoảng tập trung',
                'Nhìn lại một tuần',
                'Vòng tròn của bạn',
              ][tab],
              style: const TextStyle(
                fontSize: 10,
                color: muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        shape: const Border(bottom: BorderSide(color: flowLine)),
        actions: [
          IconButton(
            onPressed: about,
            icon: const Icon(Icons.info_outline),
            tooltip: 'Thông tin bản thử',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (store.storageError != null)
              MaterialBanner(
                content: Text(store.storageError!),
                actions: [
                  TextButton(
                    onPressed: () => store.save(),
                    child: const Text('Thử lưu lại'),
                  ),
                ],
              ),
            Expanded(
              child: switch (tab) {
                0 => today(),
                1 => ScheduleScreen(store: store),
                2 => FocusPanel(store: store),
                3 => UsagePanel(store: store),
                _ => groups(),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xffe8efff),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            color: states.contains(WidgetState.selected) ? blue : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Lịch trình',
          ),
          NavigationDestination(
            icon: Icon(Icons.center_focus_strong),
            label: 'Tập trung',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Nhóm',
          ),
        ],
      ),
    ),
  );
  Widget today() => TodayScreen(
    store: store,
    day: taskDay,
    changeDay: (v) => setState(() => taskDay = v),
    addTask: () => addTask(
      date: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + taskDay,
      ),
    ),
    activity: activity,
    voice: voiceTask,
    activityCard: activityCard,
  );

  Future<void> voiceTask() async {
    if (store.profile['voiceDisclosureAccepted'] != true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Thêm việc bằng giọng nói'),
          content: const Text(
            'Octopus mở dịch vụ nhận giọng nói của Android rồi nhận lại văn bản để bạn sửa trước khi lưu. Dịch vụ do bạn chọn có thể xử lý âm thanh qua mạng theo chính sách của họ. Octopus không ghi âm nền hoặc lưu bản ghi âm.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      store.profile['voiceDisclosureAccepted'] = true;
      await store.save();
    }
    try {
      final text = await store.device.recognizeSpeech();
      if (!mounted || text == null || text.trim().isEmpty) return;
      addTask(date: store.quickTaskDate(), initialText: text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Máy chưa có dịch vụ nhận giọng nói. Bạn có thể nhập bằng bàn phím.',
          ),
        ),
      );
      addTask(date: store.quickTaskDate());
    }
  }

  Widget activityCard(Map<String, dynamic> entry) =>
      ActivityRecordCard(store: store, entry: entry);
  Widget groups() => CirclesScreen(store: store);
}

/// Own controllers until the dialog widget is removed, including its exit animation.
class WorkEntryDialog extends StatefulWidget {
  const WorkEntryDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.withDuration = false,
    this.initialText = '',
  });
  final String title, label, confirmLabel;
  final bool withDuration;
  final String initialText;
  @override
  State<WorkEntryDialog> createState() => _WorkEntryDialogState();
}

class _WorkEntryDialogState extends State<WorkEntryDialog> {
  final title = TextEditingController(),
      minutes = TextEditingController(text: '30');
  String? error;
  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    title.text = widget.initialText;
  }

  void submit() {
    final text = title.text.trim(), duration = int.tryParse(minutes.text) ?? 0;
    final problem = text.isEmpty
        ? 'Nhập điều bạn muốn hoàn thành.'
        : widget.withDuration
        ? focusError(duration)
        : null;
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'title': text,
      'minutes': duration,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(labelText: widget.label),
          ),
          if (widget.withDuration) ...[
            const SizedBox(height: 12),
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thời lượng (phút)'),
            ),
          ],
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Để sau'),
      ),
      FilledButton(onPressed: submit, child: Text(widget.confirmLabel)),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffe7ecf4)),
    ),
    child: child,
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xffedf3ff),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        color: blue,
        fontWeight: FontWeight.w600,
        letterSpacing: .2,
      ),
    ),
  );
}

class PageIntro extends StatelessWidget {
  const PageIntro(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 11),
      Text(
        subtitle,
        style: const TextStyle(color: muted, fontSize: 13, height: 1.7),
      ),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Icon(icon, size: 37, color: blue),
        const SizedBox(height: 15),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 13, height: 1.7),
        ),
      ],
    ),
  );
}

class ActivityEditor extends StatefulWidget {
  const ActivityEditor({super.key, required this.store, this.existing});
  final BrainStore store;
  final Map<String, dynamic>? existing;
  @override
  State<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<ActivityEditor> {
  final title = TextEditingController(), note = TextEditingController();
  DateTime start = DateTime.now().subtract(const Duration(minutes: 45)),
      end = DateTime.now().subtract(const Duration(minutes: 15));
  String audience = 'private';
  String? photo, error;
  Set<String> recipients = {};
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final entry = widget.existing;
    if (entry == null) return;
    title.text = entry['title'] ?? '';
    note.text = entry['note'] ?? '';
    start = DateTime.tryParse(entry['start'] ?? '')?.toLocal() ?? start;
    end = DateTime.tryParse(entry['end'] ?? '')?.toLocal() ?? end;
    audience = entry['audience'] ?? 'private';
    recipients = Set<String>.from(entry['recipients'] ?? []);
    photo = entry['image'];
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pickTime(bool first) async {
    final now = DateTime.now(), value = first ? start : end;
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: widget.existing == null
          ? now.subtract(const Duration(days: 1))
          : DateTime(1900),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await pickAppTime(context, TimeOfDay.fromDateTime(value));
    if (time == null || !mounted) return;
    setState(() {
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (first) {
        start = selected;
      } else {
        end = selected;
      }
    });
  }

  Future<void> pickImage() async {
    setState(() => busy = true);
    try {
      final path = await widget.store.device.pickImage();
      if (mounted) setState(() => photo = path ?? photo);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Không đọc được ảnh. Chọn ảnh nhỏ hơn 8 MB.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final invalid = title.text.trim().isEmpty
        ? 'Nhập tên hoạt động.'
        : widget.existing == null
        ? activityError(start, end, DateTime.now())
        : !end.isAfter(start) || end.isAfter(DateTime.now())
        ? 'Giờ kết thúc cần sau giờ bắt đầu và không ở tương lai.'
        : end.difference(start) > const Duration(days: 1)
        ? 'Một hoạt động cần dài tối đa 24 giờ.'
        : null;
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    if (audience == 'selected' && recipients.isEmpty) {
      setState(() => error = 'Chọn ít nhất một người được xem.');
      return;
    }
    setState(() => busy = true);
    final value = {
      'title': title.text.trim(),
      'note': note.text.trim(),
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'audience': audience,
      'recipients': audience == 'selected' ? recipients.toList() : <String>[],
      'image': photo,
    };
    bool saved;
    if (widget.existing != null) {
      saved = await widget.store.updateRecord(
        widget.store.activities,
        widget.existing!['id'],
        value,
      );
    } else {
      final entry = {'id': newId(), ...value};
      widget.store.activities.add(entry);
      await widget.store.save();
      saved = widget.store.storageError == null;
      if (!saved) {
        widget.store.activities.remove(entry);
        widget.store.refreshViews();
      }
    }
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      busy = false;
      error =
          widget.store.storageError ?? 'Hoạt động này không còn trong nhật ký.';
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 25, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.existing == null
                      ? 'Ghi một điều đã làm'
                      : 'Sửa hoạt động',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            widget.existing == null
                ? 'Không cần bấm giờ từ đầu. Ghi lại trong vòng 24 giờ.'
                : 'Có thể sửa ghi chép cũ; giờ kết thúc không ở tương lai.',
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: title,
            enabled: !busy,
            maxLength: 140,
            decoration: const InputDecoration(
              labelText: 'Tên hoạt động',
              hintText: 'Chạy bộ quanh công viên',
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bắt đầu'),
            subtitle: Text(stamp(start)),
            trailing: const Icon(Icons.schedule),
            onTap: busy ? null : () => pickTime(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kết thúc'),
            subtitle: Text(stamp(end)),
            trailing: const Icon(Icons.schedule),
            onTap: busy ? null : () => pickTime(false),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              photo == null ? 'Thêm ảnh / screenshot Strava' : 'Đổi ảnh',
            ),
          ),
          if (photo != null)
            TextButton(
              onPressed: busy ? null : () => setState(() => photo = null),
              child: const Text('Bỏ ảnh'),
            ),
          if (photo != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.file(
                File(photo!),
                height: 140,
                cacheWidth: 800,
                errorBuilder: (_, _, _) =>
                    const Text('Không hiển thị được ảnh.'),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            enabled: !busy,
            controller: note,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Một điều muốn ghi nhớ (tùy chọn)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: audience,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ai có thể xem?'),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('Chỉ mình tôi')),
              DropdownMenuItem(
                value: 'group',
                child: Text('Toàn bộ nhóm · mô phỏng'),
              ),
              DropdownMenuItem(
                value: 'selected',
                child: Text('Chọn người · mô phỏng'),
              ),
            ],
            onChanged: (v) => setState(() => audience = v!),
          ),
          if (audience == 'selected')
            Wrap(
              spacing: 8,
              children: ['Minh Anh', 'Hoàng Nam', 'Thanh Hà']
                  .map(
                    (name) => FilterChip(
                      label: Text(name),
                      selected: recipients.contains(name),
                      onSelected: (v) => setState(() {
                        v ? recipients.add(name) : recipients.remove(name);
                      }),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          const Text(
            'Tự ghi nhận · lưu trên thiết bị, chưa chia sẻ cho người khác.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.check),
              label: Text(busy ? 'Đang xử lý…' : 'Lưu hoạt động'),
            ),
          ),
        ],
      ),
    ),
  );
}

class FocusPanel extends StatefulWidget {
  const FocusPanel({super.key, required this.store});
  final BrainStore store;
  @override
  State<FocusPanel> createState() => _FocusPanelState();
}

class _FocusPanelState extends State<FocusPanel> {
  final duration = TextEditingController(text: '30');
  String? error;
  bool busy = false;
  @override
  void dispose() {
    duration.dispose();
    super.dispose();
  }

  Future<void> startFocus({required bool protected}) async {
    final minutes = int.tryParse(duration.text) ?? 0;
    final invalid = focusError(minutes);
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final store = widget.store;
    try {
      if (protected && !await ensureFocusProtection(context, store)) return;
      if (!mounted) return;
      await prepareWellbeingReminders(context, store, minutes);
      if (!mounted) return;
      await store.startFocus(minutes, protected: protected);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> stopFocus() async {
    final store = widget.store;
    setState(() => busy = true);
    try {
      if (store.focusProtected) {
        final reason = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => const WorkEntryDialog(
            title: 'Kết thúc sớm',
            label: 'Lý do cần dừng phiên',
            confirmLabel: 'Ghi nhận và kết thúc',
          ),
        );
        if (reason == null || store.focusEnd == null) return;
        await store.device.cancelFocus(reason['title'] as String);
      }
      await store.finishFocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa kết nối được bộ bảo vệ. Hãy thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store, now = DateTime.now();
    final active = store.focusEnd != null;
    final seconds = active
        ? store.focusEnd!.difference(now).inSeconds.clamp(0, 28800)
        : (int.tryParse(duration.text) ?? 30).clamp(0, 480) * 60;
    final timer =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const PageIntro(
          'Trở về với một việc.',
          'Dành một khoảng thời gian cho điều bạn đã chọn.',
        ),
        const SizedBox(height: 20),
        GuardStatusCard(store: store),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xff14264b),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text(
                'MỘT KHOẢNG DÀNH RIÊNG CHO BẠN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffb0c6e9),
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xff34517e), width: 4),
                ),
                alignment: Alignment.center,
                child: Text(
                  timer,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 49,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffeaf1ff),
                  foregroundColor: blue,
                ),
                onPressed: busy
                    ? null
                    : active
                    ? stopFocus
                    : () => startFocus(protected: true),
                icon: Icon(active ? Icons.stop_rounded : Icons.play_arrow),
                label: Text(active ? 'Kết thúc phiên' : 'Bắt đầu phiên'),
              ),
              if (!active)
                TextButton.icon(
                  onPressed: busy ? null : () => startFocus(protected: false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffeaf1ff),
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Chỉ đếm giờ'),
                ),
              const SizedBox(height: 14),
              Text(
                active
                    ? store.focusProtected
                          ? 'Phiên có bảo vệ'
                          : 'Đang đếm giờ'
                    : 'Bắt đầu phiên có bảo vệ cần quyền Android. Chỉ đếm giờ dùng được ngay.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xffa0b7dc)),
              ),
              if (error != null && !active) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Color(0xffffb4ab))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        WellbeingCard(store: store),
        const SizedBox(height: 22),
        if (!active)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khoảng tập trung của bạn',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng (phút)',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  children: [25, 30, 60, 90]
                      .map(
                        (n) => ChoiceChip(
                          label: Text('$n phút'),
                          selected: duration.text == '$n',
                          onSelected: (_) =>
                              setState(() => duration.text = '$n'),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tối đa 8 giờ. Lịch đã xác nhận được theo dõi ở nền khi bật bảo vệ. Chặn mạng chỉ áp dụng cho phiên tập trung sâu.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Text(
          '${store.focusMinutes} phút đã ghi nhận từ các phiên kết thúc.',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}
