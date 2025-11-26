// lib/Compoents/property_card.dart
import 'package:flutter/material.dart';

import 'favorite_button.dart';
import 'glass_card.dart'; 

/// 用于在 PropertyCard 内部显示 "3 🛏️" 的迷你标签
class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final Map<String, dynamic> propertyData;
  final String propertyId;
  final VoidCallback onTap;
  final bool showFavoriteButton;
  
  // margin 参数 (为了 Favorites 页面的流光边框)
  final EdgeInsetsGeometry? margin;
  
  // heroTagPrefix 参数 (为了解决 Hero 动画冲突)
  final String heroTagPrefix;

  const PropertyCard({
    super.key,
    required this.propertyData,
    required this.propertyId,
    required this.onTap,
    this.showFavoriteButton = true,
    this.margin,
    this.heroTagPrefix = 'global',
  });

  @override
  Widget build(BuildContext context) {
    final String communityName = propertyData['communityName'] ?? 'Unknown Property';
    final String unit = propertyData['unitNumber'] ?? '';
    final String floor = propertyData['floor'] ?? '';
    final double price = (propertyData['price'] as num?)?.toDouble() ?? 0.0;
    final List<String> imageUrls = List<String>.from(propertyData['imageUrls'] ?? []);
    final String thumbnailUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';
    
    // ✅ 检查是否有 360 全景图
    final bool has360 = propertyData['360ImageUrl'] != null && propertyData['360ImageUrl'].toString().isNotEmpty;
    
    final int bedrooms = propertyData['bedrooms'] ?? 0;
    final int bathrooms = propertyData['bathrooms'] ?? 0;
    final int parking = propertyData['parking'] ?? 0;
    final String furnishing = propertyData['furnishing'] ?? 'N/A';
    final String size = propertyData['size_sqft'] ?? 'N/A';

    return Padding(
      // 使用传入的 margin，如果没有则默认 bottom: 16
      padding: margin ?? const EdgeInsets.only(bottom: 16.0),
      child: Stack(
        children: [
          // ========================================================
          // 1. 底层：卡片主体 (负责跳转详情)
          // ========================================================
          GestureDetector(
            onTap: onTap, // 点击卡片跳转
            behavior: HitTestBehavior.opaque, // 确保空白处也能响应
            child: GlassCard(
              child: SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1.1 左侧缩略图区域
                    Hero(
                      tag: "${heroTagPrefix}_$propertyId",
                      child: Stack(
                        children: [
                          // 图片本体
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Container(
                              width: 120,
                              height: 120,
                              color: Colors.white.withOpacity(0.1),
                              child: thumbnailUrl.isNotEmpty
                                  ? Image.network(
                                      thumbnailUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) =>
                                          progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                                      errorBuilder: (context, error, stack) =>
                                          const Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 40),
                                    )
                                  : const Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 40),
                            ),
                          ),
                          
                          // ✅ 1.1.1 新增：360 标识 (如果有 360 图)
                       // ✅ 风格 3：悬浮黑胶囊 (放右下角)
                          if (has360)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.vrpano, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      "360° Tour",
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),

                    // 1.2 中间信息
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 24.0),
                                child: Text(
                                  communityName,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'Unit $unit, Floor $floor',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (bedrooms > 0) _MiniInfoChip(icon: Icons.king_bed_outlined, label: '$bedrooms'),
                              if (bathrooms > 0) _MiniInfoChip(icon: Icons.bathtub_outlined, label: '$bathrooms'),
                              if (parking > 0) _MiniInfoChip(icon: Icons.local_parking_outlined, label: '$parking'),
                            ],
                          ),
                          Text(
                            '$furnishing • $size sq.ft.',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 1.3 右侧租金
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'RM ${price.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFFFFA500), fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Text('/Month', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ========================================================
          // 2. 顶层：收藏按钮 (加了防穿透护盾)
          // ========================================================
          if (showFavoriteButton)
            Positioned(
              top: 10,
              right: 10,
              // ✅ 修复核心：这层 GestureDetector 专门负责拦截点击
              child: GestureDetector(
                onTap: () {
                  // 这里什么都不做，单纯为了消耗掉点击事件
                  // 这样点击就不会穿透到底下的 Card 上去了
                },
                // Opaque 确保即使点击了透明区域也能被拦截
                behavior: HitTestBehavior.opaque,
                child: FavoriteButton(propertyId: propertyId),
              ),
            ),
        ],
      ),
    );
  }
}