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
      print("Error marking as read: $e");
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

                // --- 房东端数据分类 ---
                
                // 1. Action Required (需要房东操作)
                final actionList = docs.where((d) => 
                    d['status'] == 'pending' || 
                    d['status'] == 'application_pending' || 
                    d['status'] == 'tenant_signed'
                ).toList();

                // 2. Waiting for Tenant (等租客操作)
                final waitingList = docs.where((d) => 
                    d['status'] == 'ready_to_sign' || 
                    d['status'] == 'awaiting_payment'
                ).toList();

                // 3. Upcoming (已批准，即将看房)
                final upcomingList = docs.where((d) => d['status'] == 'approved').toList();

                // 4. History (历史订单)
                final historyList = docs.where((d) => 
                    d['status'] == 'rejected' || 
                    d['status'] == 'completed' || 
                    d['status'] == 'cancelled'
                ).toList();

                if (actionList.isEmpty && waitingList.isEmpty && upcomingList.isEmpty && historyList.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    if (actionList.isNotEmpty)
                      _GlassSection(
                        title: "Action Required",
                        count: actionList.length,
                        icon: Icons.notification_important,
                        color: Colors.orangeAccent,
                        children: actionList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    if (waitingList.isNotEmpty)
                      _GlassSection(
                        title: "Waiting for Tenant",
                        count: waitingList.length,
                        icon: Icons.hourglass_top,
                        color: Colors.cyanAccent,
                        children: waitingList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    if (upcomingList.isNotEmpty)
                      _GlassSection(
                        title: "Upcoming Appointments",
                        count: upcomingList.length,
                        icon: Icons.calendar_today,
                        color: Colors.greenAccent,
                        children: upcomingList.map((doc) => _buildItem(doc)).toList(),
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

  // 🔥 核心修改：带有滑动撤销/删除逻辑的 Item 构建方法
  Widget _buildItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String status = data['status'] ?? '';
    final String docId = doc.id;
    
    // 获取请求状态
    final String? deletionRequest = data['deletionRequest'];
    final String? requestedBy = data['deletionRequestedBy'];

    // 定义历史订单 (可直接物理删除)
    bool isHistory = ['rejected', 'cancelled', 'completed'].contains(status);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart, // 从右向左滑动

      // 🎨 背景：历史单红色(删除)，进行单橙色(撤销)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        margin: const EdgeInsets.only(bottom: 10.0), // 与卡片 margin 保持一致
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
        // 1. 如果已有挂起的请求
        if (deletionRequest == 'pending') {
          if (requestedBy == 'landlord') {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request already sent. Waiting for tenant.")));
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tenant requested cancellation. Please check the card buttons.")));
          }
          return false;
        }

        // 2. 场景 A: 历史订单 -> 物理删除 (使用 Glass Dialog)
        if (isHistory) {
          return await showGlassConfirmDialog(
            context: context,
            title: "Delete Record?",
            content: "Are you sure you want to permanently delete this history? This action cannot be undone.",
            confirmBtnText: "Delete",
            icon: Icons.delete_forever,
            isDestructive: true, // 红色按钮
          );
        }

        // 3. 场景 B: 进行中订单 -> 发起撤销请求 (使用 Glass Dialog)
        bool? confirm = await showGlassConfirmDialog(
          context: context,
          title: "Request Cancellation?",
          content: "This booking is active. Do you want to request the TENANT to cancel and delete it?",
          confirmBtnText: "Send Request",
          icon: Icons.outgoing_mail,
          isDestructive: false, // 蓝色/橙色按钮
        );

        if (confirm == true) {
           // 🔥 标记：房东发起
           await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
             'deletionRequest': 'pending',
             'deletionRequestedBy': 'landlord'
           });
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent to Tenant.")));
           return false; // 不直接删除，返回 false
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
          Text("No bookings managed yet", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
        ],
      ),
    );
  }
}

// ----------------------------------------------
// 🔥 复用 _GlassSection 组件
// ----------------------------------------------
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