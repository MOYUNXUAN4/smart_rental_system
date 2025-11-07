// lib/Screens/home_screen.dart
import 'dart:ui';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 导入所有需要的屏幕
import 'package:smart_rental_system/Screens/property_list_screen.dart';
import 'package:smart_rental_system/screens/favorite_screen.dart'; 
import 'login_screen.dart';
import '../Services/account_check_screen.dart'; 
import 'package:smart_rental_system/screens/landlord_inbox_screen.dart'; 
import 'package:smart_rental_system/screens/property_detail_screen.dart'; 
import 'landlord_screen.dart';
import 'tenant_screen.dart'; 

// ▼▼▼ 【新】导入预约页面 (用于通知按钮) ▼▼▼
import 'landlord_bookings_screen.dart';
import 'tenant_bookings_screen.dart';
// ▲▲▲ 【新】 ▲▲▲

// 导入所有需要的组件
import '../Compoents/animated_bottom_nav.dart'; 
import 'package:smart_rental_system/Compoents/property_card.dart'; 
import '../Compoents/glass_card.dart';


class HomeScreen extends StatefulWidget {
  final String userRole;
  final int initialIndex;

  const HomeScreen({
    super.key, 
    this.userRole = 'Tenant',
    this.initialIndex = 0, // 👈 默认打开索引 0 (Home)
  }); 

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _bottomIndex; 
  late final List<Widget> _pages; 
  static const int _accountTabIndex = 3; 
  late final List<BottomNavItem> _navItems; 
  bool get isLandlord => widget.userRole == 'Landlord';
  
  @override
  void initState() {
    super.initState();
    _bottomIndex = widget.initialIndex; 

    _pages = [
      _HomeContent(userRole: widget.userRole),  
      const PropertyListScreen(),           
      const FavoritesScreen(),              
    ];

    _navItems = isLandlord
      ? const [ 
          BottomNavItem(icon: Icons.home, label: 'Home'),
          BottomNavItem(icon: Icons.list, label: 'List'),
          BottomNavItem(icon: Icons.inbox, label: 'Inbox'), 
          BottomNavItem(icon: Icons.person, label: 'Account'),
        ]
      : const [ 
          BottomNavItem(icon: Icons.home, label: 'Home'),
          BottomNavItem(icon: Icons.list, label: 'List'),
          BottomNavItem(icon: Icons.star, label: 'Favorites'), 
          BottomNavItem(icon: Icons.person, label: 'Account'),
        ];
  }
  
  // (导航逻辑 - 已修复)
  void _onBottomNavTap(int index) {
    if (index == _accountTabIndex) {
      if (isLandlord) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LandlordScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TenantScreen()),
        );
      }
    } else if (index == 2 && isLandlord) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LandlordInboxScreen()),
      );
    }
    else {
      setState(() {
        _bottomIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      extendBody: true, 

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
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),
          
          IndexedStack(
            index: (isLandlord && _bottomIndex == 2) ? 0 : _bottomIndex,
            children: _pages,
          ),
        ],
      ),
      
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _bottomIndex,
        onTap: _onBottomNavTap, 
        items: _navItems,
      ),
    );
  }
}

// ===============================================================
// _HomeContent: (这里是主要修改的地方)
// ===============================================================
class _HomeContent extends StatefulWidget {
  final String userRole;
  const _HomeContent({required this.userRole});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  late Stream<DocumentSnapshot> _userStream; 
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<QuerySnapshot> _propertiesStream;

  // ▼▼▼ 【新】: 为通知铃铛添加 Stream ▼▼▼
  late Stream<QuerySnapshot> _notificationStream;
  // ▲▲▲ 【新】 ▲▲▲

  bool get isLandlord => widget.userRole == 'Landlord';
  final String _backgroundImagePath = 'assets/images/mainPageBackGround.png';
  
  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();

