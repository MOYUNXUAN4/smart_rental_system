// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// 1. 我们不再需要导入 AuthGate
// import 'auth_gate.dart'; 
// 2. 我们改成导入 HomeScreen
import 'home_screen.dart'; 
import 'Services/firebase_options.dart';

void main() async {
  // 确保 Flutter 绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 运行 App
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Rental System',
      theme: ThemeData(primarySwatch: Colors.blue),
      
      // 关键修改：
      // 把 App 的入口从 AuthGate()（登录路由）
      // 直接改成 HomeScreen()（主页）
      home: const HomeScreen(), 
    );
  }
}