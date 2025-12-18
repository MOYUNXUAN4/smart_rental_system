import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ 需要引入
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
  late Stream<QuerySnapshot> _rentedStream; // ✅ 新增：监听已出租订单

  int _currentNavIndex = 3; 
  bool _isRentedExpanded = false; // ✅ 控制折叠状态 (默认 false = 折叠)

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
      _propertiesStream = FirebaseFirestore.instance
          .collection('properties')
          .where('landlordUid', isEqualTo: _uid)
          .snapshots(); 
      
      // 未读消息/待处理红点流
      _bookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('landlordUid', isEqualTo: _uid)
          .where('isReadByLandlord', isEqualTo: false) // 只要有未读就提示
          .snapshots();

      // ✅ 活跃租约流 (status == completed)
      _rentedStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('landlordUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'completed')
          .snapshots();

    } else {
      _userStream = const Stream.empty();
      _propertiesStream = const Stream.empty();
      _bookingsStream = const Stream.empty();
      _rentedStream = const Stream.empty();
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

  // 退出登录
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
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        await Future.delayed(const Duration(milliseconds: 300));
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        print("Sign out error: $e");
      }
    }
  }

  void _navigateToBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LandlordBookingsScreen()));
  }

  // 🔥 计算下次收租日
  String _getNextPaymentDate(int paymentDay) {
    DateTime now = DateTime.now();
    DateTime targetDate = DateTime(now.year, now.month, paymentDay);
    if (now.day > paymentDay) {
      targetDate = DateTime(now.year, now.month + 1, paymentDay);
    }
    return DateFormat('dd MMM').format(targetDate);
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
          // 消息通知按钮
          StreamBuilder<QuerySnapshot>(
            stream: _bookingsStream,
            builder: (context, snapshot) {
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
          // 背景
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
                    if (userSnapshot.hasError) {
                      if (userSnapshot.error.toString().contains("permission-denied")) return const SizedBox.shrink();
                      return const SizedBox.shrink();
                    }
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const UserInfoCard(name: 'Loading...', phone: '...', avatarUrl: null, pendingBookingCount: 0);
                    }
                    
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final String name = userData['name'] ?? 'Landlord';
                    final String phone = userData['phone'] ?? 'No Phone';
                    final String? avatarUrl = userData['avatarUrl'];

                    return StreamBuilder<QuerySnapshot>(
                      stream: _bookingsStream, 
                      builder: (context, bookingSnapshot) {
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
                
                // 🔥🔥🔥 2. Active Leases Section (新增：默认折叠) 🔥🔥🔥
                StreamBuilder<QuerySnapshot>(
                  stream: _rentedStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink(); 
                    }
                    
                    final rentedDocs = snapshot.data!.docs;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2.1 标题栏 + 折叠按钮
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isRentedExpanded = !_isRentedExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                const Text(
                                  "Active Leases",
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${rentedDocs.length}", 
                                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _isRentedExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 2.2 折叠内容 (紧凑型列表)
                        AnimatedCrossFade(
                          firstChild: const SizedBox(width: double.infinity), // 折叠时高度为0
                          secondChild: Container(
                            constraints: const BoxConstraints(maxHeight: 220), // 限制展开高度，防止占满屏幕
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: rentedDocs.length,
                              itemBuilder: (context, index) {
                                final data = rentedDocs[index].data() as Map<String, dynamic>;
                                
                                // 获取数据
                                final int payDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;
                                final String nextDate = _getNextPaymentDate(payDay);
                                final String propertyId = data['propertyId'];
                                final String tenantUid = data['tenantUid'];

                                return _CompactRentedCard(
                                  propertyId: propertyId,
                                  tenantUid: tenantUid,
                                  nextDate: nextDate,
                                  onTap: _navigateToBookings, // 点击去管理页
                                );
                              },
                            ),
                          ),
                          crossFadeState: _isRentedExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    );
                  }
                ),

                // 3. Title (My Properties)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    "My Properties",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),

                // 4. Property List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _propertiesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
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
            elevation: 0,
            backgroundColor: Colors.transparent, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: const Icon(Icons.add_home_work, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥🔥🔥 新增：紧凑型租约卡片 (Dashboard 专用) 🔥🔥🔥
class _CompactRentedCard extends StatelessWidget {
  final String propertyId;
  final String tenantUid;
  final String nextDate;
  final VoidCallback onTap;

  const _CompactRentedCard({
    required this.propertyId,
    required this.tenantUid,
    required this.nextDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.1), // 绿色背景
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 图标
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.vpn_key, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 房产名
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('properties').doc(propertyId).get(),
                        builder: (context, snapshot) {
                          String name = "...";
                          if (snapshot.hasData && snapshot.data!.exists) {
                            name = snapshot.data!.get('communityName') ?? "Property";
                          }
                          return Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis);
                        },
                      ),
                      const SizedBox(height: 2),
                      // 租客名
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(tenantUid).get(),
                        builder: (context, snapshot) {
                          String name = "...";
                          if (snapshot.hasData && snapshot.data!.exists) {
                            name = snapshot.data!.get('name') ?? "Tenant";
                          }
                          return Text("Tenant: $name", style: const TextStyle(color: Colors.white70, fontSize: 11));
                        },
                      ),
                    ],
                  ),
                ),
                
                // 收租日
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Next Rent", style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(nextDate, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}