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
// ignore: unused_import
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


  void _checkAuthAndNavigate() async {
    // 1. Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    if (!isLoggedIn) {
      // 1.1 if not logged in, navigate to LoginScreen
      _navigateTo(const LoginScreen()); 
      return;
    }

    // 2. If logged in: Get user type and navigate
    Widget targetScreen;
    String userRoleFromDB = 'unknown'; 

    try {
      // get user document from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users') // make sure this matches your Firestore collection name
          .doc(user.uid)
          .get();

      
      userRoleFromDB = doc.exists && doc.data() != null 
          ? doc.data()!['userType'] ?? 'unknown' 
          : 'unknown';

      // navigate based on user type
      if (userRoleFromDB == 'Landlord') {
        // after landlord modification, Landlord also goes to HomeScreen
        targetScreen = const HomeScreen(userRole: 'Landlord');
      } else if (userRoleFromDB == 'Tenant') {
        // after tenant modification, Tenant goes to HomeScreen
        targetScreen = const HomeScreen(userRole: 'Tenant'); 
      } else {
        // unknown type or data issue, navigate back to login
        targetScreen = const LoginScreen();
        // ignore: avoid_print
        print('Warning: Unknown user type or missing data: $userRoleFromDB');
      }
    } catch (e) {
      // error handling: navigate to login on any error
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