import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ⚠️ 请确保路径与你的项目一致（尤其是 Components 文件夹的拼写）
import '../Compoents/animated_bottom_nav.dart';
import '../Compoents/user_info_card.dart';
import '../Compoents/meeting_card.dart';        // ✅ 用于显示最近的会议特效卡片
import '../Compoents/tenant_booking_card.dart'; // ✅ 用于显示所有历史预约卡片（智能组件）
import 'home_screen.dart';
import 'login_screen.dart';
import 'tenant_bookings_screen.dart'; 

class TenantScreen extends StatefulWidget {
  const TenantScreen({super.key});

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  late Stream<DocumentSnapshot> _userStream;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final int _currentNavIndex = 3; // 当前高亮：My Account

  late Stream<QuerySnapshot> _notificationStream; // 仅用于计算红点数量
  late Stream<QuerySnapshot> _displayListStream;  // 用于展示所有历史列表
  late Stream<QuerySnapshot> _nextMeetingStream;  // 用于展示最近的一场会议

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();

      // 1. 通知流：只关心未读数 (approved/rejected 且未读)
      _notificationStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid)
          .where('status', whereIn: ['approved', 'rejected'])
          .where('isReadByTenant', isEqualTo: false)
          .snapshots();

      // 2. 列表流：展示该租客的所有预约
      _displayListStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid)
          // .orderBy('requestedAt', descending: true) // ⚠️ 如果报错需去 Firebase 控制台建索引
          .snapshots();

      // 3. 会议流：展示最近的一场已批准的会议 (Approved & Future)
      _nextMeetingStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'approved')
          .where('meetingTime', isGreaterThan: Timestamp.now())
          .orderBy('meetingTime', descending: false) // 最近的排前面
          .limit(1) // 只取 1 个
          .snapshots();

    } else {
      // 错误处理
      _userStream = Stream.error("User not logged in");
      _notificationStream = Stream.error("User not logged in");
      _displayListStream = Stream.error("User not logged in");
      _nextMeetingStream = Stream.error("User not logged in");
    }
  }

  // 导航逻辑
  void _onNavTap(int index) {
    if (index == _currentNavIndex) return;
    
    // 跳转回 HomeScreen 并切换 Tab
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          userRole: 'Tenant',
          initialIndex: index,
        ),
      ),
    );
  }

  // 退出登录
  Future<void> _signOut(BuildContext context) async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (didConfirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false
        );
      }
    }
  }

  // 点击红点时跳转到详情页
  void _navigateToTenantBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TenantBookingsScreen()),
    );
  }
  
  // 辅助：获取状态颜色
  Color _getStatusColor(String status) {
      switch (status) {
        case 'approved': return Colors.green;
        case 'rejected': return Colors.redAccent;
        case 'pending': return Colors.orangeAccent;
        case 'completed': return Colors.blueAccent;
        case 'application_pending': return Colors.purpleAccent; 
        default: return Colors.white70;
      }
  }

  // 辅助：获取状态图标
  IconData _getStatusIcon(String status) {
      switch (status) {
        case 'approved': return Icons.check_circle;
        case 'rejected': return Icons.cancel;
        case 'pending': return Icons.hourglass_top;
        case 'completed': return Icons.task_alt;
        case 'application_pending': return Icons.assignment_ind; 
        default: return Icons.info;
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      
      // 顶部 AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Tenant Dashboard', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _signOut(context),
          )
        ],
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 背景渐变
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
              ),
            ),
          ),

          // 2. 主体内容
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100), // 底部预留导航栏空间
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- A. 用户信息卡片 (UserInfoCard) ---
                  StreamBuilder<DocumentSnapshot>(
                    stream: _userStream,
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return const SizedBox(height: 100);
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;

                      return StreamBuilder<QuerySnapshot>(
                        stream: _notificationStream,
                        builder: (context, notifSnapshot) {
                          final int count = (notifSnapshot.hasData) ? notifSnapshot.data!.docs.length : 0;
                          return UserInfoCard(
                            name: userData['name'] ?? 'Tenant',
                            phone: userData['phone'] ?? '',
                            avatarUrl: userData['avatarUrl'],
                            pendingBookingCount: count,
                            onNotificationTap: _navigateToTenantBookings,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  // --- B. 最近的一场会议 (NextMeetingCard) ---
                  StreamBuilder<QuerySnapshot>(
                    stream: _nextMeetingStream,
                    builder: (context, snapshot) {
                      // 如果没有数据、或者列表为空，就不显示这个区域（直接隐身）
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty || snapshot.hasError) {
                        return const SizedBox.shrink(); 
                      }
                      
                      final nextBookingDoc = snapshot.data!.docs.first;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           const Text(
                            "Upcoming Meeting", // 标题
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          // ✅ 使用特效卡片组件
                          NextMeetingCard(bookingDoc: nextBookingDoc),
                          const SizedBox(height: 25),
                        ],
                      );
                    },
                  ),

                  // --- C. 所有历史预约列表 (TenantBookingCard) ---
                  const Text(
                    "All Appointments",
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white
                    ),
                  ),
                  const SizedBox(height: 15),

                  StreamBuilder<QuerySnapshot>(
                    stream: _displayListStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        // 空状态显示
                        return Container(
                          height: 100,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                             color: Colors.white.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(16)
                          ),
                          child: const Text("No history yet", style: TextStyle(color: Colors.white70)),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      
                      return ListView.builder(
                        shrinkWrap: true, // 关键：适应外层 ScrollView
                        physics: const NeverScrollableScrollPhysics(), // 禁用自身滚动
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id; // ✅ 获取 ID

                          // ✅ 使用智能组件 TenantBookingCard
                          return TenantBookingCard(
                            bookingData: data,
                            docId: docId, // 传进去，这样里面的按钮才能工作
                            statusColor: _getStatusColor(data['status'] ?? ''),
                            statusIcon: _getStatusIcon(data['status'] ?? ''),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // 底部导航栏
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        items: const [
           BottomNavItem(icon: Icons.home, label: "Home Page"),
           BottomNavItem(icon: Icons.list, label: "List"),
           BottomNavItem(icon: Icons.star, label: "Favorites"),
           BottomNavItem(icon: Icons.person, label: "My Account"),
        ],
      ),
    );
  }
}