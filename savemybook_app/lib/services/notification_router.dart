import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../screens/announcement_screen.dart';
import '../screens/book_detail_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/chat_room_screen.dart';
import '../screens/legal_doc_screen.dart';
import '../screens/member_level_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/security/security_center_screen.dart';
import '../screens/support_ticket_screen.dart';
import '../screens/wallet_screen.dart';
import 'api_service.dart';

class NotificationRouter {
  static const _noTarget = {'report', 'user', 'push_test'};

  static bool hasTarget(String? relatedType, int? relatedId) {
    if (relatedType == null || _noTarget.contains(relatedType)) return false;
    if (const {'wallet', 'member_level', 'password', 'security'}.contains(relatedType)) return true;
    return relatedId != null;
  }

  static Future<bool> open(NavigatorState navigator, {String? relatedType, int? relatedId}) async {
    final screen = await _screenFor(relatedType, relatedId);
    if (screen == null) return false;
    navigator.push(MaterialPageRoute(builder: (_) => screen));
    return true;
  }

  static Future<bool> openNotification(NavigatorState navigator, AppNotification n) =>
      open(navigator, relatedType: n.relatedType, relatedId: n.relatedId);

  static Future<Widget?> _screenFor(String? type, int? id) async {
    final api = ApiService();

    switch (type) {
      case 'wallet':
        return const WalletScreen();
      case 'member_level':
        return const MemberLevelScreen();
      case 'password':
        return const ChangePasswordScreen();
      case 'security':
        return const SecurityCenterScreen();
    }
    if (id == null) return null;

    switch (type) {
      case 'chat_room':
        return ChatRoomScreen(roomId: id);
      case 'ticket':
        return TicketDetailScreen(ticketId: id);
      case 'order':
        final order = await api.fetchOrderDetail(id);
        if (order == null) return null;
        return OrderDetailScreen(order: order, asSeller: order.sellerId == ApiService.currentUser?.userId);
      case 'book':
        final book = await api.fetchBookDetail(id);
        return book == null ? null : BookDetailScreen(book: book);
      case 'announcement':
        final announcement = await api.fetchAnnouncement(id);
        return announcement == null ? null : AnnouncementDetailScreen(announcement: announcement);
      case 'legal':
        final docs = await api.fetchLegalDocList();
        final doc = docs.where((d) => d.docId == id).firstOrNull;
        return doc == null ? null : LegalDocScreen(docKey: doc.key, fallbackTitle: doc.title);
    }
    return null;
  }
}
