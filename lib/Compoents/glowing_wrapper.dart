import 'package:flutter/material.dart';

class GlowingWrapper extends StatelessWidget {
  final bool isSelected;
  final Widget child;
  final double borderRadius;

  const GlowingWrapper({
    super.key,
    required this.isSelected,
    required this.child,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // 让光可以往外溢出
      children: [
        if (isSelected)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.85),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ---- 你的 PropertyCard，不改任何内容 ----
        child,
      ],
    );
  }
}
