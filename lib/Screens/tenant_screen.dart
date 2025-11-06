// 在 lib/screens/ 目录下
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Compoents/animated_bottom_nav.dart';
import '../Compoents/user_info_card.dart'; 
import 'login_screen.dart'; 
import '../Services/account_check_screen.dart';
import 'home_screen.dart';
import 'tenant_bookings_screen.dart'; // 导入租客预约页面

class TenantScreen extends StatefulWidget {
  const TenantScreen({super.key});

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  late Stream<DocumentSnapshot> _userStream; 
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  int _currentNavIndex = 3; 
  late Stream<QuerySnapshot> _bookingsStream;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
      
      // ▼▼▼ 【逻辑修改】: 查询租客的“未读”通知 ▼▼▼
      _bookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid) // 属于我的
          .where('status', whereIn: ['approved', 'rejected']) // 且已被处理
          .where('isReadByTenant', isEqualTo: false) // 且我还没读过
          .snapshots();
      // ▲▲▲ 逻辑修改结束 ▲▲▲

    } else {
      _userStream = Stream.error("User not logged in");
      _bookingsStream = Stream.error("User not logged in"); 
    }
  }

  // 底边栏点击处理
  void _onNavTap(int index) {
    if (index == 0) { // Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 3) { // My Account
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
      );
    }
    setState(() {
      _currentNavIndex = index;
    });
  }

  // 退出函数
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
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  // 导航到租客预约页面
  void _navigateToTenantBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TenantBookingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true, 

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
          Container(
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
          ),

          SafeArea(
            bottom: false,
            // 嵌套 StreamBuilder
            child: StreamBuilder<DocumentSnapshot>(
              stream: _userStream, 
              builder: (context, userSnapshot) {
                // 加载中
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                // 错误
                if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: Text("Error: Could not load user data.", style: TextStyle(color: Colors.white70)));
                }

                // 获取用户信息
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final String name = userData['name'] ?? 'No Name';
                final String phone = userData['phone'] ?? 'No Phone';
                final String? avatarUrl = userData['avatarUrl'];

                // 内层 StreamBuilder 获取预约数量
                return StreamBuilder<QuerySnapshot>(
                  stream: _bookingsStream, // <-- 使用修改后的 Stream
                  builder: (context, bookingSnapshot) {
                    
                    // 计算未读数量
                    final int notificationCount = (bookingSnapshot.hasData)
                        ? bookingSnapshot.data!.docs.length
                        : 0;

                    // 返回 UI
                    return Column(
                      children: [
                        UserInfoCard(
                          name: name,
                          phone: phone,
                          avatarUrl: avatarUrl,
                          pendingBookingCount: notificationCount, // 传入未读数量
                          onNotificationTap: _navigateToTenantBookings, // 传入点击回调
                        ),
                        
                        Expanded(
                          child: Center(
                            child: Text(
                              'You have no rented properties yet.',
                              style: TextStyle(fontSize: 18, color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),

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