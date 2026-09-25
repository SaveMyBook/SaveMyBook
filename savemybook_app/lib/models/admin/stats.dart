import '../../utils/api_helpers.dart';
import '../../i18n/strings.dart';

class AdminOverview {
  final int memberCount;
  final int pendingReportCount;
  final int pendingListingReviewCount;
  final int openRiskAlertCount;
  final int pendingDisputeCount;
  final int activeCabinetCount;
  final int todayOrderCount;
  final int openTicketCount;

  AdminOverview({
    required this.memberCount,
    required this.pendingReportCount,
    this.pendingListingReviewCount = 0,
    this.openRiskAlertCount = 0,
    required this.pendingDisputeCount,
    required this.activeCabinetCount,
    required this.todayOrderCount,
    this.openTicketCount = 0,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      memberCount: parseInt(json['member_count']),
      pendingReportCount: parseInt(json['pending_report_count']),
      pendingListingReviewCount: parseInt(json['pending_listing_review_count']),
      openRiskAlertCount: parseInt(json['open_risk_alert_count']),
      pendingDisputeCount: parseInt(json['pending_dispute_count']),
      activeCabinetCount: parseInt(json['active_cabinet_count']),
      todayOrderCount: parseInt(json['today_order_count']),
      openTicketCount: parseInt(json['open_ticket_count']),
    );
  }

  static AdminOverview get empty => AdminOverview(
        memberCount: 0,
        pendingReportCount: 0,
        pendingDisputeCount: 0,
        activeCabinetCount: 0,
        todayOrderCount: 0,
      );

  /// 內容審核入口的待辦數：檢舉、上架審核與聊天防詐警示。
  int get pendingModerationCount => pendingReportCount + pendingListingReviewCount + openRiskAlertCount;
}

class AdminStatPoint {
  final String date;
  final int orders;
  final double revenue;
  final int newUsers;
  final int newBooks;

  AdminStatPoint({
    required this.date,
    required this.orders,
    required this.revenue,
    required this.newUsers,
    required this.newBooks,
  });

  factory AdminStatPoint.fromJson(Map<String, dynamic> json) {
    return AdminStatPoint(
      date: json['date'] as String? ?? '',
      orders: parseInt(json['orders']),
      revenue: parseDouble(json['revenue']),
      newUsers: parseInt(json['new_users']),
      newBooks: parseInt(json['new_books']),
    );
  }
}

class AdminStats {
  final int days;
  final List<AdminStatPoint> series;
  final int completedOrderCount;
  final double completedRevenue;
  final List<({String name, int count})> topCategories;

  AdminStats({
    required this.days,
    required this.series,
    required this.completedOrderCount,
    required this.completedRevenue,
    required this.topCategories,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      days: parseInt(json['days']),
      series: ((json['series'] as List?) ?? const [])
          .map((e) => AdminStatPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      completedOrderCount: parseInt(json['completed_order_count']),
      completedRevenue: parseDouble(json['completed_revenue']),
      topCategories: ((json['top_categories'] as List?) ?? const [])
          .map((e) => (
                name: (e as Map)['category_name'] as String? ?? S.uncategorised,
                count: parseInt(e['book_count']),
              ))
          .toList(),
    );
  }

  static AdminStats get empty => AdminStats(
        days: 7,
        series: const [],
        completedOrderCount: 0,
        completedRevenue: 0,
        topCategories: const [],
      );
}
