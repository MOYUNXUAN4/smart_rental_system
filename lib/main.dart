// lib/main.dart

import 'package:flutter/material.dart';
import 'login_screen.dart'; // 导入你的登录页面

// --- 步骤 1: 导入 Firebase 核心包 ---
import 'package:firebase_core/firebase_core.dart';
// --- 步骤 2: 导入你生成的 firebase_options.dart 文件 ---
// (这个文件必须存在于 lib/ 文件夹中)
import 'firebase_options.dart';

// --- 步骤 3: 将 main 函数修改为 async ---
void main() async {
  // --- 步骤 4: 确保 Flutter 绑定已初始化 ---
  // 这是在 runApp 之前调用 Firebase 所必需的
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- 步骤 5: 初始化 Firebase ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- 步骤 6: 运行你的 App ---
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Rental System',
      theme: ThemeData(
        // 启用 Material 3
        useMaterial3: true,
        // 你可以在这里定义你的 App 颜色主题
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // 将 LoginScreen 设置为 App 的首页
      home: const LoginScreen(),
    );
  }
}