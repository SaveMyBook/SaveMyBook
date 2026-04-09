import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _selectedCategory = '全部通知';
  final List<String> _categories = ['全部通知', '優惠通知', '訂單通知', '重要公告'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7ECEE),
      body: Column(
        children: [
          _buildHeader(),
          _buildCategoryFilter(),
          Expanded(
            child: _buildNotificationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 25,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF607D8B),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            const Text(
              '推播通知',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
            const SizedBox(width: 18),
            const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF607D8B) : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isSelected ? null : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF607D8B),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationList() {
    final List<Map<String, String>> notifications = [
      {
        'title': '訂單已完成',
        'content': '您的訂單 #BK10293 已經送達指定地點，請記得前往領取。',
        'time': '10 分鐘前',
        'type': '訂單通知',
        'icon': 'shopping_bag'
      },
      {
        'title': '限時優惠券',
        'content': '恭喜您獲得一張 50 元折價券，可用於全站書籍。',
        'time': '2 小時前',
        'type': '優惠通知',
        'icon': 'local_offer'
      },
      {
        'title': '系統維護公告',
        'content': '系統將於明日凌晨 02:00 - 04:00 進行維護，屆時將暫停服務。',
        'time': '5 小時前',
        'type': '重要公告',
        'icon': 'info'
      },
      {
        'title': '您追蹤的書籍已上架',
        'content': '「被討厭的勇氣」目前已有新賣家上架，快來看看吧！',
        'time': '昨天',
        'type': '全部通知',
        'icon': 'notifications'
      },
    ];

    final filteredNotifications = _selectedCategory == '全部通知'
        ? notifications
        : notifications.where((n) => n['type'] == _selectedCategory).toList();

    if (filteredNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('目前沒有相關通知', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredNotifications.length,
      itemBuilder: (context, index) {
        final item = filteredNotifications[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF607D8B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(item['icon']!), color: const Color(0xFF607D8B), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['title']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333)),
                        ),
                        Text(
                          item['time']!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['content']!,
                      style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'shopping_bag': return Icons.shopping_bag_outlined;
      case 'local_offer': return Icons.local_offer_outlined;
      case 'info': return Icons.info_outline;
      default: return Icons.notifications_none;
    }
  }
}
