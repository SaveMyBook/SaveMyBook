import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../models/book.dart';
import '../../models/wallet.dart';
import '../../services/api_service.dart';
import '../../services/verification_service.dart';
import '../../widgets/state_views.dart';
import '../selling/book_deposit_actions.dart';
import 'widgets/payment_success_dialog.dart';

enum DirectPurchaseOutcome { aborted, failed, purchased, viewOrders }

typedef DirectPurchaseResult = ({DirectPurchaseOutcome outcome, bool readyForPickup});

const DirectPurchaseResult _aborted = (outcome: DirectPurchaseOutcome.aborted, readyForPickup: false);

Future<DirectPurchaseResult> purchaseBookDirectly(
  BuildContext context,
  Book book, {
  ValueChanged<bool>? onBusy,
  VoidCallback? onPaid,
}) async {
  final blocked = ApiService.authToken == null
      ? S.pleaseSignFirst
      : book.status != 'on_sale'
      ? S.bookCannotPurchased(book.statusText)
      : book.isReservedByOthers
      ? S.bookReservedAnotherBuyerCanT
      : null;
  if (blocked != null) {
    showAppSnackBar(context, blocked, isError: true);
    return _aborted;
  }

  HapticFeedback.lightImpact();
  onBusy?.call(true);
  final api = ApiService();
  final price = book.price;
  final wallet = await api.fetchWallet();
  if (!context.mounted) return _aborted;
  // 讀不到錢包時交由伺服器判斷餘額，避免誤報代幣不足。
  final known = !identical(wallet, Wallet.empty);
  if (known && wallet.balance < price) {
    onBusy?.call(false);
    showAppSnackBar(
      context,
      S.notEnoughCoinsOrderNeedsBut(price.toStringAsFixed(0), wallet.balance.toStringAsFixed(0)),
      isError: true,
    );
    return _aborted;
  }

  if (book.inCabinet) {
    final proceed = await confirmInCabinetPurchase(context);
    if (!context.mounted) return _aborted;
    if (!proceed) {
      onBusy?.call(false);
      return _aborted;
    }
  }

  VerificationService.paymentSummary = PaymentSummary(
    amount: price,
    detail:
        S.booksTotal(1, price.toStringAsFixed(0)) +
        (known ? S.balanceAfterPaymentCoins((wallet.balance - price).toStringAsFixed(0)) : ''),
  );
  final ({String? error, bool readyForPickup}) result;
  try {
    result = await api.buyNow(book.bookId);
  } finally {
    VerificationService.paymentSummary = null;
  }
  if (!context.mounted) return _aborted;
  onBusy?.call(false);

  final error = result.error;
  if (error != null) {
    if (error.isNotEmpty) showAppSnackBar(context, error, isError: true);
    return (outcome: DirectPurchaseOutcome.failed, readyForPickup: false);
  }

  HapticFeedback.heavyImpact();
  onPaid?.call();
  final viewOrders = await showPaymentSuccess(context, total: price, readyForPickup: result.readyForPickup);
  return (
    outcome: viewOrders == true ? DirectPurchaseOutcome.viewOrders : DirectPurchaseOutcome.purchased,
    readyForPickup: result.readyForPickup,
  );
}
