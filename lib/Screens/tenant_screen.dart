import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ 需要引入时间格式化
// 导入组件
import 'package:smart_rental_system/Compoents/animated_bottom_nav.dart';
import 'package:smart_rental_system/Compoents/user_info_card.dart';
import 'package:smart_rental_system/Screens/home_screen.dart';
// 导入屏幕
import 'package:smart_rental_system/Screens/login_screen.dart';
import 'package:smart_rental_system/Screens/tenant_bookings_screen.dart';
// ✅ 导入支付服务
import 'package:smart_rental_system/Services/stripe_service.dart';

class TenantScreen extends StatefulWidget {
  const TenantScreen({super.key});

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _notificationStream; 
  late Stream<QuerySnapshot> _activeLeaseStream; // ✅ 新增：监听活跃租约

  int _currentNavIndex = 3; 
  bool _isPaying = false; // 控制支付加载状态

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
      
      // 通知流
      _notificationStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid)
          .where('isReadByTenant', isEqualTo: false) 
          .snapshots();

      // ✅ 活跃租约流 (只获取 status == completed)
      _activeLeaseStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'completed')
          .limit(1) // 假设同一时间主要展示一个活跃租约
          .snapshots();

    } else {
      _userStream = const Stream.empty();
      _notificationStream = const Stream.empty();
      _activeLeaseStream = const Stream.empty();
    }
  }

  // 导航逻辑
  void _onNavTap(int index) {
    if (index == 0) { 
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 0)));
    } else if (index == 1) { 
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 1)));
    } else if (index == 2) { 
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 2)));
    } else if (index == 3) { 
      // Current
    }
    if (mounted) setState(() => _currentNavIndex = index);
  }

  // 🔥 退出登录逻辑
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
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TenantBookingsScreen()));
  }

  // 🔥🔥🔥 新增：Dashboard 快速支付逻辑 🔥🔥🔥
  Future<void> _handleDashboardPayment(Map<String, dynamic> bookingData, String docId) async {
    setState(() => _isPaying = true);

    try {
      // 1. 获取价格 (逻辑同 TenantBookingCard)
      dynamic rawPrice = bookingData['price'] ?? bookingData['rent'] ?? bookingData['amount'];
      
      // 如果 booking 里没有价格，尝试去 properties 查 (为了 Dashboard 简洁，这里假设 booking 已经同步了价格)
      // 如果你的 booking 数据里确实没存 price，你需要在这里加一个 await FirebaseFirestore... 去查房源表的逻辑
      
      if (rawPrice == null) {
        throw Exception("Price info missing. Please check 'My Bookings' for details.");
      }

      String priceStr = rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '');
      double rentPrice = double.tryParse(priceStr) ?? 0.0;

      if (rentPrice <= 0.5) throw Exception("Invalid price");

      // 2. 发起支付
      bool success = await StripeService.instance.makePayment(rentPrice);

      if (success) {
        // ✅ 支付成功：更新状态并通知房东
        await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
          'paymentStatus': 'paid',     
          'paymentDate': FieldValue.serverTimestamp(),
          'isReadByLandlord': false, // 🔥 关键：这会给房东显示红点
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rent Paid Successfully! Landlord notified."), backgroundColor: Colors.green),
          );
        }
      } 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  // 计算下次交租日
  String _getNextPaymentDate(int paymentDay) {
    DateTime now = DateTime.now();
    DateTime targetDate = DateTime(now.year, now.month, paymentDay);
    if (now.day > paymentDay) {
      targetDate = DateTime(now.year, now.month + 1, paymentDay);
    }
    return DateFormat('dd MMM yyyy').format(targetDate);
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
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: SingleChildScrollView( // 允许滚动防止溢出
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. User Info Card
                  StreamBuilder<DocumentSnapshot>(
                    stream: _userStream,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasError) return const SizedBox.shrink();
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

                  // 🔥🔥 2. Current Active Lease (新功能) 🔥🔥
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _activeLeaseStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox.shrink(); // 没有活跃租约时不显示
                        }

                        final doc = snapshot.data!.docs.first;
                        final data = doc.data() as Map<String, dynamic>;
                        final String docId = doc.id;

                        // 计算数据
                        final Timestamp? start = data['leaseStartDate'];
                        final Timestamp? end = data['leaseEndDate'];
                        final int payDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;
                        final String nextPayDate = _getNextPaymentDate(payDay);
                        
                        // 获取房产名 (异步获取有点麻烦，为了UI流畅，这里简化显示或需要FutureBuilder)
                        // 这里我们用一个 FutureBuilder 简单获取房产名
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('properties').doc(data['propertyId']).get(),
                          builder: (context, propSnap) {
                            String propertyName = "My Rental Home";
                            if (propSnap.hasData && propSnap.data!.exists) {
                              propertyName = propSnap.data!.get('communityName') ?? "My Rental Home";
                            }

                            String leaseRange = "Unknown";
                            if (start != null && end != null) {
                              leaseRange = "${DateFormat('MMM yyyy').format(start.toDate())} - ${DateFormat('MMM yyyy').format(end.toDate())}";
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Current Lease", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 12),
                                _ActiveLeaseCard(
                                  propertyName: propertyName,
                                  leaseRange: leaseRange,
                                  nextPayDate: nextPayDate,
                                  rentAmount: data['price']?.toString() ?? '0',
                                  isPaying: _isPaying,
                                  onPayTap: () => _handleDashboardPayment(data, docId),
                                ),
                                const SizedBox(height: 24),
                              ],
                            );
                          }
                        );
                      },
                    ),
                  ),

                  // 3. Dashboard Menu
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

                        // 防止底部被导航栏遮挡
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
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

  // 🔥 专门为 Dashboard 设计的活跃租约卡片
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

// 🔥🔥🔥 新增组件：活跃租约卡片 (Dashboard 专用) 🔥🔥🔥
class _ActiveLeaseCard extends StatelessWidget {
  final String propertyName;
  final String leaseRange;
  final String nextPayDate;
  final String rentAmount;
  final bool isPaying;
  final VoidCallback onPayTap;

  const _ActiveLeaseCard({
    required this.propertyName,
    required this.leaseRange,
    required this.nextPayDate,
    required this.rentAmount,
    required this.isPaying,
    required this.onPayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 渐变背景，突出显示
        gradient: LinearGradient(
          colors: [const Color(0xFF00E676).withOpacity(0.2), const Color(0xFF00E676).withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 标题和图标
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(propertyName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Text("Active Lease", style: TextStyle(color: Color(0xFF69F0AE), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 2. 租期和交租日信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Lease Period", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(leaseRange, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Next Payment", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(nextPayDate, style: const TextStyle(color: Color(0xFF00E676), fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. 支付按钮 (允许提前付款)
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: isPaying ? null : onPayTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isPaying 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment, size: 18),
                      const SizedBox(width: 8),
                      Text("Pay Rent (RM $rentAmount)", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text("You can pay early anytime.", style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}