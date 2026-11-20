import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'flow_design.dart';

class UsageReminderCard extends StatefulWidget {
  const UsageReminderCard({super.key, required this.store});
  final BrainStore store;
  @override
  State<UsageReminderCard> createState() => _UsageReminderCardState();
}

class _UsageReminderCardState extends State<UsageReminderCard>
    with WidgetsBindingObserver {
  Map<String, dynamic> status = {};
  bool busy = false;
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
      final data = await widget.store.device.usageReminderStatus();
      if (mounted) setState(() => status = data);
    } catch (_) {
      if (mounted) setState(() => status = {});
    }
  }

  Future<void> change(bool value) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (value) {
        await widget.store.device.requestNotifications();
        final current = await widget.store.device.usageReminderStatus();
        if (current['notifications'] != true ||
            current['usageGranted'] != true) {
          if (mounted) {
            setState(
              () => error =
                  'Cần quyền truy cập sử dụng và thông báo để gửi lời nhắc.',
            );
          }
          return;
        }
      }
      widget.store.protection['usageReminders'] = value;
      await widget.store.save();
      if (widget.store.storageError != null) {
        widget.store.protection['usageReminders'] = !value;
        if (mounted) setState(() => error = widget.store.storageError);
      }
      // Native foreground-service startup completes after the state write.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Chưa bật được lời nhắc. Kiểm tra quyền thông báo rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeStrength(bool value) async {
    final previous = widget.store.protection['usageReminderStrong'];
    setState(() {
      busy = true;
      error = null;
    });
    try {
      widget.store.protection['usageReminderStrong'] = value;
      await widget.store.save();
      if (widget.store.storageError != null) {
        widget.store.protection['usageReminderStrong'] = previous;
        error = widget.store.storageError;
      }
      await refresh();
    } catch (_) {
      widget.store.protection['usageReminderStrong'] = previous;
      error = 'Chưa lưu được mức nhắc. Hãy thử lại.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.store.protection['usageReminders'] == true;
    return FlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Nhắc khi dùng ứng dụng lâu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              enabled
                  ? status['running'] == true
                        ? 'Đang nhắc ở nền'
                        : 'Đã bật · đang kiểm tra chạy nền'
                  : 'Bật để nhận lời nhắc khi dùng cùng một app liên tục.',
            ),
            value: enabled,
            onChanged: busy ? null : change,
          ),
          const Text(
            'Lời nhắc này hoạt động cả khi bạn chưa mở phiên tập trung.',
            style: TextStyle(color: flowMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in [15, 20, 30])
                ChoiceChip(
                  label: Text('Mỗi $minutes phút'),
                  selected:
                      widget.store.protection['usageReminderMinutes'] ==
                      minutes,
                  onSelected: busy
                      ? null
                      : (_) async {
                          widget.store.protection['usageReminderMinutes'] =
                              minutes;
                          await widget.store.save();
                          if (mounted) setState(() {});
                        },
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nhắc mạnh hơn'),
            subtitle: const Text(
              'Âm báo khoảng 3 giây, rung dài và lời nhắc dứt khoát. Dùng âm lượng báo thức của máy.',
            ),
            value: widget.store.protection['usageReminderStrong'] == true,
            onChanged: busy ? null : changeStrength,
          ),
          TextButton.icon(
            onPressed: busy
                ? null
                : () async {
                    try {
                      await widget.store.device.requestNotifications();
                      await widget.store.device.testUsageReminder();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã gửi thông báo thử. Kiểm tra thanh thông báo của điện thoại.',
                            ),
                          ),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error =
                              'Cho phép thông báo trong Cài đặt Android rồi thử lại.',
                        );
                      }
                    }
                    await refresh();
                  },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Gửi thông báo thử'),
          ),
          if (status['notifications'] == false)
            TextButton(
              onPressed: widget.store.device.openNotificationSettings,
              child: const Text('Mở cài đặt thông báo'),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if ((status['error'] as String? ?? '').isNotEmpty)
            Text(
              status['error'] as String,
              style: const TextStyle(color: Colors.deepOrange, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
