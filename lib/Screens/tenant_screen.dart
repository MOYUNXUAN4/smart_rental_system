import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_rental_system/Compoents/animated_bottom_nav.dart';
import 'package:smart_rental_system/Compoents/user_info_card.dart';
import 'package:smart_rental_system/Screens/home_screen.dart';
import 'package:smart_rental_system/Screens/login_screen.dart';
import 'package:smart_rental_system/Screens/tenant_bookings_screen.dart';
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
  late Stream<QuerySnapshot> _activeLeaseStream; 

  int _currentNavIndex = 3; 
  final Set<String> _payingBookingIds = {}; 

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

      _activeLeaseStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('tenantUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'completed')
          .snapshots();

    } else {
      _userStream = const Stream.empty();
      _notificationStream = const Stream.empty();
      _activeLeaseStream = const Stream.empty();
    }
  }

  // 🔥 辅助函数：计算下一次还款日期 (用于排序)
  DateTime _calculateNextDueDate(Map<String, dynamic> data) {
    final int payDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;
    final Timestamp? lastPayment = data['lastPaymentDate'];
    
    DateTime now = DateTime.now();
    bool hasPaidThisMonth = false;

    if (lastPayment != null) {
      DateTime lastDate = lastPayment.toDate();
      if (lastDate.year == now.year && lastDate.month == now.month) {
        hasPaidThisMonth = true;
      }
    }

    // 如果这个月付过了，下个截止日就是下个月；否则就是这个月
    if (hasPaidThisMonth) {
      return DateTime(now.year, now.month + 1, payDay);
    } else {
      return DateTime(now.year, now.month, payDay);
    }
  }

  void _requireLogin(VoidCallback onSuccess) {
    if (_uid == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to access this feature.")));
    } else {
      onSuccess();
    }
  }

  void _onNavTap(int index) {
    if (index == 0) { 
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 0)));
    } else if (index == 1) { 
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 1)));
    } else if (index == 2) { 
      _requireLogin(() {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Tenant', initialIndex: 2)));
      });
    } else if (index == 3) { }
    if (mounted) setState(() => _currentNavIndex = index);
  }

  Future<void> _signOut(BuildContext context) async {
    if (_uid == null) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      return;
    }
    await FirebaseAuth.instance.signOut();
    if(mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
  }

  void _navigateToBookings() {
    _requireLogin(() {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const TenantBookingsScreen()));
    });
  }

  Future<void> _handleDashboardPayment(Map<String, dynamic> bookingData, String docId) async {
    setState(() => _payingBookingIds.add(docId)); 

    try {
      dynamic rawPrice = bookingData['price'] ?? bookingData['rent'] ?? bookingData['amount'];
      if (rawPrice == null) {
        String? propertyId = bookingData['propertyId'];
        if (propertyId != null) {
           final pDoc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
           if(pDoc.exists) rawPrice = pDoc.data()?['price'] ?? pDoc.data()?['rent'];
        }
      }

      if (rawPrice == null) throw Exception("Price info missing.");
      String priceStr = rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '');
      double rentPrice = double.tryParse(priceStr) ?? 0.0;
      if (rentPrice <= 0.5) throw Exception("Invalid price");

      bool success = await StripeService.instance.makePayment(rentPrice);

      if (success) {
        await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
          'paymentStatus': 'paid',     
          'lastPaymentDate': FieldValue.serverTimestamp(), 
          'isReadByLandlord': false, 
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rent Paid! Welcome home."), backgroundColor: Colors.green));
        }
      } 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _payingBookingIds.remove(docId));
    }
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
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _notificationStream,
            builder: (context, snapshot) {
              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
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
            icon: Icon(_uid == null ? Icons.login : Icons.logout, color: Colors.white),
            onPressed: () => _signOut(context),
          )
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_uid != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: _userStream,
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100);
                        final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                        return StreamBuilder<QuerySnapshot>(
                          stream: _notificationStream,
                          builder: (context, notifSnapshot) {
                            return UserInfoCard(
                              name: userData['name'] ?? 'Tenant',
                              phone: userData['phone'] ?? 'No Phone',
                              avatarUrl: userData['avatarUrl'],
                              pendingBookingCount: (notifSnapshot.hasData) ? notifSnapshot.data!.docs.length : 0, 
                              onNotificationTap: _navigateToBookings, 
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 10),
                  if (_uid != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: _activeLeaseStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                        
                        // 🔥 1. 获取并排序数据
                        var docs = snapshot.data!.docs;
                        docs.sort((a, b) {
                          DateTime dateA = _calculateNextDueDate(a.data() as Map<String, dynamic>);
                          DateTime dateB = _calculateNextDueDate(b.data() as Map<String, dynamic>);
                          return dateA.compareTo(dateB); // 越早到期的越靠前
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text("Current Leases", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(), 
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: docs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                // 🔥 2. 将 Key 和 startExpanded 传给子组件
                                return _ExpandableLeaseCard(
                                  key: ValueKey(docs[index].id), // 确保列表排序变化时 UI 不会错乱
                                  doc: docs[index],
                                  isPaying: _payingBookingIds.contains(docs[index].id),
                                  startExpanded: index == 0, // ✨ 只有第一个默认展开
                                  onPayTap: () => _handleDashboardPayment(docs[index].data() as Map<String, dynamic>, docs[index].id),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("My Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        _buildDashboardButton(context, Icons.calendar_month_outlined, "My Bookings", "Check status & contracts", const Color(0xFF00BFA5), _navigateToBookings),
                        const SizedBox(height: 12),
                        _buildDashboardButton(context, Icons.favorite_border, "Saved Properties", "Your favorite listings", Colors.pinkAccent, () => _onNavTap(2)),
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
      bottomNavigationBar: AnimatedBottomNav(currentIndex: _currentNavIndex, onTap: _onNavTap, items: const [
          BottomNavItem(icon: Icons.home, label: "Home"),
          BottomNavItem(icon: Icons.list, label: "List"),
          BottomNavItem(icon: Icons.star, label: "Favorites"), 
          BottomNavItem(icon: Icons.person, label: "Account"),
      ]),
    );
  }

  Widget _buildDashboardButton(BuildContext context, IconData icon, String label, String subLabel, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.2))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(subLabel, style: const TextStyle(color: Colors.white70, fontSize: 12))])),
                const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [Icon(Icons.home_outlined, color: Colors.white70), SizedBox(width: 12), Text("No active leases yet.", style: TextStyle(color: Colors.white70))],
      ),
    );
  }
}

