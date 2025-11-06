// 在 lib/screens/ 目录下
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../Compoents/glass_card.dart'; // 复用你的 GlassCard

class TenantBookingsScreen extends StatefulWidget {
  const TenantBookingsScreen({super.key});

  @override
  State<TenantBookingsScreen> createState() => _TenantBookingsScreenState();
}

class _TenantBookingsScreenState extends State<TenantBookingsScreen> {
  final String currentTenantUid = FirebaseAuth.instance.currentUser!.uid;

  // ▼▼▼ 【逻辑修复】: 添加 initState 和 '标记已读' 功能 ▼▼▼
  @override
  void initState() {
    super.initState();
    _markBookingsAsRead(); // 页面加载时，立即标记所有通知为已读
  }

  Future<void> _markBookingsAsRead() async {
    // 1. 找到所有属于我、且未读的通知
    final query = FirebaseFirestore.instance
        .collection('bookings')
        .where('tenantUid', isEqualTo: currentTenantUid)
        .where('isReadByTenant', isEqualTo: false) // 找到未读的
        .where('status', whereIn: ['approved', 'rejected']); // 且是被处理过的

    final snapshot = await query.get();

    // 2. 使用一个 WriteBatch 批量更新它们，性能最高
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isReadByTenant': true}); // 标记为已读
    }
    
    // 3. 提交批量更新
    try {
      await batch.commit();
    } catch (e) {
      print("Error marking bookings as read: $e");
    }
  }
  // ▲▲▲ 逻辑修复结束 ▲▲▲

  // 根据状态获取颜色
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

  // 根据状态获取图标
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF153a44),
              Color(0xFF295a68),
              Color(0xFF5d8fa0),
              Color(0xFF94bac4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'My Booking Status',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // 查询所有属于该租客的预约
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('tenantUid', isEqualTo: currentTenantUid)
                      .orderBy('requestedAt', descending: true) // 按创建时间排序
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'You have not made any booking requests yet.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final bookingDoc = snapshot.data!.docs[index];
                        final bookingData = bookingDoc.data() as Map<String, dynamic>;
                        
                        return TenantBookingCard(
                          bookingData: bookingData,
                          statusColor: _getStatusColor(bookingData['status'] ?? ''),
                          statusIcon: _getStatusIcon(bookingData['status'] ?? ''),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 租客的预约卡片
class TenantBookingCard extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final Color statusColor;
  final IconData statusIcon;

  const TenantBookingCard({
    super.key,
    required this.bookingData,
    required this.statusColor,
    required this.statusIcon,
  });

  // 辅助方法：根据 ID 获取房产名称
  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown Property') : 'Unknown Property';
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String propertyId = bookingData['propertyId'];
    final Timestamp meetingTimestamp = bookingData['meetingTime'];
    final String meetingPoint = bookingData['meetingPoint'];
    final String status = bookingData['status'] ?? 'Unknown';
    final String formattedTime = DateFormat('dd/MM/yyyy, hh:mm a').format(meetingTimestamp.toDate());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. 房产名称
                Expanded(
                  child: FutureBuilder<String>(
                    future: _getPropertyName(propertyId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Loading property...',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                // 2. 状态
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white30, height: 16),
            
            // 3. 预约时间
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

            // 4. 预约地点
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meetingPoint,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}