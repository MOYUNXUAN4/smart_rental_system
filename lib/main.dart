// lib/main.dart

import 'package:flutter/material.dart';
import 'login_screen.dart'; // 导入你的登录页面

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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