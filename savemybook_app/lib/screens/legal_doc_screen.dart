import 'package:flutter/material.dart';
import '../models/support.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

class LegalDocScreen extends StatefulWidget {
  final String docKey;
  final String fallbackTitle;
  final IconData icon;

  const LegalDocScreen({
    super.key,
    required this.docKey,
    required this.fallbackTitle,
    this.icon = Icons.description_outlined,
  });

  @override
  State<LegalDocScreen> createState() => _LegalDocScreenState();
}

class _LegalDocScreenState extends State<LegalDocScreen> {
  final ApiService _api = ApiService();
  LegalDoc? _doc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _api.fetchLegalDoc(widget.docKey);
    if (!mounted) return;
    setState(() {
      _doc = doc;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final doc = _doc;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: doc?.title ?? widget.fallbackTitle, icon: widget.icon),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView()
                  : doc == null
                      ? const EmptyView(
                          icon: Icons.description_outlined,
                          message: '這份文件尚未建立',
                        )
                      : RefreshIndicator(
                          color: c.accent,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                            children: [
                              FadeSlideIn(
                                child: AppCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    doc.content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.9,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '最後更新：${formatDate(doc.updatedAt)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: c.textHint),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
