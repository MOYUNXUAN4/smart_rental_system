// lib/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'animated_bottom_nav.dart'; // 导入底部导航栏组件

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _backgroundImagePath = 'assets/images/mainPageBackGround.png';
  final String _smallImagePath = 'assets/images/mainPageBackGround.png'; // 使用现有图片
  int _bottomIndex = 0;

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

  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.home, label: 'Home'),
    _NavItemData(icon: Icons.list, label: 'List'),
    _NavItemData(icon: Icons.star, label: 'Favorites'),
    _NavItemData(icon: Icons.person, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    const Color imageDissolveColor = Color(0xFF153a44);
    const Color bottomNavStart = Color(0xFF1C315E);
    const Color bottomNavEnd = Color(0xFF3B73C0);

    final double appBarImageHeight = MediaQuery.of(context).size.height * 0.25;
    const double searchBarHeight = 54.0;
    const double searchBarVerticalPadding = 16.0;
    final double expandedAppBarHeight =
        appBarImageHeight + searchBarHeight + searchBarVerticalPadding * 2;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Container(
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
        child: CustomScrollView(
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
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Log Out',
                  onPressed: _signOut,
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
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08)),
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
                                      hintStyle: TextStyle(
                                          color: Colors.lightBlue.shade100),
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1D5DC7),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      elevation: 2,
                                    ),
                                    child: const Text('Search',
                                        style: TextStyle(color: Colors.white)),
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
                      _buildActionButton(context, Icons.search, "Search"),
                      _buildActionButton(context, Icons.list_alt, "List"),
                      _buildActionButton(context, Icons.star, "Favorites"),
                      _buildActionButton(context, Icons.person, "My Account"),
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
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _bottomIndex,
        onTap: (index) {
          setState(() {
            _bottomIndex = index;
          });
        },
        items: _navItems.map((e) => BottomNavItem(icon: e.icon, label: e.label)).toList(),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        Material(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15.0),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(15.0),
            onTap: () => debugPrint("$label clicked!"),
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

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}
