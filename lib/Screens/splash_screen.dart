import 'dart:ui';
import 'package:flutter/material.dart';

// ▼▼▼ 这里我用了相对路径，会自动向上找 Services 文件夹 ▼▼▼
// 只要你的目录结构是 lib/Services/account_check_screen.dart 就能找到
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

    // 1. 背景渐变动画
    fadeBg = Tween(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.00, 0.90, curve: Curves.easeInOut)),
    );

    // 2. 卡片动画
    cardOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.05, 0.30, curve: Curves.easeOut)),
    );
    cardScale = Tween(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.05, 0.40, curve: Curves.easeOutCubic)),
    );

    // 3. Logo 动画
    logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.55, curve: Curves.easeOut)),
    );
    logoScale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic)),
    );
    logoGlow = Tween(begin: 30.0, end: 8.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.85, curve: Curves.easeOut)),
    );

    // 4. 文字动画
    textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.60, 1.0, curve: Curves.easeIn)),
    );
    textSlide = Tween(begin: const Offset(0, 0.20), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic)),
    );

    _ctrl.forward();

    // 监听动画结束
    _ctrl.addStatusListener((st) {
      if (st == AnimationStatus.completed) _goNext();
    });
  }

  void _goNext() {
    // 动画播放完，跳转到原来的入口 AccountCheckScreen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => const AccountCheckScreen(), // 确保这里没报错
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
              // 背景层
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.70, 1.0],
                    colors: gradientColors.map((c) => c.withOpacity(fadeBg.value)).toList(),
                  ),
                ),
              ),
              // 内容层
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 毛玻璃卡片
                    Opacity(
                      opacity: cardOpacity.value,
                      child: Transform.scale(
                        scale: cardScale.value,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              width: 200, height: 200,
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
                                      padding: const EdgeInsets.all(35),
                                      // ▼▼▼ 确保你有这张图片，没有的话会报错 ▼▼▼
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
                    const SizedBox(height: 42),
                    // 文字
                    FadeTransition(
                      opacity: textOpacity,
                      child: SlideTransition(
                        position: textSlide,
                        child: const Text(
                          "SRS",
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, letterSpacing: 4, color: Colors.white),
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