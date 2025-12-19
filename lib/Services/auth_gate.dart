import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Screens/landlord_screen.dart';
import '../Screens/tenant_screen.dart';
// 如果你的主页 wrapper 叫 HomeScreen，请引入它。
// 这里假设 TenantScreen 是包含底部导航栏的主界面容器。

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. 等待状态：显示加载圈，避免闪屏
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. ✅ 已登录：进入分发器，判断是房东还是租客
        if (snapshot.hasData) {
          return UserTypeDispatcher(user: snapshot.data!);
        }

        // 3. 🔥🔥🔥 未登录（核心修改）：不再去 LoginScreen，而是直接去首页
        // 这里返回 TenantScreen，意味着游客默认看到的是租客界面（看房列表）
        // 请确保 TenantScreen 内部能处理 currentUser 为 null 的情况
        return const TenantScreen(); 
      },
    );
  }
}

class UserTypeDispatcher extends StatelessWidget {
  final User user;

  const UserTypeDispatcher({super.key, required this.user});

  Future<String> _getUserType() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final userType = doc.data()!['userType'] ?? 'unknown';
        print("UserType from DB: '$userType'");
        return userType;
      } else {
        // 用户文档不存在，自动创建默认类型
        await docRef.set({
          'userType': 'Tenant',
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("User document created for UID: ${user.uid}, default type: Tenant");
        return 'Tenant';
      }
    } catch (e) {
      print('Get UserType failed: $e');
      return 'error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserType(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == 'error') {
          return const Scaffold(
            body: Center(child: Text('Failed to load user information...')),
          );
        }

        final userType = snapshot.data;
        print("Checking userType: '$userType'");

        if (userType == 'Landlord') {
          return const LandlordScreen();
        } else if (userType == 'Tenant') {
          return const TenantScreen();
        } else {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Unknown user type: $userType'),
                  ElevatedButton(
                    child: const Text('Sign Out'),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}