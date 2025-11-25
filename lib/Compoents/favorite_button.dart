import 'package:flutter/material.dart';
import '../Services/favorite_service.dart';

class FavoriteButton extends StatefulWidget {
  final String propertyId;

  const FavoriteButton({super.key, required this.propertyId});

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> with SingleTickerProviderStateMixin {
  final FavoriteService _service = FavoriteService();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // 动画时长
    );
    
    // 弹跳效果：先放大到 1.5倍，再回到 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 1. 播放动画
    _controller.reset();
    _controller.forward();
    // 2. 调用后端切换状态
    _service.toggleFavorite(widget.propertyId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _service.isFavoriteStream(widget.propertyId),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;

        return GestureDetector(
          onTap: _handleTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // 背景：半透明黑，让星星更明显
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    // 选中是金色，未选中是白色
                    color: isFavorite ? Colors.amberAccent : Colors.white, 
                    size: 24,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}