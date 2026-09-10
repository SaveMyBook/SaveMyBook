import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

class AdminDisputeScreen extends StatefulWidget {
  const AdminDisputeScreen({super.key});

  @override
  State<AdminDisputeScreen> createState() => _AdminDisputeScreenState();
}

class _AdminDisputeScreenState extends State<AdminDisputeScreen>
    with SingleTickerProviderStateMixin {
  static const _results = [
    (value: 'refund_manual', label: '人工退款'),
    (value: 'refund_auto', label: '自動退款'),
    (value: 'mediated', label: '協調結案'),
    (value: 'dismissed', label: '駁回申訴'),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController;

  List<DisputeCase> _disputes = [];
  bool _isLoading = true;

  bool get _isOpenTab => _tabController.index == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final all = await _api.fetchAdminDisputes();
    if (!mounted) return;
    setState(() {
      _disputes = all
          .where((d) => _isOpenTab ? d.status != 'resolved' : d.status == 'resolved')
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _arbitrate(DisputeCase dispute) async {
    final c = AppColors.of(context);
    final noteController = TextEditingController();
    String selected = _results.first.value;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('交易仲裁',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 6),
              Text('訂單 ${dispute.orderNo}｜\$${dispute.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 4),
              Text('申訴理由：${dispute.reason}',
                  style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) => setSheetState(() => selected = value ?? selected),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _results
                      .map(
                        (r) => RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: r.value,
                          title: Text(
                            r.label,
                            style: TextStyle(fontSize: 14, color: c.textPrimary),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: noteController,
                maxLines: 3,
                maxLength: 500,
                hint: '裁決說明（選填）',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('送出裁決', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await runBusy(
      context,
      () => _api.arbitrateDispute(
        dispute.disputeId,
        result: selected,
        adminNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      ),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '已完成裁決');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: '仲裁交易',
            icon: Icons.gavel_rounded,
            bottom: AppTabBar(controller: _tabController, tabs: const ['處理中', '已結案']),
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: _disputes.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.balance_rounded, message: '目前沒有此類申訴案件'),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _disputes.length,
                            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _buildCard(_disputes[i], c)),
                          ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(DisputeCase dispute, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookThumbnail(imageUrl: dispute.bookImageUrl, width: 52, height: 66, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dispute.bookTitle.isEmpty ? dispute.orderNo : dispute.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text('訂單編號：${dispute.orderNo}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text('買家：${dispute.buyerName}｜賣家：${dispute.sellerName}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text('申訴人：${dispute.applicantName}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
              Text(
                '\$${dispute.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('申訴理由：${dispute.reason}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(formatDateTime(dispute.createdAt), style: TextStyle(fontSize: 11, color: c.textHint)),
              const Spacer(),
              if (_isOpenTab)
                GestureDetector(
                  onTap: () => _arbitrate(dispute),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('處理',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                )
              else
                Text(dispute.resultText.isEmpty ? dispute.statusText : dispute.resultText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}
