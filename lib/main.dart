// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// (这些导入不再需要了，因为 AccountCheckScreen 会处理)
// import 'package:smart_rental_system/Screens/add_property_screen.dart';
// import 'package:smart_rental_system/Screens/home_screen.dart';
// import 'Screens/home_screen.dart';

import 'Services/firebase_options.dart';

// ▼▼▼ 【新】导入 AccountCheckScreen ▼▼▼
import 'package:smart_rental_system/Services/account_check_screen.dart';
// ▲▲▲ 【新】 ▲▲▲

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
      
      // ▼▼▼ 【BUG 修复】: 将 home 指向 AccountCheckScreen ▼▼▼
      home: const AccountCheckScreen()
      // ▲▲▲ 【BUG 修复】 ▲▲▲
    );
  }
}