// 🔥🔥 核心组件优化：支持默认展开和外部控制 🔥🔥
class _ExpandableLeaseCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final bool isPaying;
  final bool startExpanded; // ✨ 新增参数
  final VoidCallback onPayTap;

  const _ExpandableLeaseCard({
    super.key, // 建议加上 Key
    required this.doc, 
    required this.isPaying, 
    this.startExpanded = false, // 默认为 false
    required this.onPayTap
  });

  @override
  State<_ExpandableLeaseCard> createState() => _ExpandableLeaseCardState();
}

class _ExpandableLeaseCardState extends State<_ExpandableLeaseCard> {
  late bool _isExpanded; 

  @override
  void initState() {
    super.initState();
    // 🔥 初始化时，应用传入的默认状态
    _isExpanded = widget.startExpanded;
  }

  @override
  void didUpdateWidget(_ExpandableLeaseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果组件被重建（比如列表重新排序导致 doc 改变），我们需要更新状态
    if (widget.doc.id != oldWidget.doc.id) {
       _isExpanded = widget.startExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final int payDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;
    final Timestamp? lastPayment = data['lastPaymentDate'];
    final String rentAmount = data['price']?.toString() ?? '0';

    DateTime now = DateTime.now();
    bool hasPaidThisMonth = false;
    if (lastPayment != null) {
      DateTime lastDate = lastPayment.toDate();
      if (lastDate.year == now.year && lastDate.month == now.month) hasPaidThisMonth = true;
    }

    DateTime targetDate;
    if (hasPaidThisMonth) {
      targetDate = DateTime(now.year, now.month + 1, payDay); // 下个月
    } else {
      targetDate = DateTime(now.year, now.month, payDay); // 这个月
    }

    int daysUntilDue = targetDate.difference(now).inDays;
    bool isOverdue = !hasPaidThisMonth && (now.day > payDay);

    final List<Color> bgGradient = isOverdue 
        ? [const Color(0xFFD32F2F), const Color(0xFFB71C1C)] 
        : [const Color(0xFF009688), const Color(0xFF004D40)];
    final Color accentColor = isOverdue ? const Color(0xFFFF5252) : const Color(0xFF69F0AE);
    final String statusText = isOverdue ? "OVERDUE" : "Active Lease";

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('properties').doc(data['propertyId']).get(),
      builder: (context, propSnap) {
        String propertyName = propSnap.hasData ? (propSnap.data!.get('communityName') ?? "Home") : "Loading...";
        String leaseRange = (data['leaseStartDate'] != null && data['leaseEndDate'] != null)
            ? "${DateFormat('MMM yyyy').format(data['leaseStartDate'].toDate())} - ${DateFormat('MMM yyyy').format(data['leaseEndDate'].toDate())}"
            : "Unknown";

        return GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: bgGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.5)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: _isExpanded 
              ? _buildExpanded(propertyName, leaseRange, DateFormat('dd MMM yyyy').format(targetDate), rentAmount, accentColor, statusText, isOverdue)
              : _buildCollapsed(propertyName, DateFormat('dd MMM yyyy').format(targetDate), statusText, accentColor),
          ),
        );
      }
    );
  }

  Widget _buildCollapsed(String name, String date, String status, Color accent) {
    return Row(
      children: [
        const CircleAvatar(backgroundColor: Colors.white24, radius: 18, child: Icon(Icons.home_work, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text("$status • Due: $date", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
      ],
    );
  }

  Widget _buildExpanded(String name, String range, String date, String amount, Color accent, String status, bool isOverdue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.white24, radius: 20, child: Icon(Icons.home_work, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(status, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up, color: Colors.white54),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _infoItem("Lease Period", range),
            _infoItem("Next Due", date, accent: accent),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton(
            onPressed: widget.isPaying ? null : widget.onPayTap,
            style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: widget.isPaying 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isOverdue ? "Pay Overdue Rent" : "Pay Rent (RM $amount)", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value, {Color? accent}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: accent ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}