import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'flow_design.dart';
import 'plans_screen.dart';
import 'main.dart' show HomeShell, Panel, blue, muted;

class AppEntry extends StatelessWidget {
  const AppEntry({super.key, required this.store});
  final BrainStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) => store.onboardingComplete
        ? HomeShell(store: store)
        : OnboardingScreen(store: store),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store});
  final BrainStore store;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final name = TextEditingController();
  DateTime? birthday;
  int step = 0;
  String? error;
  bool busy = false;
  String goal = 'Học tập & kỳ thi';
  @override
  void initState() {
    super.initState();
    name.text = widget.store.profile['name'] ?? '';
    birthday = DateTime.tryParse(widget.store.profile['birthday'] ?? '');
    goal = widget.store.profile['primaryGoal'] ?? 'Học tập & kỳ thi';
    if (name.text.isNotEmpty && birthday != null) step = 1;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> next() async {
    final invalid = profileError(name.text, birthday, DateTime.now());
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    widget.store.profile.addAll({
      'name': name.text.trim(),
      'birthday': dayKey(birthday!),
      'primaryGoal': goal,
    });
    await widget.store.save();
    if (!mounted) return;
    setState(() {
      busy = false;
      if (widget.store.storageError == null) {
        step = 1;
      } else {
        error = widget.store.storageError;
      }
    });
  }

  Future<void> startAsGuest() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    widget.store.profile['authMode'] = 'guest';
    await widget.store.save();
    if (!mounted) return;
    setState(() {
      busy = false;
      error = widget.store.storageError;
    });
    if (error != null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WidgetSetupScreen(store: widget.store, onboarding: true),
      ),
    );
  }

  void signIn(String provider) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Đăng nhập bằng $provider'),
      content: const Text(
        'Bản này hỗ trợ dùng không đăng nhập. Bạn có thể bắt đầu ngay và lưu dữ liệu trên điện thoại.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          Row(
            children: [
              const OctopusLogo(size: 40),
              const SizedBox(width: 10),
              const Text(
                'Octopus',
                style: TextStyle(
                  color: blue,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              FlowTag('Bước ${step + 1} / 3', icon: Icons.more_horiz),
            ],
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: flowTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                step == 0
                    ? Icons.waving_hand_outlined
                    : Icons.lock_outline_rounded,
                color: blue,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            step == 0 ? 'Bắt đầu từ bạn.' : 'Chọn cách bắt đầu.',
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -.9,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            step == 0
                ? 'Một nhịp ngày của riêng mình.'
                : 'Tiến bộ, theo cách của bạn.',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: blue,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step == 0
                ? 'Không cần tài khoản để bắt đầu. Cho Octopus biết bạn là ai và điều bạn muốn dành thời gian.'
                : 'Bạn có thể dùng Octopus ngay trên thiết bị này.',
            style: const TextStyle(fontSize: 12, color: muted, height: 1.6),
          ),
          const SizedBox(height: 24),
          if (step == 0) ...[
            const Text(
              'Họ và tên',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            TextField(
              key: const Key('profile-name'),
              controller: name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: 100,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Nguyễn An',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('profile-birthday'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.centerLeft,
                  backgroundColor: flowCanvas,
                  side: const BorderSide(color: flowLine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.cake_outlined, size: 18),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: birthday ?? DateTime(now.year - 20, 1, 1),
                    firstDate: DateTime(1900),
                    lastDate: now,
                    helpText: 'Ngày sinh của bạn',
                    initialEntryMode: DatePickerEntryMode.input,
                  );
                  if (picked != null && mounted) {
                    setState(() => birthday = picked);
                  }
                },
                label: Text(
                  birthday == null
                      ? 'Chọn ngày sinh'
                      : '${birthday!.day}/${birthday!.month}/${birthday!.year}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Bạn muốn tập trung vào điều gì?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 0,
              children: [
                for (final g in [
                  'Học tập & kỳ thi',
                  'Làm việc sâu',
                  'Xây thói quen',
                ])
                  ChoiceChip(
                    label: Text(g),
                    selected: goal == g,
                    showCheckmark: false,
                    selectedColor: blue,
                    backgroundColor: flowCanvas,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: goal == g ? Colors.white : flowInk,
                    ),
                    onSelected: (_) => setState(() => goal = g),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lưu trên điện thoại. Họ tên và ngày sinh không được gửi sang AI để lập lịch.',
                    style: TextStyle(fontSize: 10, color: muted, height: 1.6),
                  ),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : next,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(busy ? 'Đang lưu…' : 'Tiếp tục'),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ] else ...[
            FlowCard(
              color: flowCanvas,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FlowTag('BẮT ĐẦU NGAY', icon: Icons.bolt_rounded),
                  const SizedBox(height: 15),
                  const Text(
                    'Một thiết bị. Một nhịp riêng.',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Công việc, lịch và những lần tiến bộ được giữ trên máy này. Chưa đồng bộ giữa các thiết bị.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : startAsGuest,
                      child: Text(busy ? 'Đang lưu…' : 'Dùng không đăng nhập'),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'HOẶC LIÊN KẾT TÀI KHOẢN',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  color: muted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final (provider, logo) in [
              (
                'Google',
                Image.asset('assets/google_g.png', width: 20, height: 20),
              ),
              (
                'Facebook',
                const Icon(Icons.facebook, color: Color(0xFF0866FF), size: 20),
              ),
              (
                'Số điện thoại',
                const Icon(Icons.phone_iphone_rounded, size: 20),
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => signIn(provider),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: flowLine),
                  ),
                  icon: ExcludeSemantics(child: logo),
                  label: Text(provider, style: const TextStyle(fontSize: 12)),
                ),
              ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      error = null;
                      step = 0;
                    }),
              child: const Text('Sửa thông tin cá nhân'),
            ),
          ],
        ],
      ),
    ),
  );
}

