// 在 lib/Compoents/ 目录下创建新文件 booking_notification_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart'; // 确保 GlassCard 在 Compoents 目录中

class BookingNotificationCard extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  
  // ▼▼▼ 【新增】: 控制按钮是否显示 ▼▼▼
  final bool showActions; 
  // ▲▲▲ 【新增】 ▲▲▲

  const BookingNotificationCard({
    super.key,
    required this.bookingData,
    this.onApprove,
    this.onReject,
    this.showActions = false, // 默认不显示按钮
  });

  // 辅助方法：根据 ID 获取名称
  Future<String> _getDocName(String collection, String docId, String fieldName) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
      return doc.exists ? (doc.data()![fieldName] ?? 'Unknown') : 'Error';
    } catch (e) {
      return 'Error';
    }
  }

  // ▼▼▼ 【新增】: 获取状态的辅助方法 (从 tenant_bookings_screen 复制) ▼▼▼
  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
        return Colors.orangeAccent;
      default:
        return Colors.white70;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_top;
      default:
        return Icons.info;
    }
  }
  // ▲▲▲ 【新增】 ▲▲▲

  @override
  Widget build(BuildContext context) {
    final String tenantUid = bookingData['tenantUid'];
    final String propertyId = bookingData['propertyId'];
    final Timestamp meetingTimestamp = bookingData['meetingTime'];
    final String meetingPoint = bookingData['meetingPoint'];
    final String status = bookingData['status'] ?? 'unknown'; // 获取状态
    final String formattedTime = DateFormat('dd/MM/yyyy, hh:mm a').format(meetingTimestamp.toDate());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard( 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ▼▼▼ 【修改】: 标题行，现在包含状态 ▼▼▼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Booking Info",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(status), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ▲▲▲ 【修改】 ▲▲▲
            
            const Divider(color: Colors.white30, height: 16),
            
            // 房产名称
            Row(
              children: [
                const Icon(Icons.home_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                FutureBuilder<String>(
                  future: _getDocName('properties', propertyId, 'communityName'),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? 'Loading...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 房客名称
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                FutureBuilder<String>(
                  future: _getDocName('users', tenantUid, 'name'), 
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? 'Loading...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 预约时间
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  formattedTime,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 预约地点
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  meetingPoint,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            
            // ▼▼▼ 【修改】: 仅在 showActions 为 true 时显示按钮 ▼▼▼
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ]
            // ▲▲▲ 【修改】 ▲▲▲
          ],
        ),
      ),
    );
  }
}