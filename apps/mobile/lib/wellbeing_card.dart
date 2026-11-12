import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'flow_design.dart';

Future<void> showWellbeingReminder(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    icon: const Icon(Icons.water_drop_outlined, color: flowBlue, size: 36),
    title: const Text('Nghỉ nhẹ, nạp lại nhịp.'),
    content: const Text(
      'Uống một ít nước, đứng dậy và thả lỏng vai trong 1–2 phút. Nhìn ra xa để mắt được nghỉ.\n\nBộ đếm và bảo vệ tập trung vẫn tiếp tục; bạn không cần dùng điện thoại trong lúc nghỉ.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Đã nhớ · cảm ơn'),
      ),
    ],
  ),
);

Future<void> prepareWellbeingReminders(
  BuildContext context,
  BrainStore store,
  int minutes,
) async {
  if (!store.wellbeingReminders ||
      minutes <= 40 ||
      store.profile['wellbeingPermissionAsked'] == true) {
    return;
  }
  try {
    final status = await store.device.wellbeingStatus();
    if (status['allowed'] == true || !context.mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nhắc chăm sóc bản thân'),
        content: const Text(
          'Sau mỗi 40 phút trong phiên dài, Octopus sẽ hiện thông báo kèm âm thanh nhắc uống nước và vận động nhẹ. Chỉ dùng giờ bắt đầu/kết thúc trên máy, không gửi dữ liệu đi. Âm thanh tuân theo cài đặt im lặng/Không làm phiền của bạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bắt đầu không thông báo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cho phép thông báo'),
          ),
        ],
      ),
    );
    store.profile['wellbeingPermissionAsked'] = true;
    await store.save();
    if (accept == true) await store.device.requestWellbeingPermission();
  } catch (_) {
    /* Non-Android previews cannot grant notification permissions. */
  }
}

class WellbeingCard extends StatefulWidget {
  const WellbeingCard({super.key, required this.store});
  final BrainStore store;
  @override
  State<WellbeingCard> createState() => _WellbeingCardState();
}

class _WellbeingCardState extends State<WellbeingCard>
    with WidgetsBindingObserver {
  Map<String, dynamic>? status;
  String? error;
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
      final value = await widget.store.device.wellbeingStatus();
      if (mounted) setState(() => status = value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Quyền thông báo chỉ có trên Android.');
      }
    }
  }

  Future<void> permission() async {
    try {
      widget.store.profile['wellbeingPermissionAsked'] = true;
      await widget.store.save();
      final value = await widget.store.device.requestWellbeingPermission();
      if (mounted) setState(() => status = value);
      if (value['allowed'] != true) {
        await widget.store.device.openWellbeingSettings();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Chưa mở được cài đặt thông báo Android.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => FlowCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.water_drop_outlined, color: flowBlue),
          title: const Text(
            'Nghỉ nhẹ & uống nước',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Nhắc sau mỗi 40 phút trong phiên dài.',
            style: TextStyle(fontSize: 11, color: flowMuted),
          ),
          value: widget.store.wellbeingReminders,
          onChanged: (value) async {
            setState(() => widget.store.wellbeingReminders = value);
            await widget.store.save();
          },
        ),
        const Text(
          'Dành 1–2 phút đứng dậy, thả lỏng vai và uống nước. Bộ đếm và bảo vệ vẫn tiếp tục.',
          style: TextStyle(fontSize: 11, color: flowMuted),
        ),
        if (widget.store.wellbeingReminders) ...[
          const SizedBox(height: 9),
          if (status?['allowed'] != true)
            TextButton.icon(
              onPressed: permission,
              icon: const Icon(Icons.notifications_active_outlined, size: 17),
              label: const Text(
                'Cho phép thông báo & âm thanh',
                style: TextStyle(fontSize: 11),
              ),
            ),
          if (status?['allowed'] == true)
            TextButton.icon(
              onPressed: () => widget.store.device.openWellbeingSettings(),
              icon: const Icon(Icons.notifications_outlined, size: 17),
              label: Text(
                status?['sound'] == true && status?['headsUp'] == true
                    ? 'Thông báo đã bật · Cài đặt âm thanh'
                    : 'Kiểm tra âm thanh / banner trong Android',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          const Text(
            'Nhắc trên máy, không cần Internet. Android có thể nhắc muộn khi tiết kiệm pin; âm thanh và banner tuân theo cài đặt hệ thống.',
            style: TextStyle(fontSize: 10, color: flowMuted),
          ),
        ],
        if (error != null)
          Text(error!, style: const TextStyle(fontSize: 11, color: flowMuted)),
      ],
    ),
  );
}
