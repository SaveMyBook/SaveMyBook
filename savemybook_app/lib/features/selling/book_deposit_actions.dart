import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../models/cabinet.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import '../cabinet/cabinet_entry.dart';
import '../orders/pickup_success_screen.dart';

String storedDaysText(int days) => days <= 0 ? S.placedLockerToday : S.lockerP0Days(days);

String delistMessage(Book book) {
  final title = book.title;
  if (!book.isDeposited && !book.canRetrieve) return S.removedFromShopBuyersNoLonger(title);
  if (book.retrievalAccess?.isScan == true) return S.onceDelistedP0NoLongerAppear(title);
  return S.onceDelistedP0NoLongerAppear2(title);
}

String _cabinetOf(Book book) => book.cabinetName.isEmpty ? S.faqCatCabinet : book.cabinetName;

Future<bool> confirmBookDeposit(BuildContext context, Book book) {
  return runCabinetAction(
    context,
    action: CabinetAction.preDeposit,
    access: book.cabinetAccess,
    target: CabinetContext.book(book.bookId),
    manual: (notice) => reportCabinetManually(
      context,
      title: S.dropOff,
      message: S.confirmP0BeenPlacedP1(book.title, _cabinetOf(book)),
      confirmLabel: S.dropOff,
      icon: Icons.inventory_2_outlined,
      notice: notice,
      target: CabinetContext.book(book.bookId),
      send: () => ApiService().reportBookDepositManually(book.bookId),
    ),
  );
}

Future<bool> confirmBookRetrieval(BuildContext context, Book book) async {
  final location = book.cabinetLocation;
  final cabinet = location != null && location.cabinetName.isNotEmpty ? location.cabinetName : _cabinetOf(book);
  final access = book.retrievalAccess;
  if (!book.isDeposited && access?.isScan != true && CabinetMessages.precheck(access, CabinetAction.retrieve) == null) {
    showAppSnackBar(context, CabinetMessages.retrievalUnavailable(access), isError: true);
    return false;
  }
  return runCabinetAction(
    context,
    action: CabinetAction.retrieve,
    access: access,
    target: CabinetContext.book(book.bookId),
    manual: (notice) => reportCabinetManually(
      context,
      title: S.retrieve,
      message: S.confirmRetrievedP1FromP0(cabinet, book.title),
      confirmLabel: S.retrieve,
      icon: Icons.outbox_outlined,
      notice: notice,
      target: CabinetContext.book(book.bookId),
      send: () => ApiService().reportBookRetrievalManually(book.bookId),
    ),
  );
}

Future<bool> confirmOrderDeposit(BuildContext context, Order order) {
  final titles = [for (final item in order.items) item.book.title.isEmpty ? S.untitled : item.book.title];
  final multiple = titles.length > 1;
  return runCabinetAction(
    context,
    action: CabinetAction.orderDeposit,
    access: order.cabinetAccess,
    target: CabinetContext.order(order.orderId),
    orderDoors: order.items.every((item) => item.preDeposited) ? order.doors : const [],
    manual: (notice) => reportCabinetManually(
      context,
      title: S.markAsDroppedOff,
      message: multiple
          ? S.confirmPutAllP0BooksOrder(titles.length)
          : S.confirmPutLocker(order.firstBook?.title ?? S.untitled),
      items: multiple ? titles : const [],
      confirmLabel: S.droppedOff,
      icon: Icons.inventory_2_outlined,
      notice: notice,
      target: CabinetContext.order(order.orderId),
      send: () => ApiService().reportOrderManually(order.orderId, 'deposited'),
      onApplied: (_) async {
        if (context.mounted) showAppSnackBar(context, S.markedAsDroppedOff);
      },
    ),
  );
}

Future<bool> confirmOrderPickup(BuildContext context, Order order) {
  return runCabinetAction(
    context,
    action: CabinetAction.pickup,
    access: order.cabinetAccess,
    target: CabinetContext.order(order.orderId),
    manual: (notice) => reportCabinetManually(
      context,
      title: S.iCollected,
      message: notice == null ? S.confirmVeTakenBookFromLocker : S.confirmTakenBookFromLocker,
      confirmLabel: S.confirm,
      icon: Icons.inventory_2_outlined,
      notice: notice,
      target: CabinetContext.order(order.orderId),
      send: () => ApiService().reportOrderManually(order.orderId, 'picked_up'),
      onApplied: (_) async {
        if (!context.mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => PickupSuccessScreen(order: order)));
      },
    ),
  );
}

Future<bool> confirmInCabinetPurchase(BuildContext context, {bool fromCart = false}) => showConfirmDialog(
  context,
  title: S.confirmPurchase,
  message: fromCart ? S.ordersBooksAlreadyLockerReadyPickup : S.bookAlreadyLockerOrderReadyPickup,
  confirmLabel: S.payNow,
  cancelLabel: S.actionBack,
  icon: Icons.inventory_2_outlined,
);