class WidgetSetupScreen extends StatefulWidget {
  const WidgetSetupScreen({
    super.key,
    required this.store,
    this.onboarding = false,
  });
  final BrainStore store;
  final bool onboarding;
  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.store});
  final BrainStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ của bạn')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          store.profile['name'] ?? '',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text('Ngày sinh: ${store.profile['birthday'] ?? ''}'),
        const SizedBox(height: 8),
        const Text(
          'Đang dùng không đăng nhập · dữ liệu trên thiết bị này',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const PlansScreen()),
          ),
          icon: const Icon(Icons.workspace_premium_outlined),
          label: const Text('Gói Octopus'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => WidgetSetupScreen(store: store)),
          ),
          icon: const Icon(Icons.widgets_outlined),
          label: const Text('Quản lý widget màn hình chính'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Google, Facebook và số điện thoại sẽ được kết nối sau khi cấu hình dịch vụ đăng nhập. Chế độ khách hiện không đồng bộ dữ liệu.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        const FlowTag('Octopus · 0.6.8'),
      ],
    ),
  );
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> status = {};
  String? statusError;
  String? saveError;
  bool saving = false;

  static const manualInstructions =
      'Để thêm thủ công, nhấn giữ chỗ trống trên màn hình chính, chọn Widget, tìm Octopus rồi kéo widget vào chỗ trống.';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      final value = await widget.store.device.widgetStatus();
      if (mounted) {
        setState(() {
          status = value;
          statusError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => statusError = 'Chưa đọc được trạng thái widget. Hãy thử lại.',
        );
      }
    }
  }

  Future<void> pin(String kind) async {
    var sent = false;
    try {
      sent = await widget.store.device.pinWidget(kind);
    } catch (_) {} // Some launchers decline requests from the app.
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Xác nhận Thêm nếu Android hiện hộp thoại. Nếu không thấy, hãy thêm thủ công.'
              : manualInstructions,
        ),
      ),
    );
  }

  Future<void> complete() async {
    if (saving) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    await widget.store.save(finishOnboarding: true);
    if (!mounted) return;
    if (widget.store.storageError != null) {
      setState(() {
        saveError = widget.store.storageError;
        saving = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đưa Octopus ra màn hình chính')),
    bottomNavigationBar: widget.onboarding
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (saveError != null)
                    Text(saveError!, style: const TextStyle(color: Colors.red)),
                  FilledButton(
                    onPressed: saving ? null : complete,
                    child: Text(saving ? 'Đang lưu…' : 'Bắt đầu dùng Octopus'),
                  ),
                ],
              ),
            ),
          )
        : null,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.onboarding)
            const Text(
              'BƯỚC 3 / 3',
              style: TextStyle(color: muted, letterSpacing: 2, fontSize: 11),
            ),
          const SizedBox(height: 14),
          const Text(
            'Điều quan trọng,\nngay trước mắt.',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (widget.onboarding) ...[
            const Text(
              'Bạn có thể vào app ngay và thêm widget sau trong Hồ sơ.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 8),
          ],
          const Text(manualInstructions, style: TextStyle(color: muted)),
          const SizedBox(height: 24),
          for (final item in [
            (
              'tasks',
              Icons.checklist_rounded,
              'Nhịp hôm nay (4×2)',
              'Phiên đang chạy, đếm ngược trực tiếp, check-out một chạm và việc tiếp theo.',
            ),
            (
              'focus',
              Icons.center_focus_strong,
              'Ghi nhanh (2×2)',
              'Nhập hoặc nói một việc; bắt đầu Focus 30 phút. Lần đầu sẽ giải thích quyền bảo vệ.',
            ),
          ]) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$2, color: blue, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    item.$3,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(item.$4, style: const TextStyle(color: muted)),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: status[item.$1] == true || saving
                        ? null
                        : () => pin(item.$1),
                    icon: Icon(
                      status[item.$1] == true ? Icons.check_circle : Icons.add,
                    ),
                    label: Text(
                      status[item.$1] == true
                          ? 'Đã có trên màn hình'
                          : 'Thêm widget ${item.$3.toLowerCase()}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (statusError != null)
            Text(statusError!, style: const TextStyle(color: muted)),
          TextButton.icon(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Kiểm tra widget đã thêm'),
          ),
        ],
      ),
    ),
  );
}
