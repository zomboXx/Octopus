import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flow_design.dart';
import 'trial_api.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({
    super.key,
    this.catalogUrl = 'https://zomboxx.github.io/Octopus/plans.json',
  });
  final String? catalogUrl;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with WidgetsBindingObserver {
  late Future<List<_Plan>> plans = _loadPlans();
  bool annual = false;
  bool catalogLoading = false;
  String catalogMessage = 'Giá đã lưu trong bản cài';
  HttpClient? catalogClient;
  String selected = 'focus';
  final trialApi = TrialApi();
  Map<String, dynamic>? trial;
  bool checking = false;
  String? trialMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (trialApi.configured) _refreshTrial();
    if (widget.catalogUrl != null) _refreshPublishedPlans();
  }

  @override
  void dispose() {
    catalogClient?.close(force: true);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && trialApi.configured) {
      _refreshTrial();
    }
  }

  Future<void> _refreshTrial({bool redeem = false, String? code}) async {
    if (checking) return;
    setState(() {
      checking = true;
      trialMessage = null;
    });
    try {
      final data = redeem
          ? await trialApi.redeem(code: code)
          : await trialApi.status();
      if (!mounted) return;
      setState(() => trial = data);
    } on FormatException catch (error) {
      if (mounted) setState(() => trialMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => trialMessage =
              'Không kết nối được dịch vụ dùng thử. Thử lại sau.',
        );
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _enterTrialCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        var input = '';
        return AlertDialog(
          title: const Text('Nhập mã dùng thử'),
          content: TextField(
            autofocus: true,
            maxLength: 64,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Giftcode'),
            onChanged: (value) => input = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.trim()),
              child: const Text('Đổi mã'),
            ),
          ],
        );
      },
    );
    if (!mounted || code == null || code.isEmpty) return;
    await _refreshTrial(redeem: true, code: code);
  }

  Widget _trialCard() {
    final expires = DateTime.tryParse(trial?['expiresAt'] as String? ?? '');
    final expiresVietnam = expires?.toUtc().add(const Duration(hours: 7));
    final active = trial?['tier'] == 'trial';
    final tier = trial?['tier'];
    final paid = tier == 'focus_pro' || tier == 'mentor_coach';
    final expiry = expiresVietnam
        ?.toIso8601String()
        .replaceFirst('T', ' ')
        .substring(0, 16);
    return FlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            active
                ? 'Trial · Premium'
                : switch (tier) {
                    'focus_pro' => 'Focus Pro',
                    'mentor_coach' => 'Mentor & Coach',
                    _ => 'Dùng thử Premium',
                  },
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (expiry != null)
            Text(
              '${active || paid ? 'Hết hạn' : 'Đã hết hạn'}: $expiry · giờ Việt Nam',
            ),
          if (checking) const LinearProgressIndicator(),
          if (trialMessage != null) Text(trialMessage!),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: checking ? null : _enterTrialCode,
                child: const Text('Nhập mã dùng thử'),
              ),
              if (trialApi.configured && !active && !paid)
                TextButton(
                  onPressed: checking
                      ? null
                      : () => _refreshTrial(redeem: true),
                  child: const Text('Nhận ưu đãi lần đầu'),
                ),
              if (trialApi.configured)
                TextButton(
                  onPressed: checking ? null : _refreshTrial,
                  child: const Text('Làm mới'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<_Plan>> _loadPlans() async {
    return _parsePlans(await rootBundle.loadString('assets/plans.json'));
  }

  List<_Plan> _parsePlans(String text) {
    final data = jsonDecode(text);
    return (data as List).map((item) {
      final plan = item as Map<String, dynamic>;
      final id = switch (plan['id']) {
        'free' => 'starter',
        'pro' => 'focus',
        _ => plan['id'] as String,
      };
      final amount = plan['monthlyAmount'] as num?;
      final formatted = amount?.toInt().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
      final monthly = amount == null
          ? plan['monthly'] as String
          : amount == 0
          ? 'Miễn phí'
          : '${plan['pricePrefix'] == null ? '' : '${plan['pricePrefix']} '}$formatted đ${plan['priceUnit'] ?? '/tháng'}';
      return _Plan(
        id: id,
        name: plan['name'] as String,
        label:
            plan['label'] as String? ??
            (id == 'starter'
                ? 'Miễn phí'
                : plan['audience'] as String? ?? 'Giá công bố'),
        description: plan['description'] as String,
        monthly: monthly,
        annual: plan['annual'] as String?,
        features: List<String>.from(plan['features'] as List),
      );
    }).toList();
  }

  Future<void> _refreshPublishedPlans() async {
    if (catalogLoading || widget.catalogUrl == null) return;
    setState(() => catalogLoading = true);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    catalogClient = client;
    try {
      final request = await client
          .getUrl(Uri.parse(widget.catalogUrl!))
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != 200) {
        throw const FormatException('Catalog unavailable');
      }
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 6));
      if (text.length > 100000) {
        throw const FormatException('Catalog too large');
      }
      final latest = _parsePlans(text);
      if (latest.isEmpty) throw const FormatException('Catalog empty');
      if (mounted) {
        setState(() {
          plans = Future.value(latest);
          catalogMessage = 'Giá đồng bộ từ website Octopus';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => catalogMessage = 'Đang hiển thị giá đã lưu trên máy');
      }
    } finally {
      client.close(force: true);
      if (identical(catalogClient, client)) catalogClient = null;
      if (mounted) setState(() => catalogLoading = false);
    }
  }

  void _showDetails(_Plan plan) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan.name),
        content: Text(
          '${plan.price(annual)} · Giá tham khảo\n\n'
          'Octopus đang chuẩn bị gói này. Đăng ký và thanh toán sẽ mở sau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gói Octopus'),
      actions: [
        IconButton(
          onPressed: catalogLoading ? null : _refreshPublishedPlans,
          tooltip: 'Cập nhật giá từ website',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<_Plan>>(
      future: plans,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => plans = _loadPlans()),
              child: const Text('Tải lại danh sách gói'),
            ),
          );
        }
        final available = snapshot.data;
        if (available == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            const Center(child: FlowTag('So sánh các gói')),
            const SizedBox(height: 14),
            Text(
              'Chọn gói phù hợp với nhịp của bạn',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: flowInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              catalogMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: flowMuted),
            ),
            const SizedBox(height: 20),
            if (available.any((plan) => plan.annual != null))
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Theo tháng')),
                  ButtonSegment(value: true, label: Text('Theo năm')),
                ],
                selected: {annual},
                onSelectionChanged: (value) =>
                    setState(() => annual = value.single),
              ),
            const SizedBox(height: 16),
            if (trialApi.configured) _trialCard(),
            const SizedBox(height: 16),
            for (final plan in available) ...[
              _planCard(plan),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    ),
  );

  Widget _planCard(_Plan plan) {
    final isSelected = plan.id == selected;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isSelected ? flowBlue : flowLine,
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            selected: isSelected,
            child: InkWell(
              onTap: () => setState(() => selected = plan.id),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: FlowTag(plan.label, filled: isSelected),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected ? flowBlue : flowMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      plan.price(annual),
                      style: const TextStyle(
                        color: flowBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(plan.description),
                    const Divider(height: 24),
                    for (final feature in plan.features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              plan.id == 'starter'
                                  ? Icons.check_circle_outline
                                  : Icons.schedule,
                              size: 17,
                              color: flowBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(feature)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: FilledButton(
                onPressed: plan.id == 'starter'
                    ? () => Navigator.pop(context)
                    : () => _showDetails(plan),
                child: Text(
                  plan.id == 'starter'
                      ? 'Tiếp tục với Starter'
                      : 'Xem thông tin gói',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Plan {
  const _Plan({
    required this.id,
    required this.name,
    required this.label,
    required this.description,
    required this.monthly,
    required this.annual,
    required this.features,
  });

  final String id, name, label, description, monthly;
  final String? annual;
  final List<String> features;

  String price(bool yearly) =>
      yearly ? annual ?? 'Chưa công bố giá năm' : monthly;
}
