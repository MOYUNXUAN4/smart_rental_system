import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rental_system/Screens/property_list_screen.dart';
import 'package:smart_rental_system/screens/favorite_screen.dart'; 

// 导入核心组件和页面
import 'login_screen.dart';
import '../Compoents/animated_bottom_nav.dart'; 
import '../Services/account_check_screen.dart'; 


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomIndex = 0; // 索引 0 (Home) 是默认页

  // ✅ 2. 定义用于 IndexedStack 的页面列表
  final List<Widget> _pages = [
    const _HomeContent(),        // 索引 0: 主页内容 (我们刚提取的)
    const PropertyListScreen(),  // 索引 1: 房源列表页 (新创建的)
    const FavoritesScreen(),     // 索引 2: 收藏页 (新创建的)
  ];

  static const int _accountTabIndex = 3; // 'Account' 标签页的索引
  
  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.home, label: 'Home'),
    _NavItemData(icon: Icons.list, label: 'List'),
    _NavItemData(icon: Icons.star, label: 'Favorites'),
    _NavItemData(icon: Icons.person, label: 'Account'),
  ];
  
  // ✅ 3. 【已修改】 _onBottomNavTap 
  // 现在它会处理 IndexedStack 和导航
  void _onBottomNavTap(int index) {
    if (index == _accountTabIndex) {
      // 索引 3 (Account) 仍然使用 push 导航
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
      );
      // (我们不更新 _bottomIndex，以便在返回时保持在之前的页面)
    } else {
      // 索引 0, 1, 2 (Home, List, Favorites) 只需更新状态以切换 IndexedStack
      setState(() {
        _bottomIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // 保持全局透明
      extendBody: true, // 保持全局透明

      // ⚠️ 注意：AppBar 已被移至 _HomeContent 中
      // appBar: ... 

      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景渐变 (现在是所有页面的背景)
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
          
          // ✅ 4. 【核心修改】: 使用 IndexedStack 来切换页面
          IndexedStack(
            index: _bottomIndex,
            children: _pages,
          ),
        ],
      ),
      
      // 底边栏 (保持不变)
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _bottomIndex,
        onTap: _onBottomNavTap, // 使用更新后的点击处理
        items: _navItems.map((e) => BottomNavItem(icon: e.icon, label: e.label)).toList(),
      ),
    );
  }
}

// ===============================================================
// ✅ 5. 【新】: 提取您原有的主页 UI 到这个私有 Widget 中
// ===============================================================
class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  // (所有原有的 _HomeContent 状态和函数都移到这里)
  late Stream<DocumentSnapshot> _userStream; 
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  
  final String _backgroundImagePath = 'assets/images/mainPageBackGround.png';
  final String _smallImagePath = 'assets/images/mainPageBackGround.png'; 

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    } else {
      _userStream = Stream.error("User not logged in");
    }
  }
  
  // (登出函数)
  // ignore: unused_element
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

  // (跳转到账户页的函数)
  void _goToAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color imageDissolveColor = Color(0xFF153a44);
    
    final double appBarImageHeight = MediaQuery.of(context).size.height * 0.25;
    const double searchBarHeight = 54.0;
    const double searchBarVerticalPadding = 16.0;
    final double expandedAppBarHeight =
        appBarImageHeight + searchBarHeight + searchBarVerticalPadding * 2;

    // (您原有的 CustomScrollView 结构)
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          pinned: true,
          expandedHeight: expandedAppBarHeight,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {},
            ),
            
            // (您之前修改的用户头像/名字)
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
                  _buildActionButton(context, Icons.list_alt, "List", () => debugPrint("List clicked!")),
                  _buildActionButton(context, Icons.star, "Favorites", () => debugPrint("Favorites clicked!")),
                  _buildActionButton(context, Icons.person, "My Account", _goToAccount),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            _buildRecommendedCard(context),
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
            // 增加底部填充
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

  Widget _buildRecommendedCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recommended For You",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
                Icon(Icons.star_border,
                    color: Theme.of(context).colorScheme.onSurface),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    _smallImagePath,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Cerrado @Southville City",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.king_bed, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text("3",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          SizedBox(width: 8),
                          Icon(Icons.bathtub, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text("2",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          SizedBox(width: 8),
                          Icon(Icons.car_rental, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text("1",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ]),
                        SizedBox(height: 4),
                        Text("• Fully Furnished",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text("• Built-up: 850 sq.ft.",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text("• 11th Floor",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
                  Text("RM 1800",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  Text("/Month", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ],
            ),
          ]),
        ),
      ),
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
// (辅助类 _NavItemData 保持不变)
class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}