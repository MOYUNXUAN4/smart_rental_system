// lib/Services/account_check_screen.dart

// ignore_for_file: avoid_print, duplicate_ignore

import 'package:flutter/material.dart';
// --- 核心 Firebase 依赖 ---
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
// ----------------------------

// ==========================================================
// ⚠️ 检查导入路径 START
// ==========================================================

// 1. 未登录时跳转的界面
import '../Screens/login_screen.dart'; 

// 2. 房东仪表板 (当房东点击 "My Account" 时会用到)
import '../Screens/landlord_screen.dart';

// 3. 租户的主页 (HomeScreen)
import '../Screens/home_screen.dart';

// ==========================================================
// ⚠️ 检查导入路径 END
// ==========================================================

class AccountCheckScreen extends StatefulWidget {
  const AccountCheckScreen({super.key});

  @override
  State<AccountCheckScreen> createState() => _AccountCheckScreenState();
}

class _AccountCheckScreenState extends State<AccountCheckScreen> {

  @override
  void initState() {
    super.initState();
    // 确保在 Widget 构建完成后执行异步检查和导航
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  // 使用 Firebase 逻辑的核心导航函数
  void _checkAuthAndNavigate() async {
    // 1. 检查登录状态
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    if (!isLoggedIn) {
      // 1.1 未登录：跳转到 LoginScreen
      _navigateTo(const LoginScreen()); 
      return;
    }

    // 2. 已登录：获取用户类型并导航
    Widget targetScreen;
    String userRoleFromDB = 'unknown'; 

    try {
      // 从 Firestore 获取用户类型
      final doc = await FirebaseFirestore.instance
          .collection('users') // 确保集合名称正确
          .doc(user!.uid)
          .get();

      // (保持使用 'userType' 字段, 这是正确的)
      userRoleFromDB = doc.exists && doc.data() != null 
          ? doc.data()!['userType'] ?? 'unknown' 
          : 'unknown';

      // 导航到对应的仪表板
      if (userRoleFromDB == 'Landlord') {
        // ▼▼▼ 【你要求的修改】 ▼▼▼
        // 房东登录后，也跳转到 HomeScreen，但传递 'Landlord' 角色
        targetScreen = const HomeScreen(userRole: 'Landlord');
        // ▲▲▲ 【修改结束】 ▲▲▲
      } else if (userRoleFromDB == 'Tenant') {
        // 租客登录后，跳转到 HomeScreen，传递 'Tenant' 角色
        targetScreen = const HomeScreen(userRole: 'Tenant'); 
      } else {
        // 未知类型或数据异常，导回登录界面
        targetScreen = const LoginScreen(); 
        // ignore: avoid_print
        print('Warning: Unknown user type or missing data: $userRoleFromDB');
      }
    } catch (e) {
      // 错误处理，例如网络问题或权限问题
      print('Error fetching user type in AccountCheckScreen: $e');
      targetScreen = const LoginScreen();
    }

    _navigateTo(targetScreen);
  }

  // 导航辅助函数：使用 pushReplacement 清除当前堆栈，防止返回
  void _navigateTo(Widget targetScreen) {
    if (!mounted) return; 

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 显示加载界面，直到跳转完成
    return const Scaffold(
      backgroundColor: Color(0xFF153a44), // 保持和你的主题一致
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}