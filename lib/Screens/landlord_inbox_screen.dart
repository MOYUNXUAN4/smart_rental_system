import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Compoents/animated_bottom_nav.dart';
// ✅ 引入组件
import '../Compoents/booking_notification_card.dart';
import '../Compoents/meeting_card.dart'; // 👈 找回你的 Next Meeting Card
// 导入页面
import 'home_screen.dart';
import 'landlord_screen.dart';

class LandlordInboxScreen extends StatefulWidget {
  const LandlordInboxScreen({super.key});

  @override
  State<LandlordInboxScreen> createState() => _LandlordInboxScreenState();
}

class _LandlordInboxScreenState extends State<LandlordInboxScreen> {
  final String currentLandlordUid = FirebaseAuth.instance.currentUser!.uid;
  final int _currentNavIndex = 2; 

  late Stream<QuerySnapshot> _nextMeetingStream; // 👈 恢复 Next Meeting 流

  @override
  void initState() {
    super.initState();
    // 1. 初始化 Next Meeting 流 (只取最近的一条 approved)
    _nextMeetingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('landlordUid', isEqualTo: currentLandlordUid)
        .where('status', isEqualTo: 'approved')
        .where('meetingTime', isGreaterThan: Timestamp.now())
        .orderBy('meetingTime', descending: false)
        .limit(1)
        .snapshots();
  }

  void _onNavTap(int index) {
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Landlord', initialIndex: 0)));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Landlord', initialIndex: 1)));
    } else if (index == 2) {
      // Current
    } else if (index == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LandlordScreen()));
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': newStatus,
      'isReadByTenant': false, 
    });
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Marked as $newStatus")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Inbox Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // 1. 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. 🔥 顶部悬浮卡片 (Next Meeting Card) 🔥
                StreamBuilder<QuerySnapshot>(
                  stream: _nextMeetingStream,
                  builder: (context, snapshot) {
                    // 如果没有数据，或者出错，就不显示这个区域，保持布局整洁
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty || snapshot.hasError) {
                      return const SizedBox.shrink(); 
                    }
                    final nextBookingDoc = snapshot.data!.docs.first;
                    
                    // 包裹一层 Padding 让它好看点
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text("Next Meeting", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                          NextMeetingCard(bookingDoc: nextBookingDoc),
                        ],
                      ),
                    );
                  },
                ),

                // 3. 下方分类列表 (Expanded 填满剩余空间)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('landlordUid', isEqualTo: currentLandlordUid)
                        .orderBy('requestedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final docs = snapshot.data!.docs;

                      // --- 分类逻辑 ---
                      final newRequests = docs.where((d) => d['status'] == 'pending').toList();
                      final contractActions = docs.where((d) => d['status'] == 'application_pending' || d['status'] == 'tenant_signed').toList();
                      // 这里的 upcoming 可能会和顶部的 Next Meeting 重复，但作为列表查看也无妨
                      final upcoming = docs.where((d) => d['status'] == 'approved').toList();
                      final waiting = docs.where((d) => d['status'] == 'ready_to_sign' || d['status'] == 'awaiting_payment').toList();
                      final history = docs.where((d) => d['status'] == 'rejected' || d['status'] == 'completed' || d['status'] == 'cancelled').toList();

                      if (newRequests.isEmpty && contractActions.isEmpty && upcoming.isEmpty && waiting.isEmpty && history.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                        children: [
                          if (newRequests.isNotEmpty)
                            _GlassSection(
                              title: "New Viewing Requests",
                              count: newRequests.length,
                              icon: Icons.mark_email_unread,
                              color: Colors.orangeAccent,
                              initiallyExpanded: true,
                              children: newRequests.map((doc) => BookingNotificationCard(
                                bookingData: doc.data() as Map<String, dynamic>,
                                showActions: true, // 显示操作按钮
                                onApprove: () => _updateStatus(doc.id, 'approved'),
                                onReject: () => _updateStatus(doc.id, 'rejected'),
                              )).toList(),
                            ),

                          if (contractActions.isNotEmpty)
                            _GlassSection(
                              title: "Applications & Contracts",
                              count: contractActions.length,
                              icon: Icons.assignment_late,
                              color: const Color(0xFF29B6F6),
                              initiallyExpanded: true,
                              children: contractActions.map((doc) => BookingNotificationCard(
                                bookingData: doc.data() as Map<String, dynamic>,
                                showActions: false,
                              )).toList(),
                            ),

                          if (upcoming.isNotEmpty)
                            _GlassSection(
                              title: "All Upcoming Appointments",
                              count: upcoming.length,
                              icon: Icons.calendar_today,
                              color: const Color(0xFF69F0AE),
                              initiallyExpanded: newRequests.isEmpty,
                              children: upcoming.map((doc) => BookingNotificationCard(
                                bookingData: doc.data() as Map<String, dynamic>,
                                showActions: false,
                              )).toList(),
                            ),

                          if (waiting.isNotEmpty)
                            _GlassSection(
                              title: "Waiting for Tenant",
                              count: waiting.length,
                              icon: Icons.hourglass_bottom,
                              color: Colors.cyanAccent,
                              initiallyExpanded: false,
                              children: waiting.map((doc) => BookingNotificationCard(
                                bookingData: doc.data() as Map<String, dynamic>,
                                showActions: false,
                              )).toList(),
                            ),

                          if (history.isNotEmpty)
                            _GlassSection(
                              title: "History",
                              count: history.length,
                              icon: Icons.history,
                              color: Colors.grey,
                              initiallyExpanded: false,
                              children: history.map((doc) => BookingNotificationCard(
                                bookingData: doc.data() as Map<String, dynamic>,
                                showActions: false,
                              )).toList(),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavItem(icon: Icons.home, label: "Home"),
          BottomNavItem(icon: Icons.list, label: "List"),
          BottomNavItem(icon: Icons.inbox, label: "Inbox"), 
          BottomNavItem(icon: Icons.person, label: "Account"),
        ],
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
          Text("Inbox is empty", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
        ],
      ),
    );
  }
}

// ⚠️ 别忘了把 _GlassSection 和 _GlassSectionState 放在这下面，
// 就像之前的代码一样，确保它们在这个文件里。
// (为了节省篇幅，这里默认你已经有那个组件的代码了)
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
              color: widget.color.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.color.withOpacity(_isExpanded ? 0.3 : 0.1), 
                width: 1
              ),
            ),
            child: Column(
              children: [
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