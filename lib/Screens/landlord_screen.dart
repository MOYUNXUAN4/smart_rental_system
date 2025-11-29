import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// 导入组件
import 'package:smart_rental_system/Compoents/animated_bottom_nav.dart';
import 'package:smart_rental_system/Compoents/property_card.dart';
import 'package:smart_rental_system/Compoents/user_info_card.dart';
import 'package:smart_rental_system/Screens/home_screen.dart';
// 导入屏幕
import 'package:smart_rental_system/Screens/login_screen.dart';
import 'package:smart_rental_system/screens/add_property_screen.dart';
import 'package:smart_rental_system/screens/landlord_bookings_screen.dart';
import 'package:smart_rental_system/screens/landlord_inbox_screen.dart'; 

class LandlordScreen extends StatefulWidget {
  const LandlordScreen({super.key});

  @override
  State<LandlordScreen> createState() => _LandlordScreenState();
}

class _LandlordScreenState extends State<LandlordScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _propertiesStream;
  late Stream<QuerySnapshot> _bookingsStream; 

  int _currentNavIndex = 3; 

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
      _propertiesStream = FirebaseFirestore.instance
          .collection('properties')
          .where('landlordUid', isEqualTo: _uid)
          .snapshots(); 
      _bookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('landlordUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    } else {
      // 避免初始化时直接抛错
      _userStream = const Stream.empty();
      _propertiesStream = const Stream.empty();
      _bookingsStream = const Stream.empty();
    }
  }

  void _onNavTap(int index) {
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Landlord', initialIndex: 0)));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Landlord', initialIndex: 1)));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LandlordInboxScreen()));
    } else if (index == 3) {
      // Current
    }
    if (mounted) setState(() => _currentNavIndex = index);
  }

  // 🔥 修复版退出登录：加延时，防报错
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
                color: Colors.white.withOpacity(0.1), // 极淡背景
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
        // 1. 先跳转并清空栈 (销毁页面)
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        
        // 2. 🔥 关键修复：给页面一点时间销毁 Stream，然后再断开 Firebase
        await Future.delayed(const Duration(milliseconds: 300));

        // 3. 安全断开
        await FirebaseAuth.instance.signOut();
        
      } catch (e) {
        print("Sign out error: $e");
      }
    }
  }

  void _navigateToBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LandlordBookingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('Landlord Dashboard', style: TextStyle(color: Colors.white)),
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
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [ Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4) ],
              ),
            ),
          ),
          SafeArea(
            bottom: false, 
            child: Column( 
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                
                // 1. UserInfoCard
                StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, userSnapshot) {
                    // 🔥 屏蔽 Permission Denied 错误显示
                    if (userSnapshot.hasError) {
                      if (userSnapshot.error.toString().contains("permission-denied")) return const SizedBox.shrink();
                      return const SizedBox.shrink();
                    }
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const UserInfoCard(name: 'Loading...', phone: '...', avatarUrl: null, pendingBookingCount: 0);
                    }
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const UserInfoCard(name: 'User', phone: '', avatarUrl: null, pendingBookingCount: 0);
                    }
                    
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final String name = userData['name'] ?? 'Unknown Name';
                    final String phone = userData['phone'] ?? 'No Phone';
                    final String? avatarUrl = userData['avatarUrl'];

                    return StreamBuilder<QuerySnapshot>(
                      stream: _bookingsStream, 
                      builder: (context, bookingSnapshot) {
                        // 🔥 屏蔽错误
                        if (bookingSnapshot.hasError) return UserInfoCard(name: name, phone: phone, avatarUrl: avatarUrl, pendingBookingCount: 0, onNotificationTap: _navigateToBookings);
                        
                        final int pendingCount = (bookingSnapshot.hasData) ? bookingSnapshot.data!.docs.length : 0;
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
                
                // 2. Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    "My Properties",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),

                // 3. Property List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _propertiesStream,
                    builder: (context, snapshot) {
                      // 🔥 屏蔽 Permission Denied 错误显示 (防止退出时红屏)
                      if (snapshot.hasError) {
                         // 如果是权限错误，直接返回空，假装无事发生
                         if (snapshot.error.toString().contains("permission-denied")) {
                           return const SizedBox.shrink();
                         }
                         return const Center(child: Text("Error loading properties", style: TextStyle(color: Colors.white70)));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'You have no properties yet.\nTap the + button to add one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                          ),
                        );
                      }
                      
                      final properties = snapshot.data!.docs;
                      
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), 
                        itemCount: properties.length,
                        itemBuilder: (context, index) {
                          final doc = properties[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return PropertyCard(
                            propertyData: data,
                            propertyId: doc.id,
                            heroTagPrefix: 'landlord_list',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AddPropertyScreen(propertyId: doc.id)));
                            },
                          );
                        },
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
          BottomNavItem(icon: Icons.home, label: "Home Page"),
          BottomNavItem(icon: Icons.list, label: "List"),
          BottomNavItem(icon: Icons.inbox, label: "Inbox"), 
          BottomNavItem(icon: Icons.person, label: "My Account"),
        ],
      ),

      // 🔥 修复版 FAB: 使用 add_home_work 图标 + 半透明毛玻璃
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60), 
        child: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPropertyScreen()));
            },
            tooltip: 'Add Property',
            elevation: 0, // 去掉阴影
            backgroundColor: Colors.transparent, // 背景透明，交给 Child 渲染
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 模糊
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25), // 半透明白色背景
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5), // 白色描边
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: const Icon(
                    Icons.add_home_work, // 恢复原本的图标
                    color: Colors.white, 
                    size: 28
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}