      // ▼▼▼ 【新】: 根据角色初始化通知 Stream ▼▼▼
      if (isLandlord) {
        // 房东的通知 = 待处理 (pending) 的预约
        _notificationStream = FirebaseFirestore.instance
            .collection('bookings')
            .where('landlordUid', isEqualTo: _uid)
            .where('status', isEqualTo: 'pending')
            .snapshots();
      } else {
        // 租客的通知 = 已被处理 (approved/rejected) 且未读 (isReadByTenant == false) 的预约
        _notificationStream = FirebaseFirestore.instance
            .collection('bookings')
            .where('tenantUid', isEqualTo: _uid)
            .where('status', whereIn: ['approved', 'rejected'])
            .where('isReadByTenant', isEqualTo: false)
            .snapshots();
      }
      // ▲▲▲ 【新】 ▲▲▲

    } else {
      _userStream = Stream.error("User not logged in");
      // ▼▼▼ 【新】: 初始化
      _notificationStream = Stream.error("User not logged in");
      // ▲▲▲ 【新】 ▲▲▲
    }
    _propertiesStream = FirebaseFirestore.instance.collection('properties').snapshots();
  }
  
  // (登出函数 - 保持不变)
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  // (跳转到账户页的函数 - 已修复)
  void _goToAccount() {
    if (isLandlord) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LandlordScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TenantScreen()),
      );
    }
  }

  // (快捷按钮导航 - 保持不变)
  void _goToList() {
    context.findAncestorStateOfType<_HomeScreenState>()?._onBottomNavTap(1);
  }
  void _goToFavorites() {
    context.findAncestorStateOfType<_HomeScreenState>()?._onBottomNavTap(2);
  }
  void _goToLandlordInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LandlordInboxScreen()),
    );
  }

  // ▼▼▼ 【新】: 为通知铃铛添加导航函数 ▼▼▼
  void _goToLandlordBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LandlordBookingsScreen()));
  }
  
  void _goToTenantBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TenantBookingsScreen()));
  }
  // ▲▲▲ 【新】 ▲▲▲

  @override
  Widget build(BuildContext context) {
    const Color imageDissolveColor = Color(0xFF153a44);
    
    final double appBarImageHeight = MediaQuery.of(context).size.height * 0.25;
    const double searchBarHeight = 54.0;
    const double searchBarVerticalPadding = 16.0;
    final double expandedAppBarHeight =
        appBarImageHeight + searchBarHeight + searchBarVerticalPadding * 2;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          pinned: true,
          expandedHeight: expandedAppBarHeight,
          actions: [
            
            // ▼▼▼ 【修改】: 替换旧的通知按钮 ▼▼▼
            StreamBuilder<QuerySnapshot>(
              stream: _notificationStream, // 👈 监听新的通知 stream
              builder: (context, snapshot) {
                int count = 0;
                if (snapshot.hasData) {
                  count = snapshot.data!.docs.length; // 👈 获取通知数量
                }
                
                return IconButton(
                  icon: Badge(
                    label: Text(count.toString()),
                    isLabelVisible: count > 0, // 👈 仅在 count > 0 时显示红点
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.notifications, color: Colors.white),
                  ),
                  onPressed: () {
                    // 👈 根据角色跳转
                    if (isLandlord) {
                      _goToLandlordBookings(); // 房东 -> 待处理页面
                    } else {
                      _goToTenantBookings(); // 租客 -> 状态页面
                    }
                  },
                );
              }
            ),
            // ▲▲▲ 【修改】 ▲▲▲
            
            // (用户头像/名字 StreamBuilder - 保持不变)
            StreamBuilder<DocumentSnapshot>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(14.0), 
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  );
                }
                if (!snapshot.hasData || snapshot.hasError) {
                  return IconButton(
                    icon: const Icon(Icons.person_outline, color: Colors.white),
                    tooltip: 'My Account',
                    onPressed: _goToAccount, 
                  );
                }
                
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final String name = (userData['name'] ?? 'User').split(' ').first; 
                final String? avatarUrl = userData['avatarUrl'];

                return GestureDetector(
                  onTap: _goToAccount, 
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                    child: Row(
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person, size: 20, color: Colors.white70) : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ], 
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _backgroundImagePath,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.4),
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: imageDissolveColor);
                  },
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        imageDissolveColor.withOpacity(0.15),
                        imageDissolveColor.withOpacity(0.3),
                        imageDissolveColor.withOpacity(0.6),
                        imageDissolveColor.withOpacity(0.85),
                        imageDissolveColor,
                      ],
                      stops: const [0.2, 0.45, 0.6, 0.75, 0.9, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: searchBarVerticalPadding,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(
                        height: searchBarHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30.0),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 6),
                            const Icon(Icons.search, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                cursorColor: const Color(0xFF4DA3FF),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: TextStyle(color: Colors.lightBlue.shade100),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D5DC7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  elevation: 2,
                                ),
                                child: const Text('Search', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ), 
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(context, Icons.search, "Search", () => debugPrint("Search clicked!")),
                  _buildActionButton(context, Icons.list_alt, "List", _goToList), 
                  isLandlord
                    ? _buildActionButton(context, Icons.inbox, "Inbox", _goToLandlordInbox) 
                    : _buildActionButton(context, Icons.star, "Favorites", _goToFavorites), 
                  _buildActionButton(context, Icons.person, "My Account", _goToAccount), 
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            
            // (随机推荐卡片 - 保持不变)
            _buildRecommendedPropertyCard(context),
            
            const SizedBox(height: 16.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                      child: _buildAreaCard(context, "Popular Areas", 52,
                          1500, "City Life & Dining")),
                  const SizedBox(width: 16.0),
                  Expanded(
                      child: _buildAreaCard(context, "Bangsar", 37, 1200,
                          "Student Friendly")),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          ]),
        ),
      ],
    );
  }

  // --- (所有 _build... 辅助函数保持不变) ---
  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTapAction) {
    return Column(
      children: [
        Material(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15.0),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(15.0),
            onTap: onTapAction, 
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(icon, size: 30, color: const Color(0xFF194652)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ],
    );
  }

  Widget _buildRecommendedPropertyCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _propertiesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GlassCard( 
              child: SizedBox(
                height: 100, 
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty || snapshot.hasError) {
          return const SizedBox.shrink(); 
        }
        final properties = snapshot.data!.docs;
        final randomIndex = Random().nextInt(properties.length);
        final randomPropertyDoc = properties[randomIndex];
        final propertyData = randomPropertyDoc.data() as Map<String, dynamic>;
        final propertyId = randomPropertyDoc.id;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Recommended For You",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)
                    ),
                    Icon(Icons.star, color: Colors.yellow[700]),
                  ],
                ),
              ),
              PropertyCard(
                propertyData: propertyData,
                propertyId: propertyId,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PropertyDetailScreen(propertyId: propertyId),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAreaCard(
      BuildContext context, String title, int listings, int avgPrice, String tag) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("• $listings Listings", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text("• Avg: RM$avgPrice/Month", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text("• $tag", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// (辅助类 _NavItemData，你的代码需要它)
class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}