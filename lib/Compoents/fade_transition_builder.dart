import 'package:flutter/material.dart';

class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 🌟 这里就是之前的淡入淡出逻辑
    // 你可以调整 duration，但 Builder 不支持直接传 duration，
    // 它通常使用 Theme 的默认速度 (约300ms)。
    // 如果觉得太快，那种情况才需要去单独封装 Route。
    
    const curve = Curves.easeInOut;
    var tween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

    return FadeTransition(
      opacity: animation.drive(tween),
      child: child,
    );
  }
}