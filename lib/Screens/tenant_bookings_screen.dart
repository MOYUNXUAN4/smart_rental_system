import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 引入卡片组件
import '../Compoents/tenant_booking_card.dart';

class TenantBookingsScreen extends StatefulWidget {
  const TenantBookingsScreen({super.key});

  @override
  State<TenantBookingsScreen> createState() => _TenantBookingsScreenState();
}

class _TenantBookingsScreenState extends State<TenantBookingsScreen> {
  
  @override
  void initState() {
    super.initState();
    // 页面初始化时，执行“标记已读”
    _markAllAsRead();
  }

  // 批量将该租客的所有未读消息标记为已读
  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: uid)
          .where('isReadByTenant', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isReadByTenant': true});
      }
      await batch.commit();
    } catch (e) {
      print("Error marking as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("My Bookings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF1F2E35)],
              ),
            ),
          ),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('tenantUid', isEqualTo: uid)
                  .orderBy('meetingTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                // --- 数据分类 ---
                final payList = docs.where((d) => d['status'] == 'awaiting_payment').toList();
                final signList = docs.where((d) => d['status'] == 'ready_to_sign' || d['status'] == 'tenant_signed').toList();
                final meetList = docs.where((d) => 
                    d['status'] == 'pending' || 
                    d['status'] == 'approved' || 
                    d['status'] == 'application_pending'
                ).toList();
                final historyList = docs.where((d) => 
                    d['status'] == 'rejected' || 
                    d['status'] == 'completed' || 
                    d['status'] == 'cancelled'
                ).toList();

                if (payList.isEmpty && signList.isEmpty && meetList.isEmpty && historyList.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    if (payList.isNotEmpty)
                      _GlassSection(
                        title: "Ready to Pay",
                        count: payList.length,
                        icon: Icons.payment,
                        color: const Color(0xFF00BFA5),
                        children: payList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    if (signList.isNotEmpty)
                      _GlassSection(
                        title: "Ready to Sign",
                        count: signList.length,
                        icon: Icons.edit_document,
                        color: const Color(0xFF29B6F6),
                        children: signList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    if (meetList.isNotEmpty)
                      _GlassSection(
                        title: "Active / To Meet",
                        count: meetList.length,
                        icon: Icons.calendar_today,
                        color: const Color(0xFFFFA726),
                        children: meetList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    if (historyList.isNotEmpty)
                      _GlassSection(
                        title: "History",
                        count: historyList.length,
                        icon: Icons.history,
                        color: Colors.grey,
                        children: historyList.map((doc) => _buildItem(doc)).toList(),
                      ),
                      
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TenantBookingCard(
      bookingData: data,
      docId: doc.id,
      statusColor: Colors.white, 
      statusIcon: Icons.circle,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text("No active bookings found", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
        ],
      ),
    );
  }
}

// ==============================================
// 🔥 纯展示型毛玻璃分组组件 (Stateless & No Folding)
// ==============================================
class _GlassSection extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _GlassSection({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0), // 增加间距，让分类更明显
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3), // 固定边框亮度
                width: 1
              ),
            ),
            child: Column(
              children: [
                // --- 1. 标题栏 (固定显示) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                        child: Text("$count", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      // ❌ 这里移除了箭头图标
                    ],
                  ),
                ),

                // --- 2. 分割线 (让标题和内容分开一点) ---
                Divider(height: 1, color: color.withOpacity(0.2)),

                // --- 3. 内容列表 (永远展开) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6), 
                  child: Column(children: children),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}