import 'dart:ui';

import 'package:flutter/material.dart';

import '../Services/account_check_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> fadeBg;
  late Animation<double> cardOpacity;
  late Animation<double> cardScale;
  late Animation<double> logoOpacity;
  late Animation<double> logoScale;
  late Animation<double> logoGlow;
  late Animation<double> textOpacity;
  late Animation<Offset> textSlide;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // 1. background animation
    fadeBg = Tween(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.00, 0.90, curve: Curves.easeInOut)),
    );

    // 2. card animation
    cardOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.05, 0.30, curve: Curves.easeOut)),
    );
    cardScale = Tween(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.05, 0.40, curve: Curves.easeOutCubic)),
    );

    // 3. Logo animation
    logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.55, curve: Curves.easeOut)),
    );
    logoScale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic)),
    );
    logoGlow = Tween(begin: 30.0, end: 8.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.85, curve: Curves.easeOut)),
    );

    // 4. text animation
    textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.60, 1.0, curve: Curves.easeIn)),
    );
    textSlide = Tween(begin: const Offset(0, 0.20), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic)),
    );

    _ctrl.forward();

    // animation final status listener
    _ctrl.addStatusListener((st) {
      if (st == AnimationStatus.completed) _goNext();
    });
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => const AccountCheckScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 定义背景色
    const gradientColors = [
      Color(0xFF0E1C22), Color(0xFF173039), Color(0xFF355A68), Color(0xFF6F97A5),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0E1C22), // 兜底背景色
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            children: [
              // 1. 背景层
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.70, 1.0],
                    colors: gradientColors.map((c) => c.withOpacity(fadeBg.value)).toList(),
                  ),
                ),
              ),
              // 2. 内容层
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- 毛玻璃 Logo 卡片 ---
                    Opacity(
                      opacity: cardOpacity.value,
                      child: Transform.scale(
                        scale: cardScale.value,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              // 【调整】为了配合小文字，卡片尺寸微调为 160 (原 200)
                              width: 160, height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.04)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.1),
                              ),
                              child: Center(
                                child: Transform.scale(
                                  scale: logoScale.value,
                                  child: Opacity(
                                    opacity: logoOpacity.value,
                                    child: Padding(
                                      padding: const EdgeInsets.all(30), // Padding 微调
                                      // 确保图片资源存在
                                      child: Image.asset('assets/images/my_logo.png', fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 35),
                    
                    // --- 文字部分 (已调整为居中、缩小) ---
                    FadeTransition(
                      opacity: textOpacity,
                      child: SlideTransition(
                        position: textSlide,
                        child: const Text(
                          "Smart Rental System",
                          textAlign: TextAlign.center, // 确保文字水平居中
                          style: TextStyle(
                            fontSize: 18,                // 【修改】字体变小 (原 40)
                            fontWeight: FontWeight.w500, // 【修改】字重变细
                            letterSpacing: 3.5,          // 保持一定的字母间距，显得精致
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}