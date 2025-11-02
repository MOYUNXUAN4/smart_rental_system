// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:smart_rental_system/Screens/add_property_screen.dart';
import 'package:smart_rental_system/Screens/home_screen.dart';

// 导入我们测试合同生成的界面
// ignore: duplicate_import
import 'Screens/home_screen.dart';
import 'Services/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Rental System',
      theme: ThemeData(primarySwatch: Colors.blue),
      
      // 直接跳转到合同测试页面
      home: const HomeScreen()
    );
  }
}
