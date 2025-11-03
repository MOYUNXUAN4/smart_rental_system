import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ 1. 【已修复】: 统一并修正了所有的 import 路径
// (请确保您的 'Compoents' 文件夹拼写正确, 如果是 'Components' 请在此处更正)
import 'package:smart_rental_system/Compoents/animated_bottom_nav.dart';
import 'package:smart_rental_system/Compoents/user_info_card.dart'; 
import 'package:smart_rental_system/Screens/login_screen.dart'; 
// (假设 account_check_screen 在 lib/screens/ 目录下)
import 'package:smart_rental_system/Services/account_check_screen.dart'; 
// (假设 home_screen 在 lib/ 目录下)
import 'package:smart_rental_system/Screens/home_screen.dart';
// (✅ 关键修复: 使用小写的 'screens')
import 'package:smart_rental_system/screens/add_property_screen.dart'; 

// ✅ 2. 导入我们新创建的卡片 (请确保 'Compoents' 拼写正确)
import 'package:smart_rental_system/Compoents/property_card.dart';


class LandlordScreen extends StatefulWidget {
  const LandlordScreen({super.key});

  @override
  State<LandlordScreen> createState() => _LandlordScreenState();
}

class _LandlordScreenState extends State<LandlordScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _userStream;
  // ✅ 3. 为房源列表创建新的 Stream
  late Stream<QuerySnapshot> _propertiesStream;

  int _currentNavIndex = 3; 

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      // Stream 1: 用于 UserInfoCard
      _userStream =
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
          
      // ✅ 4. Stream 2: 用于房源列表，查询 'properties' 集合
      _propertiesStream = FirebaseFirestore.instance
          .collection('properties')
          .where('landlordUid', isEqualTo: _uid) // 筛选出当前房东的房源
          .snapshots(); 
          
    } else {
      _userStream = Stream.error("User not logged in");
      _propertiesStream = Stream.error("User not logged in");
    }
  }

  // ( _onNavTap 和 _signOut 函数保持不变 )
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
      
      // ✅ 5. 【核心修改】: 重构 body
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景渐变 (保持不变)
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
            child: Column( // 使用 Column 堆叠 UserInfoCard 和 房源列表
              children: [
                // 顶部 UserInfoCard (保持不变)
                StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // 在加载时显示一个空的 UserInfoCard 占位符
                      return const UserInfoCard(name: 'Loading...', phone: '...', avatarUrl: null);
                    }
                    if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                      return const UserInfoCard(name: 'Error', phone: 'Could not load data', avatarUrl: null);
                    }
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final String name = userData['name'] ?? 'Unknown Name';
                    final String phone = userData['phone'] ?? 'No Phone';
                    final String? avatarUrl = userData['avatarUrl'];
                    return UserInfoCard(name: name, phone: phone, avatarUrl: avatarUrl);
                  },
                ),
                
                // ✅ 6. 【新】房源列表
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _propertiesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                
                      if (snapshot.hasError) {
                        print("Error loading properties: ${snapshot.error}"); // 调试
                        return const Center(child: Text("Error loading properties", style: TextStyle(color: Colors.white70)));
                      }
                      
                      // 检查是否有数据，如果 0 个房源，显示提示
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'You have no properties yet.\nTap the + button to add one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                          ),
                        );
                      }
                      
                      // ✅ 7. 【新】使用 ListView 显示 PropertyCard
                      final properties = snapshot.data!.docs;
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16.0), // 在列表周围添加 padding
                        itemCount: properties.length,
                        itemBuilder: (context, index) {
                          final doc = properties[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          return PropertyCard(
                            propertyData: data,
                            propertyId: doc.id,
                            onTap: () {
                              // ✅ 8. 点击卡片导航到 AddPropertyScreen（编辑模式）
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddPropertyScreen(
                                    propertyId: doc.id, // 👈 传入 ID，进入编辑模式
                                  ),
                                ),
                              );
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
      
      // (底边栏和 FAB 保持不变)
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 导航到 AddPropertyScreen (不传 ID，进入添加模式)
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
