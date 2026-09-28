import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/book.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

String storedDaysText(int days) => days <= 0 ? S.placedLockerToday : S.lockerP0Days(days);

String delistMessage(Book book) => book.isDeposited
    ? S.removedFromShopDepositedRetrieveBeforeRelisting(book.title)
    : S.removedFromShopBuyersNoLonger(book.title);

String _cabinetOf(Book book) => book.cabinetName.isEmpty ? S.faqCatCabinet : book.cabinetName;

Future<bool> confirmBookDeposit(BuildContext context, Book book) async {
  final title = book.title;
  final cabinet = _cabinetOf(book);
  final confirmed = await showConfirmDialog(
    context,
    title: S.dropOff,
    message: S.confirmP0BeenPlacedP1Once(title, cabinet),
    confirmLabel: S.dropOff,
    icon: Icons.inventory_2_outlined,
  );
  if (!confirmed || !context.mounted) return false;

  final error = await runBusy(context, () => ApiService().depositBook(book.bookId));
  if (!context.mounted) return true;
  if (error != null) {
    showAppSnackBar(context, error, isError: true);
  } else {
    HapticFeedback.lightImpact();
    showAppSnackBar(context, S.dropOffRegistered);
  }
  return true;
}

Future<bool> confirmBookRetrieval(BuildContext context, Book book) async {
  final title = book.title;
  final cabinet = _cabinetOf(book);
  final confirmed = await showConfirmDialog(
    context,
    title: S.retrieve,
    message: S.confirmRetrievedP1FromP0(cabinet, title),
    confirmLabel: S.retrieve,
    icon: Icons.outbox_outlined,
  );
  if (!confirmed || !context.mounted) return false;

  final result = await runBusy(context, () => ApiService().retrieveBook(book.bookId));
  if (!context.mounted || result == null) return true;
  final error = result.error;
  if (error != null) {
    showAppSnackBar(context, error, isError: true);
  } else {
    HapticFeedback.lightImpact();
    showAppSnackBar(context, result.restored ? S.retrievalReportedBookBackSale : S.retrievalReported);
  }
  return true;
}

Future<bool> confirmOrderDeposit(BuildContext context, Order order) async {
  final titles = [for (final item in order.items) item.book.title.isEmpty ? S.untitled : item.book.title];
  final multiple = titles.length > 1;
  final confirmed = await showConfirmDialog(
    context,
    title: S.markAsDroppedOff,
    message: multiple
        ? S.confirmPutAllP0BooksOrder(titles.length)
        : S.confirmPutLocker(order.firstBook?.title ?? S.untitled),
    items: multiple ? titles : const [],
    confirmLabel: S.droppedOff,
    icon: Icons.inventory_2_outlined,
  );
  if (!confirmed || !context.mounted) return false;

  final error = await runBusy(context, () => ApiService().updateOrderStatus(order.orderId, 'deposited'));
  if (!context.mounted) return true;
  if (error != null) {
    showAppSnackBar(context, error, isError: true);
  } else {
    HapticFeedback.lightImpact();
    showAppSnackBar(context, S.markedAsDroppedOff);
  }
  return true;
}

Future<bool> confirmInCabinetPurchase(BuildContext context, {bool fromCart = false}) => showConfirmDialog(
  context,
  title: S.confirmPurchase,
  message: fromCart ? S.ordersBooksAlreadyLockerReadyPickup : S.bookAlreadyLockerOrderReadyPickup,
  confirmLabel: S.payNow,
  cancelLabel: S.actionBack,
  icon: Icons.inventory_2_outlined,
);
