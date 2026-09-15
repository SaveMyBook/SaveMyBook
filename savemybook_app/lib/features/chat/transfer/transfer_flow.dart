import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../models/chat.dart';
import '../../../services/api_service.dart';
import '../../../services/verification_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_tiles.dart';
import '../../../widgets/state_views.dart';
import '../../account/wallet_screen.dart';
import '../widgets/chat_format.dart';
import 'transfer_card.dart';

const int kTransferMaxAmount = 100000;
const int kTransferNoteMax = 100;

class _TransferDraft {
  final ChatMember target;
  final int amount;
  final String note;

  const _TransferDraft(this.target, this.amount, this.note);
}

Future<ChatMessage?> startCoinTransfer(
  BuildContext context, {
  required int roomId,
  required bool request,
  required List<ChatMember> candidates,
}) async {
  final myId = ApiService.currentUser?.userId ?? 0;
  final targets = candidates.where((m) => m.userId != 0 && m.userId != myId).toList();
  if (targets.isEmpty) {
    showAppSnackBar(context, S.somethingWentWrongPleaseTryAgain, isError: true);
    return null;
  }

  FocusScope.of(context).unfocus();
  final c = AppColors.of(context);
  final draft = await showModalBottomSheet<_TransferDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.sheetBg,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _TransferSheet(request: request, candidates: targets),
  );
  if (draft == null || !context.mounted) return null;

  final api = ApiService();
  final name = draft.target.displayName;
  final amountText = formatCoinAmount(draft.amount.toDouble());

  if (request) {
    final (_, message, error) = await runBusy(
          context,
          () => api.requestCoinTransfer(roomId, fromUserId: draft.target.userId, amount: draft.amount, note: draft.note),
        ) ??
        (null, null, S.somethingWentWrongPleaseTryAgain);
    if (!context.mounted) return null;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return null;
    }
    HapticFeedback.mediumImpact();
    return message;
  }

  VerificationService.paymentSummary = PaymentSummary(amount: draft.amount.toDouble(), detail: S.transferP0(name));
  (ChatTransfer?, ChatMessage?, String?) result;
  try {
    result = await api.sendCoinTransfer(roomId, toUserId: draft.target.userId, amount: draft.amount, note: draft.note);
  } finally {
    VerificationService.paymentSummary = null;
  }
  if (!context.mounted) return null;
  final (_, message, error) = result;
  if (error != null) {
    if (error != S.verificationCancelled) await _showTransferError(context, error, draft.amount);
    return null;
  }
  HapticFeedback.heavyImpact();
  showAppSnackBar(context, S.sentP0CoinsP1(amountText, name));
  return message;
}

Future<ChatTransfer?> respondToTransfer(
  BuildContext context, {
  required ChatTransfer transfer,
  required TransferAction action,
  required String counterpartName,
}) async {
  final api = ApiService();
  final amountText = formatCoinAmount(transfer.amount);
  final name = counterpartName;

  final bool confirmed;
  switch (action) {
    case TransferAction.pay:
      confirmed = await showConfirmDialog(
        context,
        title: S.confirmPayment,
        message: S.payP0CoinsP1(amountText, name),
        confirmLabel: S.payNow,
        icon: Icons.payments_outlined,
      );
    case TransferAction.decline:
      confirmed = await showConfirmDialog(
        context,
        title: S.declineRequest,
        message: S.declineP1CoinRequestFromP0(name, amountText),
        confirmLabel: S.decline2,
        isDestructive: true,
        icon: Icons.block_rounded,
      );
    case TransferAction.cancel:
      confirmed = await showConfirmDialog(
        context,
        title: S.cancelRequest,
        message: S.cancelRequestP0P1Coins(name, amountText),
        confirmLabel: S.cancelRequest,
        cancelLabel: S.notNow2,
        isDestructive: true,
        icon: Icons.undo_rounded,
      );
  }
  if (!confirmed || !context.mounted) return null;

  final (ChatTransfer?, String?) result;
  switch (action) {
    case TransferAction.pay:
      VerificationService.paymentSummary = PaymentSummary(amount: transfer.amount, detail: S.payRequestFromP0(name));
      try {
        result = await api.payCoinTransfer(transfer.transferId);
      } finally {
        VerificationService.paymentSummary = null;
      }
    case TransferAction.decline:
      result = await api.declineCoinTransfer(transfer.transferId);
    case TransferAction.cancel:
      result = await api.cancelCoinTransfer(transfer.transferId);
  }
  if (!context.mounted) return result.$1;

  final (updated, error) = result;
  if (error != null) {
    if (error != S.verificationCancelled) {
      if (action == TransferAction.pay) {
        await _showTransferError(context, error, transfer.amount.round());
      } else {
        showAppSnackBar(context, error, isError: true);
      }
    }
    return null;
  }

  switch (action) {
    case TransferAction.pay:
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.paymentCompleted);
    case TransferAction.decline:
      showAppSnackBar(context, S.requestDeclined);
    case TransferAction.cancel:
      showAppSnackBar(context, S.requestCanceled);
  }
  return updated;
}

Future<void> _showTransferError(BuildContext context, String error, int amount) async {
  final wallet = await ApiService().fetchWallet();
  if (!context.mounted) return;
  if (wallet.balance < amount) {
    showAppSnackBar(
      context,
      error,
      isError: true,
      actionLabel: S.goWallet,
      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
    );
  } else {
    showAppSnackBar(context, error, isError: true);
  }
}

class _TransferSheet extends StatefulWidget {
  final bool request;
  final List<ChatMember> candidates;

