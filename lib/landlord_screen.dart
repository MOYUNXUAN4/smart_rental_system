// lib/landlord_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 导入头像上传页
import 'profile_page.dart';

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

    // ✅ 【调试输出：验证 Firebase 当前登录状态】
    final user = FirebaseAuth.instance.currentUser;
    print("========== 🔍 Firebase 用户调试信息 ==========");
    print("是否检测到登录: ${user != null}");
    print("当前 UID: ${user?.uid}");
    print("用户邮箱: ${user?.email}");
    print("===========================================");

    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    } else {
      _userStream = Stream.error("User not logged in");
    }
  }

  // 跳转到头像上传页面
  void _onAvatarTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

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
            print("⚠️ Firestore 加载失败或找不到用户文档: $_uid");
            return const Center(child: Text("Error loading user data"));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? 'Unknown Name';
          final String phone = userData['phone'] ?? 'No Phone';
          final String? avatarUrl = userData['avatarUrl'];

          // ✅ 【调试输出：确认 Firestore 获取的数据】
          print("Firestore 加载成功 ✅");
          print("用户姓名: $name");
          print("手机号: $phone");
          print("头像链接: ${avatarUrl ?? '(无头像)'}");

          return Column(
            children: [
              Card(
                elevation: 4.0,
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // 点击头像 -> 跳转上传页面
                      GestureDetector(
                        onTap: _onAvatarTapped,
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Icon(Icons.camera_alt, size: 30, color: Colors.grey.shade600)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(phone,
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey.shade700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
