import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  
  // 数据流
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _propertiesStream;
  late Stream<QuerySnapshot> _bookingsStream; 
  late Stream<QuerySnapshot> _rentedStream;   

  int _currentNavIndex = 3; 
  bool _isRentedExpanded = true; 

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
          .where('isReadByLandlord', isEqualTo: false) 
          .snapshots();

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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(userRole: 'Landlord', initialIndex: 0)));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(userRole: 'Landlord', initialIndex: 1)));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LandlordInboxScreen()));
    } else if (index == 3) {
      // Current
    }
    if (mounted) setState(() => _currentNavIndex = index);
  }

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
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  void _navigateToBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => LandlordBookingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _bookingsStream,
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) count = snapshot.data!.docs.length;
              return IconButton(
                onPressed: _navigateToBookings,
                icon: Badge(
                  label: Text(count.toString()),
                  isLabelVisible: count > 0,
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white), 
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
                
                StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) return const SizedBox(height: 80); 
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                    
                    return StreamBuilder<QuerySnapshot>(
                      stream: _bookingsStream, 
                      builder: (context, bookingSnapshot) {
                        return UserInfoCard(
                          name: userData['name'] ?? 'Landlord',
                          phone: userData['phone'] ?? '',
                          avatarUrl: userData['avatarUrl'],
                          pendingBookingCount: (bookingSnapshot.hasData) ? bookingSnapshot.data!.docs.length : 0,
                          onNotificationTap: _navigateToBookings,
                        );
                      },
                    );
                  },
                ),
                
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          child: InkWell(
                            onTap: () => setState(() => _isRentedExpanded = !_isRentedExpanded),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  "Rent Collection",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                ),
                                const Spacer(),
                                Icon(
                                  _isRentedExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),

                        AnimatedCrossFade(
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: Container(
                            // 🔥🔥🔥 修复点：增加高度到 250 🔥🔥🔥
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal, 
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: rentedDocs.length,
                              itemBuilder: (context, index) {
                                final data = rentedDocs[index].data() as Map<String, dynamic>;
                                return _GlassRentCard(
                                  data: data,
                                  onTap: _navigateToBookings,
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

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Icon(Icons.home_work_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "My Properties",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _propertiesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
                      if (snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_home_work, size: 50, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 10),
                              const Text("No Properties", style: TextStyle(color: Colors.white70)),
                            ],
                          )
                        );
                      }
                      
                      final properties = snapshot.data!.docs;
                      
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), 
                        itemCount: properties.length,
                        itemBuilder: (context, index) {
                          final doc = properties[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String status = data['status'] ?? 'available';
                          final bool isRented = status == 'rented';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Stack(
                              children: [
                                PropertyCard(
                                  propertyData: data,
                                  propertyId: doc.id,
                                  heroTagPrefix: 'landlord_list',
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddPropertyScreen(propertyId: doc.id)));
                                  },
                                ),
                                
                                if (isRented)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), 
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.2), 
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          alignment: Alignment.topRight,
                                          child: Container(
                                            margin: const EdgeInsets.only(top: 12, right: 12),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.redAccent.withOpacity(0.9), Colors.redAccent],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                                              ]
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.lock_outline, color: Colors.white, size: 12),
                                                SizedBox(width: 4),
                                                Text(
                                                  "RENTED", 
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
          BottomNavItem(icon: Icons.dashboard_rounded, label: "Home"),
          BottomNavItem(icon: Icons.view_list_rounded, label: "Properties"),
          BottomNavItem(icon: Icons.move_to_inbox_rounded, label: "Inbox"), 
          BottomNavItem(icon: Icons.person_rounded, label: "Profile"),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60), 
        child: SizedBox(
          width: 56, height: 56,
          child: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPropertyScreen())),
            elevation: 0,
            backgroundColor: Colors.transparent, 
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥🔥🔥 核心组件：智能收租卡片 (Smart Rent Card) 🔥🔥🔥
class _GlassRentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _GlassRentCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 获取数据
    final String propertyId = data['propertyId'];
    final String tenantUid = data['tenantUid'];
    
    final int monthlyPaymentDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;
    final Timestamp? lastPaymentTimestamp = data['lastPaymentDate'] as Timestamp?;

    // --- 🔥 智能状态逻辑 (Smart Billing Logic) 🔥 ---
    final now = DateTime.now();
    
    // UI 变量初始化
    String statusText = "UNKNOWN";
    Color statusColor = Colors.grey;
    List<Color> gradientColors = [Colors.grey, Colors.grey];
    IconData statusIcon = Icons.info_outline;

    DateTime? payTime;
    if (lastPaymentTimestamp != null) {
      payTime = lastPaymentTimestamp.toDate();
    }

    DateTime targetDueDate;
    String paidForMonthText = "";

    if (payTime != null) {
      // 🧠 核心算法：智能推断目标月份
      bool isEarlyPaymentForNextMonth = (monthlyPaymentDay < 15) && (payTime.day > 20);

      if (isEarlyPaymentForNextMonth) {
        if (payTime.month == 12) {
           targetDueDate = DateTime(payTime.year + 1, 1, monthlyPaymentDay);
        } else {
           targetDueDate = DateTime(payTime.year, payTime.month + 1, monthlyPaymentDay);
        }
      } else {
        targetDueDate = DateTime(payTime.year, payTime.month, monthlyPaymentDay);
      }
      
      paidForMonthText = "Paid for: ${DateFormat('MMM yyyy').format(targetDueDate)}";

    } else {
      // 没付钱，目标就是"本月"
      targetDueDate = DateTime(now.year, now.month, monthlyPaymentDay);
    }

    // 比较逻辑
    if (payTime != null) {
      final datePaid = DateTime(payTime.year, payTime.month, payTime.day);
      final dateDue = DateTime(targetDueDate.year, targetDueDate.month, targetDueDate.day);

      if (datePaid.isBefore(dateDue)) {
        // 🟢 提前 (Early)
        statusText = "PAID EARLY - ${DateFormat('dd MMM').format(payTime)}";
        gradientColors = [const Color(0xFF00E676).withOpacity(0.3), const Color(0xFF00E676).withOpacity(0.1)];
        statusColor = const Color(0xFF69F0AE); 
        statusIcon = Icons.verified_rounded;
      
      } else if (datePaid.isAtSameMomentAs(dateDue)) {
        // 🟢 准时 (On Time)
        statusText = "PAID ON TIME - ${DateFormat('dd MMM').format(payTime)}";
        gradientColors = [const Color(0xFF66BB6A).withOpacity(0.3), const Color(0xFF66BB6A).withOpacity(0.1)];
        statusColor = const Color(0xFFA5D6A7); 
        statusIcon = Icons.check_circle_rounded;
      
      } else {
        // 🟠 迟交 (Late)
        final daysLate = datePaid.difference(dateDue).inDays;
        statusText = "PAID LATE ($daysLate DAYS)";
        gradientColors = [Colors.orangeAccent.withOpacity(0.3), Colors.orangeAccent.withOpacity(0.1)];
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.history_toggle_off_rounded;
      }

    } else {
      // ❌ 未支付状态
      final currentMonthDue = DateTime(now.year, now.month, monthlyPaymentDay);
      
      if (now.day > monthlyPaymentDay) {
        // 🔴 逾期
        final daysLate = now.difference(currentMonthDue).inDays;
        statusText = "OVERDUE ($daysLate DAYS)";
        gradientColors = [const Color(0xFFEF5350).withOpacity(0.4), const Color(0xFFEF5350).withOpacity(0.1)];
        statusColor = const Color(0xFFFFCDD2);
        statusIcon = Icons.warning_rounded;
      } else {
        // 🔵 待支付
        statusText = "DUE: ${DateFormat('MMM dd').format(currentMonthDue)}";
        gradientColors = [Colors.lightBlueAccent.withOpacity(0.3), Colors.lightBlueAccent.withOpacity(0.1)];
        statusColor = Colors.lightBlueAccent;
        statusIcon = Icons.access_time_rounded;
      }
    }

    return Container(
      width: 290, 
      margin: const EdgeInsets.only(right: 16, bottom: 4), 
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), 
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)), 
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 顶部：房产名
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('properties').doc(propertyId).get(),
                              builder: (context, snapshot) {
                                String name = "...";
                                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                  name = snapshot.data!.get('communityName') ?? "Property";
                                }
                                return Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      // 🔥 修改：稍微调小这里的间距 12 -> 8
                      const SizedBox(height: 8),

                      // 中部：租金 & 租客
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TENANT", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(tenantUid).get(),
                                builder: (context, snapshot) {
                                  String tName = "...";
                                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                    tName = snapshot.data!.get('name') ?? "Tenant";
                                  }
                                  return Text(tName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14));
                                },
                              ),
                            ],
                          ),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("RENT", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('properties').doc(propertyId).get(),
                                builder: (context, snapshot) {
                                  String priceDisplay = "...";
                                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                    final pData = snapshot.data!.data() as Map<String, dynamic>;
                                    priceDisplay = pData['price']?.toString() ?? pData['rentAmount']?.toString() ?? '0';
                                  }
                                  return Text(
                                    "RM $priceDisplay", 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // 🔥 修改：稍微调小这里的间距 12 -> 8
                      const SizedBox(height: 8),
                      
                      // 🔥 新增：显示已付月份 🔥
                      if (paidForMonthText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.6), size: 12),
                              const SizedBox(width: 4),
                              Text(paidForMonthText, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                            ],
                          ),
                        ),

                      // 底部：毛玻璃支付状态条
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), 
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradientColors), 
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(statusIcon, color: statusColor, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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