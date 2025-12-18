import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ 引入通用毛玻璃弹窗工具
import '../Compoents/glass_dialog_helper.dart';
// 引入房东版卡片组件
import '../Compoents/landlord_booking_card.dart'; 

class LandlordBookingsScreen extends StatefulWidget {
  const LandlordBookingsScreen({super.key});

  @override
  State<LandlordBookingsScreen> createState() => _LandlordBookingsScreenState();
}

class _LandlordBookingsScreenState extends State<LandlordBookingsScreen> {
  
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  // 批量标记已读
  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('landlordUid', isEqualTo: uid)
          .where('isReadByLandlord', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isReadByLandlord': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Bookings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. 极光背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF1F2E35)],
              ),
            ),
          ),

          // 2. 内容列表
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('landlordUid', isEqualTo: uid)
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

                // --- 🔥 房东端数据分类 (新逻辑) ---
                
                // 1. Currently Rented (✅ 新增：已完成出租)
                final rentedList = docs.where((d) => d['status'] == 'completed').toList();

                // 2. Action Required (需要房东操作)
                final actionList = docs.where((d) => 
                    d['status'] == 'pending' || 
                    d['status'] == 'application_pending' || 
                    d['status'] == 'tenant_signed'
                ).toList();

                // 3. Waiting for Tenant (等租客操作)
                final waitingList = docs.where((d) => 
                    d['status'] == 'ready_to_sign' || 
                    d['status'] == 'awaiting_payment'
                ).toList();

                // 4. Upcoming (已批准，即将看房)
                final upcomingList = docs.where((d) => d['status'] == 'approved').toList();

                // 5. History (历史订单：已拒绝或已取消)
                // 注意：completed 移到了 rentedList，这里不再包含 completed
                final historyList = docs.where((d) => 
                    d['status'] == 'rejected' || 
                    d['status'] == 'cancelled'
                ).toList();

                if (rentedList.isEmpty && actionList.isEmpty && waitingList.isEmpty && upcomingList.isEmpty && historyList.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    // ✅ 1. 当前出租中 (最重要，放最上面)
                    if (rentedList.isNotEmpty)
                      _GlassSection(
                        title: "Currently Rented",
                        count: rentedList.length,
                        icon: Icons.vpn_key, // 钥匙图标
                        color: const Color(0xFF00E676), // 亮绿色
                        children: rentedList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 2. 需要操作
                    if (actionList.isNotEmpty)
                      _GlassSection(
                        title: "Action Required",
                        count: actionList.length,
                        icon: Icons.notification_important,
                        color: Colors.orangeAccent,
                        children: actionList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 3. 等待租客
                    if (waitingList.isNotEmpty)
                      _GlassSection(
                        title: "Waiting for Tenant",
                        count: waitingList.length,
                        icon: Icons.hourglass_top,
                        color: Colors.cyanAccent,
                        children: waitingList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 4. 即将看房
                    if (upcomingList.isNotEmpty)
                      _GlassSection(
                        title: "Upcoming Appointments",
                        count: upcomingList.length,
                        icon: Icons.calendar_today,
                        color: Colors.blueAccent,
                        children: upcomingList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 5. 历史记录
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

  // 🔥 Item 构建方法
  Widget _buildItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String status = data['status'] ?? '';
    final String docId = doc.id;
    
    final String? deletionRequest = data['deletionRequest'];
    final String? requestedBy = data['deletionRequestedBy'];

    // 历史订单定义 (rejected, cancelled)
    // 注意：completed 现在算作 "活跃租约"，不能直接物理删除，只能走撤销流程
    bool isHistory = ['rejected', 'cancelled'].contains(status);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart, 

      // 🎨 背景
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        margin: const EdgeInsets.only(bottom: 10.0),
        decoration: BoxDecoration(
          color: isHistory ? Colors.redAccent.withOpacity(0.8) : Colors.orangeAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isHistory ? Icons.delete_forever : Icons.undo,
          color: Colors.white, size: 28
        ),
      ),

      // 🤝 确认逻辑
      confirmDismiss: (direction) async {
        if (deletionRequest == 'pending') {
          if (requestedBy == 'landlord') {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request already sent. Waiting for tenant.")));
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tenant requested cancellation. Please check the card buttons.")));
          }
          return false;
        }

        // A: 历史订单 -> 物理删除
        if (isHistory) {
          return await showGlassConfirmDialog(
            context: context,
            title: "Delete Record?",
            content: "Permanently delete this history?",
            confirmBtnText: "Delete",
            icon: Icons.delete_forever,
            isDestructive: true,
          );
        }

        // B: 进行中/已出租订单 -> 发起撤销请求
        bool? confirm = await showGlassConfirmDialog(
          context: context,
          title: "Terminate Booking?",
          content: "Do you want to request the TENANT to cancel this booking/lease?",
          confirmBtnText: "Send Request",
          icon: Icons.outgoing_mail,
          isDestructive: false,
        );

        if (confirm == true) {
           await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
             'deletionRequest': 'pending',
             'deletionRequestedBy': 'landlord'
           });
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent to Tenant.")));
           return false; 
        }
        return false;
      },

      onDismissed: (direction) async {
        if (isHistory) await FirebaseFirestore.instance.collection('bookings').doc(docId).delete();
      },

      child: LandlordBookingCard(
        bookingData: data,
        docId: docId,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text("No bookings yet", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
        ],
      ),
    );
  }
}

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
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
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
                    ],
                  ),
                ),
                Divider(height: 1, color: color.withOpacity(0.2)),
                Padding(
                  padding: const EdgeInsets.all(6), 
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