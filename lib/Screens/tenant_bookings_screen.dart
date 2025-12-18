import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ 引入弹窗工具
import '../Compoents/glass_dialog_helper.dart';
// 引入租客卡片组件
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
      debugPrint("Error marking as read: $e");
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
          // 1. 极光背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF1F2E35)],
              ),
            ),
          ),

          // 2. 内容区域
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

                // --- 🔥 数据分类逻辑 (与房东端保持一致) ---
                
                // 1. Currently Rented (✅ 新增：已完成出租)
                final rentedList = docs.where((d) => d['status'] == 'completed').toList();

                // 2. Ready to Pay (待付款)
                final payList = docs.where((d) => d['status'] == 'awaiting_payment').toList();

                // 3. Ready to Sign (待签约)
                final signList = docs.where((d) => d['status'] == 'ready_to_sign' || d['status'] == 'tenant_signed').toList();

                // 4. Active / To Meet (申请中/待看房)
                final meetList = docs.where((d) => 
                    d['status'] == 'pending' || 
                    d['status'] == 'approved' || 
                    d['status'] == 'application_pending'
                ).toList();

                // 5. History (历史：拒绝/取消) 
                // ⚠️ 注意：completed 移到了 rentedList，这里不再包含
                final historyList = docs.where((d) => 
                    d['status'] == 'rejected' || 
                    d['status'] == 'cancelled'
                ).toList();

                if (rentedList.isEmpty && payList.isEmpty && signList.isEmpty && meetList.isEmpty && historyList.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    // ✅ 1. 当前租约 (最上方)
                    if (rentedList.isNotEmpty)
                      _GlassSection(
                        title: "Currently Rented",
                        count: rentedList.length,
                        icon: Icons.vpn_key,
                        color: const Color(0xFF00E676), // 亮绿色
                        children: rentedList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 2. 待付款
                    if (payList.isNotEmpty)
                      _GlassSection(
                        title: "Ready to Pay",
                        count: payList.length,
                        icon: Icons.payment,
                        color: const Color(0xFF00BFA5),
                        children: payList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 3. 待签约
                    if (signList.isNotEmpty)
                      _GlassSection(
                        title: "Ready to Sign",
                        count: signList.length,
                        icon: Icons.edit_document,
                        color: const Color(0xFF29B6F6),
                        children: signList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 4. 申请/看房
                    if (meetList.isNotEmpty)
                      _GlassSection(
                        title: "Active / To Meet",
                        count: meetList.length,
                        icon: Icons.calendar_today,
                        color: const Color(0xFFFFA726),
                        children: meetList.map((doc) => _buildItem(doc)).toList(),
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

  // 🔥 带有统一毛玻璃弹窗的 Item 构建方法
  Widget _buildItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String status = data['status'] ?? '';
    final String docId = doc.id;
    
    // 获取删除请求的状态
    final String? deletionRequest = data['deletionRequest'];
    final String? requestedBy = data['deletionRequestedBy'];

    // 定义历史订单 (rejected, cancelled)
    // ⚠️ completed 现在属于"活跃租约"，不能直接物理删除
    bool isHistory = ['rejected', 'cancelled'].contains(status);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart, // 从右向左滑动

      // --- 🎨 背景样式 ---
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        margin: const EdgeInsets.only(bottom: 10.0), 
        decoration: BoxDecoration(
          color: isHistory ? Colors.redAccent.withOpacity(0.8) : Colors.orangeAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isHistory ? Icons.delete_forever : Icons.undo, // 图标区分
          color: Colors.white, size: 28
        ),
      ),

      // --- 🤝 确认逻辑 ---
      confirmDismiss: (direction) async {
        // 1. 检查是否已经存在挂起的请求
        if (deletionRequest == 'pending') {
          if (requestedBy == 'tenant') {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You already requested cancellation. Waiting for landlord.")));
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Landlord requested cancellation. Please check the card buttons.")));
          }
          return false; // 禁止滑动
        }

        // 2. 场景 A: 历史订单 -> 物理删除弹窗
        if (isHistory) {
          return await showGlassConfirmDialog(
            context: context,
            title: "Delete History?",
            content: "Are you sure you want to permanently delete this record? This cannot be undone.",
            confirmBtnText: "Delete",
            icon: Icons.delete_forever,
            isDestructive: true, 
          );
        }

        // 3. 场景 B: 进行中/已出租订单 -> 发起撤销请求弹窗
        // 这里的文案修改为 "Terminate Lease" 更加贴切
        bool? confirm = await showGlassConfirmDialog(
          context: context,
          title: status == 'completed' ? "Terminate Lease?" : "Request Cancellation?",
          content: status == 'completed' 
              ? "Do you want to request early termination of your lease? The landlord will be notified."
              : "Order is active. Send a request to the Landlord to CANCEL this booking?",
          confirmBtnText: "Send Request",
          icon: Icons.outgoing_mail,
          isDestructive: false, 
        );

        if (confirm == true) {
          // 发起请求
          await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
            'deletionRequest': 'pending',
            'deletionRequestedBy': 'tenant' 
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancellation request sent.")));
          return false; // 不直接删除列表项
        }
        return false;
      },

      onDismissed: (direction) async {
        if (isHistory) {
          await FirebaseFirestore.instance.collection('bookings').doc(docId).delete();
        }
      },

      // 卡片组件
      child: TenantBookingCard(
        bookingData: data,
        docId: docId,
        // 这里传入默认颜色，实际颜色由 Card 内部根据 status 决定
        statusColor: Colors.white, 
        statusIcon: Icons.circle,
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
          Text("No active bookings found", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
        ],
      ),
    );
  }
}

// ==============================================
// 🔥 纯展示型毛玻璃分组组件 (复用)
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
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1
              ),
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