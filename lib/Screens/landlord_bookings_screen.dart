import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ 引入你刚才修改好的紧凑版房东卡片
import '../Compoents/landlord_booking_card.dart'; 

class LandlordBookingsScreen extends StatelessWidget {
  const LandlordBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentLandlordUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Manage Bookings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. 全局背景 (深色极光渐变，保持应用风格统一)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF1F2E35)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // 2. 数据流
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('landlordUid', isEqualTo: currentLandlordUid)
                  .orderBy('meetingTime', descending: true) // ⚠️ 确保 Firestore 索引已创建
                  .snapshots(),
              builder: (context, snapshot) {
                // 加载中
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                // 无数据
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                // --- 🔥 核心分类逻辑 (房东视角) ---

                // 1. 需立即处理 (Action Required)
                // 包括: 新看房请求(pending)、新租房申请(application_pending)、租客已签等复签(tenant_signed)
                final actionList = docs.where((d) {
                  final s = d['status'];
                  return s == 'pending' || s == 'application_pending' || s == 'tenant_signed';
                }).toList();

                // 2. 等待租客 (Waiting)
                // 包括: 等租客签字(ready_to_sign)、等租客付款(awaiting_payment)
                final waitingList = docs.where((d) {
                  final s = d['status'];
                  return s == 'ready_to_sign' || s == 'awaiting_payment';
                }).toList();

                // 3. 待会面/活跃 (Upcoming)
                // 已批准看房，等待线下见面
                final activeList = docs.where((d) => d['status'] == 'approved').toList();

                // 4. 历史记录 (History)
                // 已拒绝、已完成、已取消
                final historyList = docs.where((d) {
                  final s = d['status'];
                  return s == 'rejected' || s == 'completed' || s == 'cancelled';
                }).toList();

                // 如果所有分类都为空 (防止空白)
                if (actionList.isEmpty && waitingList.isEmpty && activeList.isEmpty && historyList.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    // 分组 A: Action Required (橙色警示)
                    if (actionList.isNotEmpty)
                      _GlassSection(
                        title: "Action Required",
                        count: actionList.length,
                        icon: Icons.notification_important,
                        color: Colors.orangeAccent,
                        initiallyExpanded: true, // 默认展开，因为最重要
                        children: actionList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 分组 B: Waiting for Tenant (青色)
                    if (waitingList.isNotEmpty)
                      _GlassSection(
                        title: "Waiting for Tenant",
                        count: waitingList.length,
                        icon: Icons.hourglass_bottom,
                        color: Colors.cyanAccent,
                        initiallyExpanded: true,
                        children: waitingList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 分组 C: Upcoming Appointments (绿色)
                    if (activeList.isNotEmpty)
                      _GlassSection(
                        title: "Upcoming Appointments",
                        count: activeList.length,
                        icon: Icons.event_available,
                        color: const Color(0xFF69F0AE),
                        initiallyExpanded: actionList.isEmpty, // 如果没待办，就展开这个
                        children: activeList.map((doc) => _buildItem(doc)).toList(),
                      ),

                    // 分组 D: History (灰色，默认折叠)
                    if (historyList.isNotEmpty)
                      _GlassSection(
                        title: "History",
                        count: historyList.length,
                        icon: Icons.history,
                        color: Colors.grey,
                        initiallyExpanded: false,
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
    // 调用无折叠的紧凑卡片
    return LandlordBookingCard(
      bookingData: data,
      docId: doc.id,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in, size: 60, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 10),
          Text("No active bookings", style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ==============================================
// 🔥 毛玻璃折叠分组组件 (可复用)
// ==============================================
class _GlassSection extends StatefulWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _GlassSection({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<_GlassSection> createState() => _GlassSectionState();
}

class _GlassSectionState extends State<_GlassSection> with SingleTickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0), 
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              // 极淡的背景色区分分组
              color: widget.color.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.color.withOpacity(_isExpanded ? 0.3 : 0.1), 
                width: 1
              ),
            ),
            child: Column(
              children: [
                // Header (点击收缩/展开)
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: widget.color.withOpacity(0.2), shape: BoxShape.circle),
                          child: Icon(widget.icon, color: widget.color, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                          child: Text("${widget.count}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20),
                      ],
                    ),
                  ),
                ),
                // List Content
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: SizedBox(
                    width: double.infinity,
                    child: _isExpanded
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6), 
                            child: Column(children: widget.children),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}