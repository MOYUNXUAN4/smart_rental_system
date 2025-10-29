import 'dart:ui';
import 'package:flutter/material.dart';

class BottomNavItem {
  final IconData icon;
  final String label;
  const BottomNavItem({required this.icon, required this.label});
}

class AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const AnimatedBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<AnimatedBottomNav>
    with TickerProviderStateMixin {
  static const Color bottomNavStart = Color(0xFF1E3B70);
  static const Color bottomNavEnd = Color(0xFF295A8A);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [bottomNavStart, bottomNavEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26, blurRadius: 8, offset: Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final selected = index == widget.currentIndex;
                return GestureDetector(
                  onTap: () => widget.onTap(index),
                  child: _AnimatedNavItemWithRipple(
                    icon: item.icon,
                    label: item.label,
                    selected: selected,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✅ 同心扩散圈动画 + 平滑上升 + 柔和发光
class _AnimatedNavItemWithRipple extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _AnimatedNavItemWithRipple({
    required this.icon,
    required this.label,
    required this.selected,
    Key? key,
  }) : super(key: key);

  @override
  State<_AnimatedNavItemWithRipple> createState() =>
      _AnimatedNavItemWithRippleState();
}

class _AnimatedNavItemWithRippleState extends State<_AnimatedNavItemWithRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rippleScale = Tween<double>(begin: 0.0, end: 1.8).animate(
        CurvedAnimation(parent: _rippleController, curve: Curves.easeOutCubic));
    _rippleOpacity = Tween<double>(begin: 0.25, end: 0.0).animate(
        CurvedAnimation(parent: _rippleController, curve: Curves.easeOut));
    if (widget.selected) _rippleController.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _AnimatedNavItemWithRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      _rippleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = Colors.white;
    final unselectedColor = Colors.white70;
    final double targetScale = widget.selected ? 1.1 : 1.0;
    final double yOffset = widget.selected ? -2.0 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              final scale = _rippleScale.value;
              final opacity = _rippleOpacity.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            const Color(0xFF4DA3FF).withOpacity(opacity * 0.8),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: scale * 1.3,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            const Color(0xFF4DA3FF).withOpacity(opacity * 0.4),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          AnimatedSlide(
            offset: Offset(0, yOffset / 20),
            duration: const Duration(milliseconds: 250),
            child: AnimatedScale(
              scale: targetScale,
              duration: const Duration(milliseconds: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon,
                      color: widget.selected ? selectedColor : unselectedColor),
                  const SizedBox(height: 4),
                  Text(widget.label,
                      style: TextStyle(
                          color: widget.selected ? selectedColor : unselectedColor,
                          fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
