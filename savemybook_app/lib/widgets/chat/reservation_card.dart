import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.dart';
import '../../models/chat.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../app_tiles.dart';
import '../state_views.dart';
import 'chat_format.dart';

enum ReservationAction { accept, decline, cancel, buy }

class ReservationCardView extends StatelessWidget {
  final ChatReservation reservation;
  final int myId;
  final bool busy;
  final ValueChanged<ReservationAction> onAction;
  final VoidCallback? onOpenBook;

  const ReservationCardView({
    super.key,
    required this.reservation,
    required this.myId,
    required this.onAction,
    this.busy = false,
    this.onOpenBook,
  });

  bool get _pendingExpired {
    final created = reservation.createdAt;
    return reservation.isPending && created != null && DateTime.now().difference(created) > const Duration(hours: 24);
  }

  (String, Color, IconData) _status(AppColors c) {
    final r = reservation;
    if (r.isPending) {
      if (_pendingExpired) return (S.expired, c.neutral, Icons.hourglass_disabled_rounded);
      return (S.awaitingReply, c.warning, Icons.schedule_rounded);
    }
    if (r.status == 'confirmed') {
      final deadline = r.pickupDeadline;
      if (r.isHolding && deadline != null) {
        final label = chatDeadline(deadline);
        return (S.heldUntilP0(label), c.success, Icons.lock_clock_rounded);
      }
      return (S.expired, c.neutral, Icons.hourglass_disabled_rounded);
    }
    if (r.status == 'cancelled') {
      if (r.closedAction == 'decline' || (r.closedAction == null && r.closedBy == 'seller' && r.pickupDeadline == null)) return (S.declined2, c.danger, Icons.block_rounded);
      return (S.orderCancelled, c.neutral, Icons.cancel_outlined);
    }
    if (r.status == 'expired') return (S.expired, c.neutral, Icons.hourglass_disabled_rounded);
    return (S.closed, c.neutral, Icons.check_circle_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final r = reservation;
    final isSeller = r.sellerId == myId;
    final isBuyer = r.buyerId == myId;
    final (label, tint, icon) = _status(c);
    final active = (r.isPending && !_pendingExpired) || r.isConfirmed;
    final width = MediaQuery.sizeOf(context).width;

    final actions = <Widget>[];
    if (!_pendingExpired && r.isPending && isSeller) {
      actions.add(_ActionButton(label: S.decline2, onTap: () => onAction(ReservationAction.decline), tone: _Tone.outline));
      actions.add(_ActionButton(label: S.accept, onTap: () => onAction(ReservationAction.accept), tone: _Tone.primary));
    } else if (!_pendingExpired && r.isPending && isBuyer) {
      actions.add(_ActionButton(label: S.cancelReservation2, onTap: () => onAction(ReservationAction.cancel), tone: _Tone.outline));
    } else if (r.isConfirmed) {
      actions.add(_ActionButton(label: S.cancelReservation2, onTap: () => onAction(ReservationAction.cancel), tone: _Tone.outline));
      if (isBuyer) {
        actions.add(_ActionButton(label: S.buyNow, onTap: () => onAction(ReservationAction.buy), tone: _Tone.primary));
      }
    }

    final heading = isSeller ? S.theyWantReserveBook : S.sentReservationRequest;
    final hoursText = S.holdP0H(r.hours);
    final note = r.message?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.min(width * 0.86, 380)),
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.standard,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? tint.withValues(alpha: 0.45) : c.border, width: active ? 1.2 : 1),
              boxShadow: [
                BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: c.isDark ? 0.14 : 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, size: 16, color: c.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: Motion.base,
                          child: Row(
                            key: ValueKey(label),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 13, color: tint),
                              const SizedBox(width: 3),
                              Flexible(child: StatusBadge(label: label, color: tint)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onOpenBook,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Row(
                      children: [
                        BookThumbnail(imageUrl: r.bookImageUrl, width: 50, height: 68, radius: 10),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                r.bookTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '\$${r.bookPrice.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accent),
                                  ),
                                  if (r.hours > 0)
                                    Text(hoursText, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded, size: 14, color: c.textHint),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                AnimatedSize(
                  duration: Motion.base,
                  curve: Motion.standard,
                  child: actions.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: busy
                              ? SizedBox(
                                  height: 40,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: c.accent),
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    for (var i = 0; i < actions.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      Expanded(child: actions[i]),
                                    ],
                                  ],
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
}

enum _Tone { primary, outline }

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _Tone tone;

  const _ActionButton({required this.label, required this.onTap, required this.tone});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final primary = tone == _Tone.primary;
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        style: TextButton.styleFrom(
          backgroundColor: primary ? chatMineBubble(c) : c.inputFill,
          foregroundColor: primary ? Colors.white : c.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class ReservationRequest {
  final int hours;
  final String note;

  const ReservationRequest(this.hours, this.note);
}

Future<ReservationRequest?> showReservationRequestSheet(
  BuildContext context, {
  required String title,
  required double price,
  String? imageUrl,
}) {
  final c = AppColors.of(context);
  return showModalBottomSheet<ReservationRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.sheetBg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ReservationSheet(title: title, price: price, imageUrl: imageUrl),
  );
}

class _ReservationSheet extends StatefulWidget {
  final String title;
  final double price;
  final String? imageUrl;

  const _ReservationSheet({required this.title, required this.price, this.imageUrl});

  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  final TextEditingController _note = TextEditingController();
  int _hours = 24;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              const SizedBox(height: 16),
              Text(
                S.reserveBook,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                S.onceSellerAcceptsBookHeldNo,
                style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    BookThumbnail(imageUrl: widget.imageUrl, width: 44, height: 60, radius: 8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${widget.price.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                S.holdPeriod,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final h in const [24, 48, 72]) ...[
                    if (h != 24) const SizedBox(width: 10),
                    Expanded(child: _hourOption(c, h)),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _note,
                maxLength: 200,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: S.messageSellerOptional,
                  hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                  filled: true,
                  fillColor: c.inputFill,
                  counterStyle: TextStyle(color: c.textHint, fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, ReservationRequest(_hours, _note.text.trim()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: chatMineBubble(c),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    S.sendRequest,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.actionCancel, style: TextStyle(color: c.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hourOption(AppColors c, int hours) {
    final selected = _hours == hours;
    final label = S.p0Hours(hours);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _hours = hours);
      },
      child: AnimatedContainer(
        duration: Motion.micro,
        curve: Motion.standard,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : c.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? c.accent : Colors.transparent, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? c.accent : c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