  const _TransferSheet({required this.request, required this.candidates});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final TextEditingController _note = TextEditingController();
  final FocusNode _noteFocus = FocusNode();
  final FocusNode _keyFocus = FocusNode();
  late ChatMember? _target = widget.candidates.length == 1 ? widget.candidates.first : null;
  String _digits = '';
  double? _balance;
  bool _noteActive = false;

  bool get _multi => widget.candidates.length > 1;

  int get _amount => int.tryParse(_digits) ?? 0;

  bool get _overLimit => _amount > kTransferMaxAmount;

  bool get _insufficient => !widget.request && _balance != null && _amount > _balance!;

  bool get _canSubmit => _target != null && _amount >= 1 && !_overLimit && !_insufficient;

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(() {
      if (mounted) setState(() => _noteActive = _noteFocus.hasFocus);
    });
    if (!widget.request) _loadBalance();
  }

  Future<void> _loadBalance() async {
    final wallet = await ApiService().fetchWallet();
    if (!mounted) return;
    setState(() => _balance = wallet.balance);
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == 'back') {
        if (_digits.isNotEmpty) _digits = _digits.substring(0, _digits.length - 1);
        return;
      }
      final next = _digits == '' ? key.replaceFirst(RegExp(r'^0+'), '') : _digits + key;
      if (next.length > 6) return;
      _digits = next;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_noteActive || event is KeyUpEvent) return KeyEventResult.ignored;
    final label = event.character;
    if (label != null && RegExp(r'^[0-9]$').hasMatch(label)) {
      _press(label);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _press('back');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && _canSubmit) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit() {
    final target = _target;
    if (target == null) {
      showAppSnackBar(context, widget.request ? S.selectPayer : S.selectRecipient, isError: true);
      return;
    }
    if (!_canSubmit) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _TransferDraft(target, _amount, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.request ? S.request : S.transfer;

    return Focus(
      focusNode: _keyFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 14),
                _multi ? _recipientPicker(c) : _recipientRow(c, widget.candidates.first),
                const SizedBox(height: 14),
                _amountDisplay(c),
                const SizedBox(height: 12),
                _noteField(c),
                AnimatedSize(
                  duration: Motion.base,
                  curve: Motion.standard,
                  child: _noteActive ? const SizedBox(width: double.infinity) : _keypad(c),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canSubmit || (_target == null && _amount > 0) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chatMineBubble(c),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: c.inputFill,
                      disabledForegroundColor: c.textHint,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      widget.request ? S.sendRequest2 : S.confirmTransfer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recipientRow(AppColors c, ChatMember member) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          UserAvatar(imageUrl: member.avatarUrl, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request ? S.payer : S.recipient,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
                const SizedBox(height: 1),
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipientPicker(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            widget.request ? S.payer : S.recipient,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textSecondary),
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.candidates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final member = widget.candidates[i];
              final selected = _target?.userId == member.userId;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _target = member);
                },
                child: SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: Motion.micro,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: selected ? c.accent : Colors.transparent, width: 2),
                            ),
                            child: UserAvatar(imageUrl: member.avatarUrl, radius: 24),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: AnimatedScale(
                              scale: selected ? 1 : 0,
                              duration: Motion.micro,
                              curve: Motion.pop,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.sheetBg, width: 2),
                                ),
                                child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? c.accent : c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _amountDisplay(AppColors c) {
    final empty = _digits.isEmpty;
    final String? hint;
    Color hintColor = c.textSecondary;
    if (_overLimit) {
      hint = S.limitPerTransferP0Coins(formatCoinAmount(kTransferMaxAmount.toDouble()));
      hintColor = c.danger;
    } else if (!widget.request && _balance != null) {
      final balanceText = formatCoinAmount(_balance!);
      hint = _insufficient ? S.insufficientBalanceP0Coins(balanceText) : S.balanceP0Coins(balanceText);
      if (_insufficient) hintColor = c.danger;
    } else {
      hint = widget.request ? null : '';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  empty ? '0' : formatCoinAmount(_amount.toDouble()),
                  style: TextStyle(
                    fontSize: 40,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: empty ? c.textHint : (_overLimit || _insufficient ? c.danger : c.textPrimary),
                  ),
                ),
                const SizedBox(width: 6),
                Text(S.faqCatWallet, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textSecondary)),
              ],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: hint.isEmpty
                  ? Center(
                      child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: c.textHint)),
                    )
                  : Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: hintColor),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _noteField(AppColors c) {
    return TextField(
      controller: _note,
      focusNode: _noteFocus,
      maxLines: 1,
      inputFormatters: [LengthLimitingTextInputFormatter(kTransferNoteMax)],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _noteFocus.unfocus(),
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: S.noteOptional,
        hintStyle: TextStyle(color: c.textHint, fontSize: 14),
        prefixIcon: Icon(Icons.edit_note_rounded, color: c.iconInactive, size: 22),
        filled: true,
        fillColor: c.inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _keypad(AppColors c) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', 'back'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final width = (constraints.maxWidth - spacing * 2) / 3;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final key in keys)
                SizedBox(
                  width: width,
                  height: 50,
                  child: Material(
                    color: key == 'back' ? Colors.transparent : c.inputFill,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _press(key),
                      onLongPress: key == 'back' ? () => setState(() => _digits = '') : null,
                      child: Center(
                        child: key == 'back'
                            ? Icon(Icons.backspace_outlined, size: 22, color: c.textSecondary)
                            : Text(key, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
