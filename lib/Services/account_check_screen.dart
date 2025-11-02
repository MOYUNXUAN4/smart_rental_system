// lib/screens/account_check_screen.dart

import 'package:flutter/material.dart';
// --- 核心 Firebase 依赖 ---
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
// ----------------------------

// ==========================================================
// ⚠️ 检查导入路径 START
// 请根据您的文件结构，仔细检查以下导入路径是否正确：
// ==========================================================

// 1. 未登录时跳转的界面 (根据您的 AuthGate 逻辑，是 LoginScreen)
import '../../LogIn&Register/login_screen.dart'; 

// 2. 房东仪表板
import '../../LogIn&Register/landlord_screen.dart';

// 3. 租户仪表板
import '../../LogIn&Register/tenant_screen.dart';

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

    try {
      // 从 Firestore 获取用户类型
      final doc = await FirebaseFirestore.instance
          .collection('users') // 确保集合名称正确
          .doc(user!.uid)
          .get();

      // 根据 AuthGate 逻辑，获取 userType 字段
      final userType = doc.exists && doc.data() != null 
          ? doc.data()!['userType'] ?? 'unknown' 
          : 'unknown';

      // 导航到对应的仪表板 (注意：使用 'Landlord' 和 'Tenant' 匹配您 AuthGate 的逻辑)
      if (userType == 'Landlord') {
        targetScreen = const LandlordScreen();
      } else if (userType == 'Tenant') {
        targetScreen = const TenantScreen();
      } else {
        // 未知类型或数据异常，导回登录界面
        targetScreen = const LoginScreen(); 
        print('Warning: Unknown user type or missing data: $userType');
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
    // 检查 Widget 是否仍然在 Widget Tree 中 (避免在 dispose 后调用 setState/Navigator)
    if (!mounted) return; 

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 显示加载界面，直到跳转完成
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}