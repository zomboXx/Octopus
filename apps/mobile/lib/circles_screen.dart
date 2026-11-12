import 'package:flutter/material.dart';
import 'brain_store.dart';
import 'main.dart' show blue, muted;
import 'flow_design.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key, required this.store});
  final BrainStore store;
  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  BrainStore get store => widget.store;
  int selected = 0;
  Future<void> create() async {
    final circle = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const CircleEditor(),
    );
    if (circle == null) return;
    store.circles.add(circle);
    await store.save();
    if (mounted) setState(() => selected = store.circles.length - 1);
  }

  Future<void> checkin(Map<String, dynamic> circle, bool rest) async {
    final date = dayKey(DateTime.now());
    store.checkins.removeWhere(
      (c) => c['circleId'] == circle['id'] && c['date'] == date,
    );
    store.checkins.add({
      'circleId': circle['id'],
      'date': date,
      'rest': rest,
      'at': DateTime.now().toIso8601String(),
    });
    await store.save();
    if (mounted) setState(() {});
  }

  int streak(String id) {
    final dates = store.checkins
        .where((c) => c['circleId'] == id && c['rest'] != true)
        .map((c) => c['date'])
        .toSet();
    var date = DateTime.now();
    if (!dates.contains(dayKey(date))) {
      date = date.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (dates.contains(dayKey(date))) {
      n++;
      date = date.subtract(const Duration(days: 1));
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final circle = store.circles.isEmpty
        ? null
        : store.circles[selected.clamp(0, store.circles.length - 1)];
    final checked = circle == null
        ? <Map<String, dynamic>>[]
        : store.checkins
              .where(
                (c) =>
                    c['circleId'] == circle['id'] &&
                    c['date'] == dayKey(DateTime.now()),
              )
              .toList();
    final work = store.workOn(DateTime.now());
    final done = work.where((t) => t['done'] == true).length;
    final members = circle == null ? <dynamic>[] : circle['members'] as List;
    final shared = [...store.tasks, ...store.plan]
        .where(
          (t) =>
              t['done'] == true &&
              (t['audience'] == 'group' ||
                  t['audience'] == 'selected' &&
                      (t['recipients'] as List? ?? []).any(
                        (id) => members.any((m) => m['id'] == id),
                      )),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cùng nhau giữ nhịp.',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Một cam kết nhỏ. Những người bạn đồng hành.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: create,
              icon: const Icon(Icons.group_add_outlined, size: 21),
              tooltip: 'Tạo nhóm',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (circle == null) ...[
          FlowCard(
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FlowAvatar('B', size: 44),
                    SizedBox(width: 4),
                    Icon(Icons.add_rounded, color: flowBlue, size: 20),
                    SizedBox(width: 4),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: flowTint,
                      child: Icon(Icons.people_outline, color: flowBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Những điều lớn bắt đầu\ntừ một vòng tròn nhỏ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chọn một mục tiêu chung, thêm bạn đồng hành\nvà nhìn lại cam kết của mình mỗi ngày.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted, height: 1.7),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: create,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tạo vòng tròn đầu tiên'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _principles(),
        ] else ...[
          if (store.circles.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 7,
                children: store.circles
                    .asMap()
                    .entries
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e.value['name']),
                        selected: e.key == selected,
                        onSelected: (_) => setState(() => selected = e.key),
                      ),
                    )
                    .toList(),
              ),
            ),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FlowTag('CAM KẾT CHUNG', icon: Icons.flag_outlined),
                    const Spacer(),
                    for (var i = 0; i < members.length.clamp(0, 3); i++)
                      Align(
                        widthFactor: .8,
                        child: FlowAvatar(
                          members[i]['name'],
                          size: 25,
                          index: i,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  circle['name'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  circle['goal'],
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tiến độ của bạn hôm nay',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                    Text(
                      '$done / ${work.length} việc',
                      style: const TextStyle(
                        fontSize: 11,
                        color: blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: work.isEmpty ? 0 : done / work.length,
                  minHeight: 5,
                  backgroundColor: flowTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _metric('${streak(circle['id'])}', 'ngày giữ chuỗi'),
                    _metric('$done', 'việc đã xong'),
                    _metric('${members.length}', 'bạn đồng hành'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FlowCard(
            color: flowTint,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      checked.isEmpty
                          ? Icons.radio_button_unchecked
                          : checked.first['rest'] == true
                          ? Icons.spa_outlined
                          : Icons.task_alt,
                      color: blue,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        checked.isEmpty
                            ? 'Hôm nay, bạn đã giữ cam kết?'
                            : checked.first['rest'] == true
                            ? 'Dành hôm nay để nghỉ ngơi.'
                            : 'Một ngày giữ lời với chính mình.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => checkin(circle, false),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      child: const Text('Tôi đã giữ cam kết'),
                    ),
                    TextButton(
                      onPressed: () => checkin(circle, true),
                      child: const Text(
                        'Hôm nay tôi nghỉ',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chuỗi tính các ngày check-in liên tiếp. Nghỉ ngơi cũng là một phần của hành trình.',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 23),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bạn đồng hành',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              FlowTag('${members.length} bạn'),
            ],
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            const FlowCard(
              child: Text(
                'Bạn chưa thêm tên bạn đồng hành.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            )
          else
            FlowCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                children: [
                  for (var i = 0; i < members.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          FlowAvatar(members[i]['name'], size: 38, index: i),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  members[i]['name'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Chưa kết nối tài khoản',
                                  style: TextStyle(fontSize: 10, color: muted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: muted,
                          ),
                        ],
                      ),
                    ),
                    if (i < members.length - 1)
                      const Divider(height: 1, color: flowLine),
                  ],
                ],
              ),
            ),
          if (shared.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Ghi nhận bạn chọn chia sẻ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final t in shared)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FlowCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 18, color: blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['title'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((t['reflection'] ?? '').toString().isNotEmpty)
                              Text(
                                t['reflection'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            const Text(
                              'Đang lưu cục bộ · chưa gửi',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
        const SizedBox(height: 18),
        const FlowTag(
          'LƯU TRÊN MÁY · CHƯA ĐỒNG BỘ',
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 10),
        const Text(
          'Danh sách bạn và check-in hiện lưu trên thiết bị. Mời bạn, đồng bộ và chia sẻ trực tuyến chưa kết nối.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: muted, height: 1.6),
        ),
      ],
    );
  }

  Widget _metric(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: blue,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: muted, fontSize: 9)),
      ],
    ),
  );

  Widget _principles() => const FlowCard(
    color: flowTint,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.spa_outlined, color: blue, size: 22),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Cùng kỷ luật, cùng phát triển. Không dòng tin vô tận hay bảng xếp hạng gây áp lực.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ],
    ),
  );
}

