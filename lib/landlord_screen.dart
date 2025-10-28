import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 1. 【更改】导入我们可重用的卡片
import 'user_info_card.dart'; 
// 2. 【移除】不再需要 profile_page.dart
// import 'profile_page.dart'; 

class LandlordScreen extends StatefulWidget {
  const LandlordScreen({super.key});

  @override
  State<LandlordScreen> createState() => _LandlordScreenState();
}

class _LandlordScreenState extends State<LandlordScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();

    // ... (你的调试日志可以保留，非常好) ...
    final user = FirebaseAuth.instance.currentUser;
    print("========== 🔍 Firebase 用户调试信息 ==========");
    print("是否检测到登录: ${user != null}");
    print("当前 UID: ${user?.uid}");
    print("===========================================");

    if (_uid != null) {
      _userStream =
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    } else {
      _userStream = Stream.error("User not logged in");
    }
  }

  // 3. 【移除】不再需要这个方法，UserInfoCard 会自己处理点击
  /*
  void _onAvatarTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Error loading user data"));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? 'Unknown Name';
          final String phone = userData['phone'] ?? 'No Phone';
          final String? avatarUrl = userData['avatarUrl'];

          // ... (你的调试日志可以保留) ...
          print("Firestore 加载成功 ✅");
          print("头像链接: ${avatarUrl ?? '(无头像)'}");

          return Column(
            children: [
              // 4. 【关键】用一行代码替换掉你原来整个 Card
              UserInfoCard(
                name: name,
                phone: phone,
                avatarUrl: avatarUrl,
              ),

              // ... (剩余部分不变) ...
              Expanded(
                child: Center(
                  child: Text(
                    'You have no properties yet.\nTap the + button to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 跳转到添加房源页面
        },
        tooltip: 'Add Property',
        child: const Icon(Icons.add_home_work),
      ),
    );
  }
}