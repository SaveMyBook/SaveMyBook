import 'package:flutter/material.dart';
import '../models/order.dart';
import '../utils/app_colors.dart';

/// 取書完成的結果頁
class PickupSuccessScreen extends StatelessWidget {
  final Order? order;
  const PickupSuccessScreen({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final book = order?.firstBook;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 62, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text(
                '取書完成',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                book == null ? '感謝你的使用，祝閱讀愉快！' : '《${book.title}》已完成取書',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.5),
              ),
              if (order != null) ...[
                const SizedBox(height: 8),
                Text(
                  '訂單編號：${order!.orderNo}',
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('返回', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
