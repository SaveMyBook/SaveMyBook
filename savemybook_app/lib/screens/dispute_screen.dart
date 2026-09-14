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
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import 'package:flutter/services.dart';
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
  bool _submitted = false;
  String? _orderError;
  String? _reasonError;

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
    if (_isSubmitting) return;
    final orderId = int.tryParse(_orderIdController.text.trim());
    final reason = _reasonController.text.trim();

    final orderError = orderId == null ? S.enterOrderNumberDisputing : null;
    final reasonError = reason.isEmpty
        ? S.describeDispute
        : reason.length < 10
            ? S.useLeast10CharactersSoSupport
            : null;
    setState(() {
      _orderError = orderError;
      _reasonError = reasonError;
    });
    if (orderError != null || reasonError != null || orderId == null) return;
    FocusScope.of(context).unfocus();

    final confirmed = await showConfirmDialog(
      context,
      title: S.submitDispute,
      message: S.orderEntersDisputeProcessPaymentSeller,
      confirmLabel: S.actionSubmit,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    final evidenceUrls = await _api.uploadFiles(_evidence.map((f) => f.path).toList());
    if (!mounted) return;
    if (_evidence.isNotEmpty && evidenceUrls.isEmpty) {
      setState(() => _isSubmitting = false);
      showAppSnackBar(context, S.couldNotUploadPhotosPleaseTry, isError: true);
      return;
    }
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

    setState(() => _submitted = true);
    showAppSnackBar(context, S.disputeSubmittedSupportContact);
    Navigator.of(context).pop();
  }

  bool get _isDirty => !_submitted && (_reasonController.text.trim().isNotEmpty || _evidence.isNotEmpty);

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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                      secondary: Icon(Icons.ac_unit_rounded, color: AppColors.primary),
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
                  FormRowCard(
                    label: S.orderNumber,
                    state: widget.orderId != null ? FieldState.locked : FieldState.normal,
                    child: AppTextField(
                      controller: _orderIdController,
                      hint: S.eGSmb20260910123456789,
                      enabled: widget.orderId == null,
                      errorText: _orderError,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      maxLength: 12,
                      onChanged: (_) {
                        if (_orderError != null) setState(() => _orderError = null);
                      },
                    ),
                  ),
                  FormRowCard(
                    label: S.whatHappened,
                    alignTop: true,
                    child: AppTextField(
                      controller: _reasonController,
                      maxLines: 5,
                      maxLength: 500,
                      errorText: _reasonError,
                      hint: S.describeProblemEGConditionDoes,
                      onChanged: (_) => setState(() => _reasonError = null),
                    ),
                  ),
                  _buildEvidenceCard(c),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: S.submit,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildEvidenceCard(AppColors c) {
    return FormRowCard(
      label: S.uploadPhotos,
      alignTop: true,
      margin: EdgeInsets.zero,
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
                              behavior: HitTestBehavior.opaque,
                              onTap: _isSubmitting ? null : () => setState(() => _evidence.remove(file)),
                              child: Icon(Icons.cancel, size: 20, color: c.danger),
                            ),
                          ),
                        ],
                      ),
                    PressableScale(
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
                Text('${_evidence.length} / 6', style: TextStyle(fontSize: 11, color: c.textHint)),
              ],
            ),
    );
  }
}
