import 'dart:async';
import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'main.dart' show Panel, PageIntro, blue, muted;

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
  String? error;
  bool loading = true;
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
      final data = await widget.store.device.guardStatus();
      final installed = await widget.store.device.installedApps();
      if (mounted) {
        setState(() {
          status = data;
          apps = installed;
          error = null;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Chưa đọc được quyền Android. Thử kiểm tra lại.';
          loading = false;
        });
      }
    }
  }

  Future<void> change(String key, bool value) async {
    widget.store.protection[key] = value;
    await widget.store.save();
    if (value && key == 'enabled') await widget.store.device.resumeProtection();
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
          'Thiết lập một lần.',
          'Android cần bạn tự cấp quyền. Octopus chỉ bật bảo vệ khi bạn đồng ý bên dưới.',
        ),
        const SizedBox(height: 16),
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
          title: const Text('1. Cho phép Trợ năng'),
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
          title: const Text('2. Cho phép VPN cục bộ'),
          subtitle: Text(
            status['vpnPrepared'] == true
                ? 'Đã cấp quyền · chỉ chặn mạng trong phiên sâu'
                : 'Android sẽ hỏi đồng ý. VPN hiện dùng có thể bị thay thế.',
          ),
          onTap: () => action(widget.store.device.prepareVpn),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined, color: blue),
          title: const Text('3. Hiện thông báo phiên tập trung'),
          subtitle: const Text(
            'Hiện trạng thái bảo vệ; nhắc nghỉ nhẹ và uống nước mỗi 40 phút trong phiên dài.',
          ),
          onTap: () => action(widget.store.device.requestNotifications),
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
            '30 giây cảnh báo, nghỉ 60 giây. Theo âm lượng máy.',
          ],
        ])
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(option[1]),
            subtitle: Text(option[2]),
            value: widget.store.protection[option[0]] == true,
            onChanged: (v) => change(option[0], v),
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
        for (final app in apps)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(app['name'] as String),
            subtitle: Text(
              app['package'] as String,
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
          widget.store.protection['enabled'] == true &&
                  status['accessibility'] == true
              ? 'Bộ bảo vệ đã sẵn sàng'
              : 'Cần thiết lập bảo vệ',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          'Trợ năng: ${status['accessibility'] == true ? "đã kết nối" : "chưa kết nối"} · Internet: ${status['networkBlocked'] == true ? "đang chặn" : "không chặn"}',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        if (widget.store.focusEnd?.isAfter(DateTime.now()) == true &&
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
