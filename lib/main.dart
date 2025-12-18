import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// ✅ 1. 引入 Stripe 包
import 'package:flutter_stripe/flutter_stripe.dart';
// ✅ 2. 引入动画构建器 (请确保路径正确)
import 'package:smart_rental_system/Compoents/fade_transition_builder.dart';
import 'package:smart_rental_system/Services/firebase_options.dart';

import 'Screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ 3. 配置 Stripe (已填入你的公钥)
  Stripe.publishableKey = 'pk_test_51SeDucL7fpWOo6Fl4norAYosjDiupQufgRP7ak6u2Q7JFO5X5rNVMF1ssfCiijx3T7t2zh6jhI0Prx0mVIB5x0Jk00XBgywnlO'; 
  await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Rental System',
      
      // 🔥🔥🔥 核心修改在这里：ThemeData 🔥🔥🔥
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // 你的极光深色背景
        scaffoldBackgroundColor: const Color(0xFF0E1C22),
        
        // ✅ 全局路由动画配置 (一键生效)
        // 加上这一段后，整个 App 所有的 Navigator.push 都会变成淡入淡出
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            // Android 默认是上下/缩放，现在改成淡入淡出
            TargetPlatform.android: FadePageTransitionsBuilder(),
            // iOS 默认是左右滑动，现在也强制改成淡入淡出
            TargetPlatform.iOS: FadePageTransitionsBuilder(),
          },
        ),
      ),
      
      home: const SplashScreen(),
    );
  }
}