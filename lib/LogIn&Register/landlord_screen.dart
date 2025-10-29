import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_rental_system/Screens/add_property_screen.dart';

// 1. 导入所需的 UI 和导航组件
import '../Compoents/animated_bottom_nav.dart';
import '../Compoents/user_info_card.dart'; 
import '../LogIn&Register/login_screen.dart'; 
import '../account_check_screen.dart'; // 修正：假设在 lib/ 根目录
import '../home_screen.dart';
import '../Screens/add_property_screen.dart'; // 导入已存在

class LandlordScreen extends StatefulWidget {
  const LandlordScreen({super.key});

  @override
  State<LandlordScreen> createState() => _LandlordScreenState();
}

class _LandlordScreenState extends State<LandlordScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _userStream;

  // 2. 添加底边栏状态
  int _currentNavIndex = 3; 

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream =
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
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
      // 刷新当前流程
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
      );
    }
    // 其他索引 (List, Favorites) 仅更新动画
    setState(() {
      _currentNavIndex = index;
    });
  }

  // (您的 _signOut 函数保持不变)
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
          SafeArea(
            bottom: false, 
            child: StreamBuilder<DocumentSnapshot>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("Error loading user data", style: TextStyle(color: Colors.white70)));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final String name = userData['name'] ?? 'Unknown Name';
                final String phone = userData['phone'] ?? 'No Phone';
                final String? avatarUrl = userData['avatarUrl'];

                return Column(
                  children: [
                    UserInfoCard(
                      name: name,
                      phone: phone,
                      avatarUrl: avatarUrl,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'You have no properties yet.\nTap the + button to add one.',
                          textAlign: TextAlign.center,
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

      // ✅ 【已修改】: 补充了 FAB 的导航逻辑
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 跳转到添加房源页面
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPropertyScreen()),
          );
        },
        tooltip: 'Add Property',
        child: const Icon(Icons.add_home_work),
      ),
    );
  }
}