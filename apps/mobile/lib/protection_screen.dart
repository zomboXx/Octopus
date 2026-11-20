import 'dart:async';
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'main.dart' show Panel, PageIntro, blue, muted;
import 'app_icon.dart';
import 'usage_screen.dart'
    show restrictionSuggestion, RestrictionSuggestionCard, rows, usageDuration;

String guardSummary(BrainStore store, Map<String, dynamic> status) {
  if (status['accessibility'] != true) {
    return status['accessibilityEnabled'] == true
        ? 'Dịch vụ Trợ năng đang ngắt'
        : 'Chưa kết nối Trợ năng';
  }
  if (store.protection['enabled'] != true) return 'Bảo vệ đang tắt';
  if (status['paused'] == true) return 'Bảo vệ đang tạm dừng';
  if ((status['activeTitle'] as String? ?? '').isNotEmpty) {
    return 'Đang bảo vệ tập trung';
  }
  return 'Đã bật · chờ lịch hoặc phiên tập trung';
}

Future<bool> ensureFocusProtection(
  BuildContext context,
  BrainStore store,
) async {
  if (store.protection['disclosureAccepted'] != true) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.shield_outlined, color: blue, size: 36),
        title: const Text('Bạn cấp quyền. Bạn giữ quyền kiểm soát.'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trước phiên đầu tiên',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                '• Trợ năng: nhận biết tên ứng dụng đang mở và hiện màn hình chặn khi cần. Không đọc nội dung màn hình, tin nhắn hay mật khẩu.',
              ),
              SizedBox(height: 12),
              Text(
                '• VPN cục bộ: ngăn kết nối Internet trong phiên sâu. Không chuyển lưu lượng tới máy chủ; tự trả lại kết nối khi kết thúc. Có thể thay thế VPN bạn đang dùng.',
              ),
              SizedBox(height: 12),
              Text(
                '• Thông báo (tùy chọn): hiện trạng thái bảo vệ và nhắc nghỉ nhẹ, uống nước sau mỗi 40 phút trong phiên dài.',
              ),
              SizedBox(height: 12),
              Text(
                'Quyền truy cập sử dụng chỉ dành cho biểu đồ Thống kê, không bắt buộc để bắt đầu phiên.',
              ),
              SizedBox(height: 16),
              Text(
                'Cam kết: Octopus không đánh cắp, bán hay bí mật gửi dữ liệu của bạn. Dữ liệu bảo vệ ở trên máy, không gửi sang AI. Bạn có thể tắt bảo vệ và thu hồi quyền trong Cài đặt Android.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Đã hiểu · thiết lập quyền'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return false;
    store.protection['disclosureAccepted'] = true;
    await store.save();
    if (!context.mounted) return false;
  }
  try {
    final status = await store.device.guardStatus();
    if (store.protection['enabled'] == true &&
        status['accessibility'] == true &&
        (store.protection['blockInternet'] != true ||
            status['vpnPrepared'] == true)) {
      await store.device.resumeProtection();
      return true;
    }
    if (!context.mounted) return false;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ProtectionScreen(store: store)),
    );
    final updated = await store.device.guardStatus();
    if (store.protection['enabled'] == true &&
        updated['accessibility'] == true &&
        (store.protection['blockInternet'] != true ||
            updated['vpnPrepared'] == true)) {
      await store.device.resumeProtection();
      return true;
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa kết nối được bộ bảo vệ Android. Hãy thử lại.'),
        ),
      );
    }
  }
  return false;
}

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key, required this.store});
  final BrainStore store;
  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> status = {};
  List<Map<String, dynamic>> apps = [];
  List<Map<String, dynamic>> usageApps = [], usageDays = [];
  Timer? statusTimer;
  int refreshId = 0;
  String query = '';
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshStatus(),
    );
  }

  @override
  void dispose() {
    refreshId++;
    statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final run = ++refreshId;
    try {
      final data = await widget.store.device.guardStatus();
      if (!mounted || run != refreshId) return;
      setState(() => status = data);
      final installed = await widget.store.device.installedApps();
      Map<String, dynamic> usage = {};
      try {
        usage = await widget.store.device.usage();
      } catch (_) {}
      final recentApps = rows(usage['apps']);
      final times = {
        for (final app in recentApps) app['package']: app['milliseconds'],
      };
      final ordered = installed
          .map((app) => {...app, 'milliseconds': times[app['package']] ?? 0})
          .toList();
      ordered.sort((a, b) {
        final byTime = (b['milliseconds'] as num).compareTo(
          a['milliseconds'] as num,
        );
        return byTime != 0
            ? byTime
            : (a['name'] as String).compareTo(b['name'] as String);
      });
      if (mounted && run == refreshId) {
        setState(() {
          apps = ordered;
          usageApps = recentApps;
          usageDays = rows(usage['days']);
          error = null;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && run == refreshId) {
        setState(() {
          error = 'Chưa đọc được quyền Android. Thử kiểm tra lại.';
          loading = false;
        });
      }
    }
  }

  Future<void> refreshStatus() async {
    try {
      final data = await widget.store.device.guardStatus();
      if (mounted) setState(() => status = data);
    } catch (_) {
      if (mounted) setState(() => status = {});
    }
  }

  Future<void> notifications() async {
    await widget.store.device.requestNotifications();
    final state = await widget.store.device.guardStatus();
    if (state['notifications'] != true) {
      await widget.store.device.openNotificationSettings();
    }
  }

  Future<void> disableForBanking() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tắt Trợ năng của Octopus?'),
        content: const Text(
          'Dịch vụ chặn ứng dụng và VPN tập trung sẽ dừng. Sau khi dùng ngân hàng, bạn có thể bật lại Octopus trong Trợ năng rồi tiếp tục phiên có bảo vệ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Tắt Trợ năng'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await action(widget.store.device.disableAccessibility);
    }
  }

  Future<void> change(String key, bool value) async {
    final previous = widget.store.protection[key];
    widget.store.protection[key] = value;
    await widget.store.save();
    if (widget.store.storageError != null) {
      if (widget.store.protection[key] == value) {
        widget.store.protection[key] = previous;
      }
      if (mounted) setState(() => error = widget.store.storageError);
      return;
    }
    try {
      if (value && key == 'enabled') {
        await widget.store.device.resumeProtection();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Chưa kết nối được bộ bảo vệ. Mở Trợ năng để kiểm tra lại dịch vụ.',
        );
      }
      return;
    }
    if (mounted) setState(() {});
    await refresh();
  }

  Future<void> action(Future<dynamic> Function() run) async {
    try {
      await run();
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Không mở được yêu cầu quyền. Thử lại trong Cài đặt Android.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bảo vệ tập trung'),
      actions: [
        IconButton(
          onPressed: refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Kiểm tra lại',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const PageIntro(
          'Bảo vệ theo lựa chọn của bạn',
          'Kiểm tra kết nối dịch vụ, bật bảo vệ rồi chọn ứng dụng cần hạn chế.',
        ),
        const SizedBox(height: 16),
        Panel(
          color: const Color(0xffeef3ff),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guardSummary(widget.store, status),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status['accessibility'] != true
                    ? status['accessibilityEnabled'] == true
                          ? 'Android vẫn ghi nhận quyền đã bật, nhưng dịch vụ chưa kết nối. Mở Trợ năng, tắt rồi bật lại Octopus.'
                          : 'Mở Trợ năng để cho phép Octopus nhận biết ứng dụng đang mở.'
                    : (status['activeTitle'] as String? ?? '').isNotEmpty
                    ? status['activeTitle'] as String
                    : 'Bảo vệ áp dụng trong phiên có bảo vệ hoặc lịch đã chọn. Bạn có thể kiểm tra bằng cách bắt đầu một phiên.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Panel(
          child: Text(
            'Trợ năng nhận tên app đang mở để hiện màn hình chặn; không đọc nội dung màn hình, tin nhắn hay mật khẩu. VPN xử lý và bỏ gói mạng ngay trên máy, không chuyển qua máy chủ. Lịch sử dùng app và cảnh báo lưu trên thiết bị.',
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            status['accessibility'] == true
                ? Icons.check_circle
                : Icons.shield_outlined,
            color: blue,
          ),
          title: const Text('Kết nối Trợ năng'),
          subtitle: Text(
            status['accessibility'] == true
                ? 'Đã kết nối · nhận biết và chặn ứng dụng'
                : 'Cài đặt → Octopus · Bảo vệ tập trung → Bật',
          ),
          onTap: () => action(widget.store.device.openAccessibility),
        ),
        const Text(
          'Nếu Android khóa quyền với APK tải ngoài: Thông tin ứng dụng → ⋮ → Cho phép cài đặt bị hạn chế, rồi quay lại Trợ năng.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            status['vpnPrepared'] == true ? Icons.check_circle : Icons.vpn_lock,
            color: blue,
          ),
          title: const Text('VPN cho phiên chặn Internet'),
          subtitle: Text(
            status['vpnPrepared'] == true
                ? 'Đã cấp quyền · chỉ chặn mạng trong phiên sâu'
                : 'Android sẽ hỏi đồng ý. VPN hiện dùng có thể bị thay thế.',
          ),
          onTap: () => action(widget.store.device.prepareVpn),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            status['notifications'] == true
                ? Icons.check_circle
                : Icons.notifications_outlined,
            color: blue,
          ),
          title: const Text('Cho phép thông báo'),
          subtitle: Text(
            status['notifications'] == true
                ? 'Đã cho phép. Nhắc nghỉ và nhắc dùng app lâu được bật riêng.'
                : 'Chưa cho phép. Chạm để cấp quyền hoặc mở cài đặt thông báo.',
          ),
          onTap: () => action(notifications),
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tôi đồng ý bật bảo vệ'),
          subtitle: const Text(
            'Có thể tắt ở đây hoặc thu hồi quyền trong Android.',
          ),
          value: widget.store.protection['enabled'] == true,
          onChanged: status['accessibility'] == true
              ? (v) => change('enabled', v)
              : null,
        ),
        for (final option in const [
          [
            'watchSchedule',
            'Theo dõi lịch đã xác nhận',
            'Cắt ngang app hạn chế trong giờ học/làm việc.',
          ],
          [
            'watchFixed',
            'Bao gồm lịch cố định',
            'Áp dụng các khung giờ học/làm việc hằng tuần.',
          ],
          [
            'blockInternet',
            'Ngắt Internet khi tập trung sâu',
            'Chặn IPv4 và IPv6; ngoại lệ cho dịch vụ gọi điện.',
          ],
          [
            'sound',
            'Phát âm báo khi vi phạm',
            'Cảnh báo lặp trong 30 giây, nghỉ 60 giây rồi nhắc tiếp.',
          ],
          [
            'alarmLoud',
            'Âm báo mạnh',
            'Dùng kênh âm lượng báo thức của điện thoại.',
          ],
          [
            'vibrate',
            'Rung khi cảnh báo',
            'Rung cùng nhịp âm báo nếu thiết bị hỗ trợ.',
          ],
        ])
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(option[1]),
            subtitle: Text(option[2]),
            value: widget.store.protection[option[0]] == true,
            onChanged: (v) => change(option[0], v),
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => action(widget.store.device.previewAlarm),
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Thử âm báo'),
            ),
            TextButton(
              onPressed: () => action(widget.store.device.openSoundSettings),
              child: const Text('Âm lượng báo thức'),
            ),
          ],
        ),
        if (status['alarmVolume'] != null)
          Text(
            'Âm lượng báo thức hiện tại ${status['alarmVolume']}/${status['alarmMaxVolume']}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Chạy nền và ứng dụng ngân hàng'),
          children: [
            const Text(
              'Một số ứng dụng ngân hàng yêu cầu tắt quyền Trợ năng. Nút dưới tắt dịch vụ của Octopus và dừng VPN. Bạn cần bật lại Trợ năng sau khi dùng xong.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            TextButton(
              onPressed: disableForBanking,
              child: const Text('Tắt Trợ năng để dùng ngân hàng'),
            ),
            const Text(
              'Trên Xiaomi, mở thông tin Octopus và kiểm tra quyền chạy nền, tự khởi động và mục Tiết kiệm pin. Android có thể dừng dịch vụ khi hạn chế chạy nền.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            TextButton(
              onPressed: () => action(widget.store.device.openAppSettings),
              child: const Text('Thông tin ứng dụng và chạy nền'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Ứng dụng hạn chế khi đến giờ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const Text(
          'Phiên tập trung sâu chặn mọi app thông thường. Lịch hẹn chỉ chặn các app bạn chọn dưới đây. Điện thoại, màn hình chính và Cài đặt luôn được phép.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        if (loading) const LinearProgressIndicator(),
        if (restrictionSuggestion(usageApps, usageDays, widget.store)
            case final suggestion?)
          RestrictionSuggestionCard(
            store: widget.store,
            app: suggestion,
            onChanged: () {
              if (mounted) setState(() {});
            },
            onSkip: () {
              setState(
                () => usageApps = usageApps
                    .where((app) => app['package'] != suggestion['package'])
                    .toList(),
              );
            },
          ),
        const SizedBox(height: 12),
        const Text(
          'Ứng dụng được xếp theo thời gian dùng trong tuần khi có quyền thống kê.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Tìm ứng dụng',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => query = value.toLowerCase().trim()),
        ),
        for (final app in apps.where(
          (app) => (app['name'] as String).toLowerCase().contains(query),
        ))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            secondary: AppIdentityIcon(
              device: widget.store.device,
              package: app['package'] as String,
              name: app['name'] as String,
            ),
            title: Text(app['name'] as String),
            subtitle: Text(
              (app['milliseconds'] as num) > 0
                  ? '${usageDuration(app['milliseconds'] as num)} trong tuần'
                  : 'Chưa có thời gian dùng trong tuần',
              style: const TextStyle(fontSize: 11),
            ),
            value: widget.store.restricted.contains(app['package']),
            onChanged: (v) async {
              v == true
                  ? widget.store.restricted.add(app['package'] as String)
                  : widget.store.restricted.remove(app['package']);
              await widget.store.save();
              if (mounted) setState(() {});
            },
          ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if ((status['error'] ?? '') != '')
          Text(
            status['error'] as String,
            style: const TextStyle(color: Colors.red),
          ),
        const SizedBox(height: 12),
        const Text(
          'Đây không phải chế độ kiosk của thiết bị được quản trị. Bạn vẫn có thể vào Cài đặt, thu hồi quyền hoặc dừng app. Một số hãng cần cho phép chạy nền riêng; hãy kiểm tra trên điện thoại thật.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    ),
  );
}

class GuardStatusCard extends StatefulWidget {
  const GuardStatusCard({super.key, required this.store});
  final BrainStore store;
  @override
  State<GuardStatusCard> createState() => _GuardStatusCardState();
}

class _GuardStatusCardState extends State<GuardStatusCard> {
  Timer? timer;
  Map<String, dynamic> status = {};
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final data = await widget.store.device.guardStatus();
      if (mounted) setState(() => status = data);
    } catch (_) {
      if (mounted) setState(() => status = {});
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          guardSummary(widget.store, status),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          'Trợ năng: ${status['accessibility'] == true ? "đã kết nối" : "chưa kết nối"} · Internet: ${status['networkBlocked'] == true ? "đang chặn" : "không chặn"}',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        if (widget.store.focusEnd?.isAfter(DateTime.now()) == true &&
            widget.store.focusProtected &&
            widget.store.protection['blockInternet'] == true &&
            status['networkBlocked'] != true)
          const Text(
            'Phiên đang đếm giờ nhưng mạng chưa được chặn. Nếu trạng thái này kéo dài, kiểm tra quyền hoặc kết thúc và bắt đầu lại phiên.',
            style: TextStyle(fontSize: 12, color: Colors.deepOrange),
          ),
        if ((status['error'] ?? '') != '')
          Text(
            status['error'] as String,
            style: const TextStyle(color: Colors.red),
          ),
        TextButton.icon(
          onPressed: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ProtectionScreen(store: widget.store),
              ),
            );
            await refresh();
          },
          icon: const Icon(Icons.tune),
          label: const Text('Quyền và ứng dụng hạn chế'),
        ),
      ],
    ),
  );
}
