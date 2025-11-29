import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// 导入组件
import 'package:smart_rental_system/Compoents/animated_bottom_nav.dart';
import 'package:smart_rental_system/Compoents/user_info_card.dart';
import 'package:smart_rental_system/Screens/home_screen.dart';
// 导入屏幕
import 'package:smart_rental_system/Screens/login_screen.dart';
import 'package:smart_rental_system/Screens/tenant_bookings_screen.dart';

class TenantScreen extends StatefulWidget {
  const TenantScreen({super.key});

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _notificationStream; 

  int _currentNavIndex = 3; 

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
      _notificationStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid)
          .where('isReadByTenant', isEqualTo: false) 
          .snapshots();
    } else {
      // 防止初始化直接报错
      _userStream = const Stream.empty();
      _notificationStream = const Stream.empty();
    }
  }

  // 导航逻辑
  void _onNavTap(int index) {
    if (index == 0) { // Home
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 0)));
    } else if (index == 1) { // List
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 1)));
    } else if (index == 2) { // Favorites
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 2)));
    } else if (index == 3) { 
      // Current
    }
    if (mounted) setState(() => _currentNavIndex = index);
  }

  // 🔥 修复版退出登录：加延时，防报错，毛玻璃弹窗
  Future<void> _signOut(BuildContext context) async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.logout, color: Colors.white70, size: 40),
                  const SizedBox(height: 16),
                  const Text("Log Out", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Are you sure you want to exit?", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF5350)]),
                            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (didConfirm == true) {
      try {
        // 1. 先跳转销毁页面
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        // 2. 🔥 延时，等待 Stream 销毁
        await Future.delayed(const Duration(milliseconds: 300));
        
        // 3. 断开连接
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        print("Sign out error: $e");
      }
    }
  }

  void _navigateToBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TenantBookingsScreen()));
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
          StreamBuilder<QuerySnapshot>(
            stream: _notificationStream,
            builder: (context, snapshot) {
              // 🔥 屏蔽错误
              if (snapshot.hasError) return const SizedBox.shrink();
              
              int count = 0;
              if (snapshot.hasData) count = snapshot.data!.docs.length;
              
              return IconButton(
                onPressed: _navigateToBookings,
                icon: Badge(
                  label: Text(count.toString()),
                  isLabelVisible: count > 0,
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.notifications, color: Colors.white),
                ),
              );
            },
          ),
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
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. User Info Card
                StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, userSnapshot) {
                    // 🔥 屏蔽 Permission Denied
                    if (userSnapshot.hasError) {
                      if (userSnapshot.error.toString().contains("permission-denied")) return const SizedBox.shrink();
                      return const SizedBox.shrink();
                    }
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const UserInfoCard(name: 'Loading...', phone: '...', avatarUrl: null, pendingBookingCount: 0);
                    }
                    
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final String name = userData['name'] ?? 'Tenant';
                    final String phone = userData['phone'] ?? 'No Phone';
                    final String? avatarUrl = userData['avatarUrl'];

                    return StreamBuilder<QuerySnapshot>(
                      stream: _notificationStream,
                      builder: (context, notifSnapshot) {
                        // 🔥 屏蔽错误
                        if (notifSnapshot.hasError) return UserInfoCard(name: name, phone: phone, avatarUrl: avatarUrl, pendingBookingCount: 0, onNotificationTap: _navigateToBookings);

                        final int pendingCount = (notifSnapshot.hasData) ? notifSnapshot.data!.docs.length : 0;
                        return UserInfoCard(
                          name: name,
                          phone: phone,
                          avatarUrl: avatarUrl,
                          pendingBookingCount: pendingCount, 
                          onNotificationTap: _navigateToBookings, 
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 2. Dashboard Menu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("My Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 16),
                      
                      _buildDashboardButton(
                        context, 
                        icon: Icons.calendar_month_outlined, 
                        label: "My Bookings & Contracts", 
                        subLabel: "Check status, sign contracts",
                        color: const Color(0xFF00BFA5),
                        onTap: _navigateToBookings
                      ),
                      
                      const SizedBox(height: 12),

                      _buildDashboardButton(
                        context, 
                        icon: Icons.favorite_border, 
                        label: "Saved Properties", 
                        subLabel: "View your favorite listings",
                        color: Colors.pinkAccent,
                        onTap: () => _onNavTap(2) 
                      ),
                    ],
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
          BottomNavItem(icon: Icons.star, label: "Favorites"), 
          BottomNavItem(icon: Icons.person, label: "Account"),
        ],
      ),
    );
  }

  Widget _buildDashboardButton(BuildContext context, {required IconData icon, required String label, required String subLabel, required Color color, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}