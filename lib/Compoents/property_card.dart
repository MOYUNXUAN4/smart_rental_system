// lib/Compoents/property_card.dart
import 'package:flutter/material.dart';
import 'glass_card.dart'; // 导入我们已有的毛玻璃卡片
import 'favorite_button.dart'; // 导入收藏按钮组件

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
  
  // ✅ 新增 margin 参数，允许外部控制边距
  final EdgeInsetsGeometry? margin;

  const PropertyCard({
    super.key,
    required this.propertyData,
    required this.propertyId,
    required this.onTap,
    this.showFavoriteButton = true,
    this.margin, // 接收参数
  });

  @override
  Widget build(BuildContext context) {
    final String communityName = propertyData['communityName'] ?? 'Unknown Property';
    final String unit = propertyData['unitNumber'] ?? '';
    final String floor = propertyData['floor'] ?? '';
    final double price = (propertyData['price'] ?? 0.0).toDouble();
    final List<String> imageUrls = List<String>.from(propertyData['imageUrls'] ?? []);
    final String thumbnailUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';
    
    final int bedrooms = propertyData['bedrooms'] ?? 0;
    final int bathrooms = propertyData['bathrooms'] ?? 0;
    final int parking = propertyData['parking'] ?? 0;
    final String furnishing = propertyData['furnishing'] ?? 'N/A';
    final String size = propertyData['size_sqft'] ?? 'N/A';

    return Padding(
      // ✅ 如果外部没传 margin，默认用 bottom: 16；如果传了(比如 zero)就用传进来的
      padding: margin ?? const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            GlassCard(
              child: SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1.1 左侧缩略图
                    Hero(
                      tag: propertyId,
                      child: ClipRRect(
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

            if (showFavoriteButton)
              Positioned(
                top: 10,
                right: 10,
                child: FavoriteButton(propertyId: propertyId),
              ),
          ],
        ),
      ),
    );
  }
}