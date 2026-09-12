import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/photo_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/guards.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../i18n/strings.dart';

class DisputeScreen extends StatefulWidget {
  final int? orderId;
  const DisputeScreen({super.key, this.orderId});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _orderIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final List<XFile> _evidence = [];

  bool _freezeRequested = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) {
      _orderIdController.text = widget.orderId.toString();
    }
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final orderId = int.tryParse(_orderIdController.text.trim());
    final reason = _reasonController.text.trim();

    if (orderId == null) {
      showAppSnackBar(context, S.enterOrderNumberDisputing, isError: true);
      return;
    }
    if (reason.isEmpty) {
      showAppSnackBar(context, S.describeDispute, isError: true);
      return;
    }
    if (reason.length < 10) {
      showAppSnackBar(context, S.useLeast10CharactersSoSupport, isError: true);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: S.submitDispute,
      message: S.orderEntersDisputeProcessPaymentSeller,
      confirmLabel: S.actionSubmit,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    final evidenceUrls = await _api.uploadFiles(_evidence.map((f) => f.path).toList());
    final error = await _api.submitDispute(
      orderId: orderId,
      reason: _freezeRequested ? S.paymentHoldRequested(reason) : reason,
      evidenceUrls: evidenceUrls,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }

    showAppSnackBar(context, S.disputeSubmittedSupportContact);
    Navigator.of(context).maybePop();
  }

  /// 申訴理由打了一半、或已經挑了證據照片，就別讓返回鍵直接吃掉。
  bool get _isDirty => _reasonController.text.trim().isNotEmpty || _evidence.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _isDirty,
      child: Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.dispute, icon: Icons.error_outline_rounded),
          Expanded(
            child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _freezeRequested,
                      activeThumbColor: c.accent,
                      onChanged: (value) => setState(() => _freezeRequested = value),
                      secondary: const Icon(Icons.ac_unit_rounded, color: AppColors.primary),
                      title: Text(
                        S.requestPaymentHold,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                      subtitle: Text(
                        S.paymentSellerHeldUntilSupportDecides,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    S.submitDispute2,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Divider(color: c.divider),
                  const SizedBox(height: 12),
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: Text(S.orderNumber,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        ),
                        Expanded(
                          child: AppTextField(
                            controller: _orderIdController,
                            hint: S.eGSmb20260910123456789,
                            enabled: widget.orderId == null,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 76,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(S.whatHappened,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                          ),
                        ),
                        Expanded(
                          child: AppTextField(
                            controller: _reasonController,
                            maxLines: 5,
                            maxLength: 500,
                            hint: S.describeProblemEGConditionDoes,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEvidenceCard(c),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: c.accent.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(S.submit, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildEvidenceCard(AppColors c) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(S.uploadPhotos,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final file in _evidence)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(file.path), width: 64, height: 64, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: GestureDetector(
                              onTap: () => setState(() => _evidence.remove(file)),
                              child: Icon(Icons.cancel, size: 18, color: c.danger),
                            ),
                          ),
                        ],
                      ),
                    GestureDetector(
                      onTap: () async {
                        if (_evidence.length >= 6) {
                          showAppSnackBar(context, S.canAttachUp6Photos, isError: true);
                          return;
                        }
                        final paths = await PhotoService.pickAndCropMultiple(
                          context,
                          remaining: 6 - _evidence.length,
                          aspectRatio: 3 / 4,
                          outputSize: 1200,
                        );
                        if (paths.isNotEmpty && mounted) {
                          setState(() => _evidence.addAll(paths.map(XFile.new)));
                        }
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: c.inputFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.divider),
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(S.up5, style: TextStyle(fontSize: 11, color: c.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
