import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 1. 导入所有必需的 UI 和导航组件
import '../Compoents/animated_bottom_nav.dart';
import '../Compoents/user_info_card.dart'; 
import 'login_screen.dart'; 
import '../Services/account_check_screen.dart';
import 'home_screen.dart';

class TenantScreen extends StatefulWidget {
  const TenantScreen({super.key});

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  // 您的 Stream 逻辑（已优化，保持不变）
  late Stream<DocumentSnapshot> _userStream; 
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // 2. 添加底边栏状态 (同 LandlordScreen, 索引为 3)
  int _currentNavIndex = 3; 

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    } else {
      _userStream = Stream.error("User not logged in");
    }
  }

  // 3. 添加底边栏点击处理
  void _onNavTap(int index) {
    if (index == 0) { // Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 3) { // My Account
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
      );
    }
    setState(() {
      _currentNavIndex = index;
    });
  }

  // 4. 添加带确认和导航的退出函数 (与 LandlordScreen 相同)
  Future<void> _signOut(BuildContext context) async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (didConfirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 5. 应用与 LandlordScreen 相同的 UI 结构
      extendBody: true,
      extendBodyBehindAppBar: true, 

      appBar: AppBar(
        backgroundColor: Colors.transparent, // 透明
        elevation: 0, // 无阴影
        title: const Text('Tenant Dashboard', style: TextStyle(color: Colors.white)), // 文本变白
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), // 图标变白
            onPressed: () => _signOut(context), // 6. 使用新的退出函数
          )
        ],
      ),

      // 7. 添加渐变背景
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
              ),
            ),
          ),

          // 8. 将 StreamBuilder 放入 SafeArea
          SafeArea(
            bottom: false,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _userStream, 
              builder: (context, snapshot) {
                // 9. 更新加载和错误提示的颜色
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("Error: Could not load user data.", style: TextStyle(color: Colors.white70)));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final String name = userData['name'] ?? 'No Name';
                final String phone = userData['phone'] ?? 'No Phone';
                final String? avatarUrl = userData['avatarUrl'];

                return Column(
                  children: [
                    // UserInfoCard 自动是毛玻璃风格
                    UserInfoCard(
                      name: name,
                      phone: phone,
                      avatarUrl: avatarUrl,
                    ),
                    
                    Expanded(
                      child: Center(
                        child: Text(
                          'You have no rented properties yet.',
                          // 10. 更新空状态文本颜色
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // 11. 添加底边栏
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavItem(icon: Icons.home, label: "Home Page"),
          BottomNavItem(icon: Icons.list, label: "List"),
          BottomNavItem(icon: Icons.star, label: "Favorites"),
          BottomNavItem(icon: Icons.person, label: "My Account"),
        ],
      ),
    );
  }
}