class CircleEditor extends StatefulWidget {
  const CircleEditor({super.key});
  @override
  State<CircleEditor> createState() => _CircleEditorState();
}

class _CircleEditorState extends State<CircleEditor> {
  final name = TextEditingController(),
      goal = TextEditingController(),
      members = TextEditingController();
  String? error;
  @override
  void dispose() {
    name.dispose();
    goal.dispose();
    members.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tạo vòng tròn'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Tên nhóm',
              hintText: 'Cùng vượt qua kỳ thi',
            ),
          ),
          TextField(
            controller: goal,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Cam kết chung',
              hintText: 'Mỗi ngày ôn tập 45 phút',
            ),
          ),
          TextField(
            controller: members,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Tên bạn, cách nhau bằng dấu phẩy',
              hintText: 'An, Minh, Linh',
            ),
          ),
          const Text(
            'Đây là danh sách trên máy, chưa gửi lời mời.',
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
        onPressed: () {
          if (name.text.trim().isEmpty || goal.text.trim().isEmpty) {
            setState(() => error = 'Nhập tên và cam kết chung.');
            return;
          }
          final id = DateTime.now().microsecondsSinceEpoch.toString();
          final names = members.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .take(10)
              .toList();
          Navigator.pop(context, <String, dynamic>{
            'id': id,
            'name': name.text.trim(),
            'goal': goal.text.trim(),
            'members': names.indexed
                .map((e) => {'id': '$id-${e.$1}', 'name': e.$2})
                .toList(),
          });
        },
        child: const Text('Tạo nhóm'),
      ),
    ],
  );
}
