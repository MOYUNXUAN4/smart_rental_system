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

  // 🔥 修复后的日期计算逻辑：支持提前还款识别
  DateTime _calculateNextDueDate(Map<String, dynamic> data) {
    final int payDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;
    final Timestamp? lastPayment = data['lastPaymentDate'];
    
    DateTime now = DateTime.now();

    if (lastPayment != null) {
      DateTime payTime = lastPayment.toDate();
      
      // 🧠 智能判定：如果是月底 (20号后) 付 月初 (15号前) 的房租 -> 视为付了下个月的钱
      // 比如：12月26日 付了 1月1日 的房租
      bool isEarlyPaymentForNextMonth = (payDay < 15) && (payTime.day > 20);

      if (isEarlyPaymentForNextMonth) {
        // 如果是12月付的，payTime.month 是12。
        // 既然是 Early Payment，说明这笔钱cover了1月。
        // 那么 Next Due 就是 2月。
        
        // 逻辑：基于支付时间，跳过它cover的那个月，再往后推一个月
        DateTime paidForMonth;
        if (payTime.month == 12) {
          paidForMonth = DateTime(payTime.year + 1, 1, 1);
        } else {
          paidForMonth = DateTime(payTime.year, payTime.month + 1, 1);
        }

        // 下一次截止日 = PaidForMonth + 1 month
        if (paidForMonth.month == 12) {
          return DateTime(paidForMonth.year + 1, 1, payDay);
        } else {
          return DateTime(paidForMonth.year, paidForMonth.month + 1, payDay);
        }
      } else {
        // 普通情况：同月支付 (比如5号付了本月1号的钱)
        // 既然lastPaymentDate存在且不是Early Payment，说明本月已付。
        // Next Due = 本月 + 1
        // 注意：这里要处理 "如果上个月付了，但现在已经是新的一月且没付" 的情况
        
        // 简单化：如果最后一次支付月份 == 当前月份，说明本月已付 -> 下个月
        // 如果最后一次支付月份 < 当前月份，说明本月未付 -> 本月
        
        if (payTime.year == now.year && payTime.month == now.month) {
           // 本月已付 -> 下个月
           return DateTime(now.year, now.month + 1, payDay);
        } else if (payTime.isBefore(DateTime(now.year, now.month, 1))) {
           // 上次支付是很久以前 -> 本月
           return DateTime(now.year, now.month, payDay);
        }
      }
    }

    // 没付过钱 -> 本月
    return DateTime(now.year, now.month, payDay);
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
                        
                        // 🔥 1. 获取并排序数据 (使用新逻辑)
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
                                  key: ValueKey(docs[index].id), 
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
  final bool startExpanded; 
  final VoidCallback onPayTap;

  const _ExpandableLeaseCard({
    super.key, 
    required this.doc, 
    required this.isPaying, 
    this.startExpanded = false, 
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
    _isExpanded = widget.startExpanded;
  }

  @override
  void didUpdateWidget(_ExpandableLeaseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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

    // 🔥🔥🔥 核心修正：智能推算 Next Due Date 🔥🔥🔥
    DateTime nextDueDate;
    bool hasPaidForCurrentCycle = false;
    
    // 默认为本月
    nextDueDate = DateTime(now.year, now.month, payDay);

    if (lastPayment != null) {
      DateTime payTime = lastPayment.toDate();
      
      // 算法：如果是 月底(>20) 付 月初(<15) 的租金 -> 认为是提前支付了下个月的
      bool isEarlyPayment = (payDay < 15) && (payTime.day > 20);

      if (isEarlyPayment) {
        // 判定：已付下月
        // 下次截止日应该是：下下个月
        // 例子：12月26 付 1月1日。 PaidFor=Jan. NextDue=Feb.
        
        DateTime paidForMonth; // 1月
        if (payTime.month == 12) {
          paidForMonth = DateTime(payTime.year + 1, 1, 1);
        } else {
          paidForMonth = DateTime(payTime.year, payTime.month + 1, 1);
        }
        
        // Next Due = PaidFor + 1
        if (paidForMonth.month == 12) {
          nextDueDate = DateTime(paidForMonth.year + 1, 1, payDay);
        } else {
          nextDueDate = DateTime(paidForMonth.year, paidForMonth.month + 1, payDay);
        }
        hasPaidForCurrentCycle = true;

      } else {
        // 普通情况：同月支付
        if (payTime.year == now.year && payTime.month == now.month) {
          // 本月已付 -> 下个月
          hasPaidForCurrentCycle = true;
          if (now.month == 12) {
            nextDueDate = DateTime(now.year + 1, 1, payDay);
          } else {
            nextDueDate = DateTime(now.year, now.month + 1, payDay);
          }
        } else {
          // 上次支付是很久以前 -> 本月
          // nextDueDate 保持默认值 (本月)
        }
      }
    }

    int daysUntilDue = nextDueDate.difference(now).inDays;
    bool isOverdue = !hasPaidForCurrentCycle && (now.day > payDay) && nextDueDate.month == now.month;

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
              ? _buildExpanded(propertyName, leaseRange, DateFormat('dd MMM yyyy').format(nextDueDate), rentAmount, accentColor, statusText, isOverdue)
              : _buildCollapsed(propertyName, DateFormat('dd MMM yyyy').format(nextDueDate), statusText, accentColor),
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
    // 🔥🔥 新增：动态计算并显示已付月份 (Paid For ...) 🔥🔥
    String paidForText = "";
    bool showPaidInfo = false;
    
    final Map<String, dynamic> data = widget.doc.data() as Map<String, dynamic>;
    final Timestamp? lastPayment = data['lastPaymentDate'];
    final int monthlyPaymentDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;

    if (lastPayment != null) {
      DateTime payTime = lastPayment.toDate();
      DateTime targetMonth;
      
      // 智能判断：是付当月还是下月
      bool isEarly = (monthlyPaymentDay < 15) && (payTime.day > 20);
      
      if (isEarly) {
        // 如果是提前付，Paid For = 下个月
        if (payTime.month == 12) {
           targetMonth = DateTime(payTime.year + 1, 1, 1);
        } else {
           targetMonth = DateTime(payTime.year, payTime.month + 1, 1);
        }
      } else {
        // 普通支付，Paid For = 当前支付月
        targetMonth = payTime;
      }

      paidForText = "Paid for: ${DateFormat('MMMM yyyy').format(targetMonth)}";
      showPaidInfo = true;
    }

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
        
        // 🔥 显示已付月份的 UI
        if (showPaidInfo) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF69F0AE), size: 16),
                const SizedBox(width: 8),
                Text(
                  paidForText, 
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
        ],

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