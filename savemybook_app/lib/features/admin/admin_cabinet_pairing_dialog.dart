import 'dart:async';

import 'package:flutter/material.dart';
import '../../i18n/strings.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/cabinet_labels.dart';

enum _PairingState { waiting, done, failed }

Future<bool> showAdminCabinetPairingDialog(
  BuildContext context, {
  required int cabinetId,
  required AdminCabinetPairResult paired,
  String? previousDeviceNo,
}) async {
  final retry = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdminCabinetPairingDialog(cabinetId: cabinetId, paired: paired, previousDeviceNo: previousDeviceNo),
  );
  return retry ?? false;
}

class AdminCabinetPairingDialog extends StatefulWidget {
  static const pollInterval = Duration(seconds: 3);
  static const maxWait = Duration(minutes: 11);

  final int cabinetId;
  final AdminCabinetPairResult paired;
  final String? previousDeviceNo;

  const AdminCabinetPairingDialog({super.key, required this.cabinetId, required this.paired, this.previousDeviceNo});

  @override
  State<AdminCabinetPairingDialog> createState() => _AdminCabinetPairingDialogState();
}

class _AdminCabinetPairingDialogState extends State<AdminCabinetPairingDialog> {
  final ApiService _api = ApiService();
  final Stopwatch _clock = Stopwatch()..start();

  _PairingState _state = _PairingState.waiting;
  Timer? _timer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    final summary = widget.paired.summary;
    if (summary != null) _state = _evaluate(summary);
    if (_state == _PairingState.waiting) {
      _timer = Timer.periodic(AdminCabinetPairingDialog.pollInterval, (_) => _poll());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 裝置領取憑證與清除 pairing 在同一筆交易；pairing 消失而裝置未換新即為逾時或已撤銷，不以手機時鐘判斷效期。
  _PairingState _evaluate(AdminCabinetDeviceSummary summary) {
    if (summary.pairing != null) return _PairingState.waiting;
    final device = summary.device;
    return device != null && device.deviceNo != widget.previousDeviceNo ? _PairingState.done : _PairingState.failed;
  }

  Future<void> _poll() async {
    if (!mounted || _polling || _state != _PairingState.waiting) return;
    if (_clock.elapsed >= AdminCabinetPairingDialog.maxWait) {
      _finish(_PairingState.failed);
      return;
    }
    _polling = true;
    final summary = await _api.fetchCabinetDevice(widget.cabinetId);
    _polling = false;
    if (!mounted || summary == null || _state != _PairingState.waiting) return;
    final next = _evaluate(summary);
    if (next != _PairingState.waiting) _finish(next);
  }

  void _finish(_PairingState state) {
    _timer?.cancel();
    setState(() => _state = state);
  }

  Widget _kv(String label, String value, AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, maxLines: 2, style: TextStyle(fontSize: 12, color: c.textHint))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary))),
        ],
      ),
    );
  }

  Widget _status(AppColors c) {
    final (Widget icon, String text, Color tint) = switch (_state) {
      _PairingState.waiting => (
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
          S.waitingDeviceConnect,
          c.textPrimary,
        ),
      _PairingState.done => (Icon(Icons.check_circle_rounded, size: 18, color: c.success), S.paired, c.success),
      _PairingState.failed => (Icon(Icons.error_outline_rounded, size: 18, color: c.danger), S.pairingWasNotCompletedEnterNew, c.danger),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: SizedBox(width: 18, height: 18, child: Center(child: icon))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600, color: tint))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final paired = widget.paired;
    final firmware = paired.firmware;

    return AlertDialog(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(S.pairDevice, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(S.deviceType, CabinetLabels.deviceKind(paired.kind), c),
            _kv(S.numberDoors, '${paired.doorCount}', c),
            _kv(S.doorSensors, paired.hasDoorSensor ? S.installed : S.notInstalled, c),
            if (firmware != null) _kv(S.firmware, firmware, c),
            Divider(color: c.divider, height: 24),
            _status(c),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            S.actionClose,
            style: TextStyle(
              color: _state == _PairingState.failed ? c.textSecondary : c.accent,
              fontWeight: _state == _PairingState.failed ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
        if (_state == _PairingState.failed)
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.pairDevice, style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
