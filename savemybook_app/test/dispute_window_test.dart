import 'package:flutter_test/flutter_test.dart';
import 'package:savemybook_app/models/order.dart';

void main() {
  final now = DateTime(2026, 9, 16, 12);

  Order order({String status = 'deposited', DateTime? pickedUpAt, bool openDispute = false}) => Order(
        orderId: 1,
        orderNo: 'SMB1',
        totalAmount: 100,
        status: status,
        buyerId: 1,
        sellerId: 2,
        pickedUpAt: pickedUpAt,
        hasOpenDispute: openDispute,
      );

  test('取書後 24 小時內可提出爭議', () {
    expect(order(pickedUpAt: now.subtract(const Duration(hours: 23))).canOpenDispute(now: now), isTrue);
    expect(order(pickedUpAt: now.subtract(const Duration(hours: 24))).canOpenDispute(now: now), isTrue);
  });

  test('超過 24 小時不顯示申訴入口', () {
    expect(order(pickedUpAt: now.subtract(const Duration(hours: 24, minutes: 1))).canOpenDispute(now: now), isFalse);
  });

  test('已有處理中的爭議、已完成、已取消或已退款時不可再申訴', () {
    expect(order(pickedUpAt: now, openDispute: true).canOpenDispute(now: now), isFalse);
    expect(order(status: 'completed', pickedUpAt: now).canOpenDispute(now: now), isFalse);
    expect(order(status: 'cancelled').canOpenDispute(now: now), isFalse);
    expect(order(status: 'refunded').canOpenDispute(now: now), isFalse);
    expect(order(status: 'refunding').canOpenDispute(now: now), isFalse);
  });

  test('取書後待完成：可完成訂單，不可再取書或取消；存書前才可取消', () {
    final awaiting = order(pickedUpAt: now);
    expect(awaiting.awaitingConfirmation, isTrue);
    expect(awaiting.canCollect, isFalse);
    expect(awaiting.isCancellable, isFalse);
    expect(order().canCollect, isTrue);
    expect(order().isCancellable, isFalse, reason: '已存書不可取消');
    expect(order(status: 'pending_deposit').isCancellable, isTrue);
    expect(order(status: 'completed', pickedUpAt: now).awaitingConfirmation, isFalse);
  });

  test('取書前不受時限限制', () {
    expect(order(status: 'pending_deposit').canOpenDispute(now: now), isTrue);
  });

  test('解析訂單的取書與完成時間，且不再讀取取書碼', () {
    final parsed = Order.fromJson({
      'order_id': 1,
      'order_no': 'SMB1',
      'total_amount': '100',
      'status': 'completed',
      'buyer_id': 1,
      'seller_id': 2,
      'picked_up_at': '2026-09-16T01:00:00Z',
      'completed_at': '2026-09-16T01:05:00Z',
      'pickup_code': '123456',
    });
    expect(parsed.pickedUpAt, isNotNull);
    expect(parsed.completedAt, isNotNull);
  });
}
