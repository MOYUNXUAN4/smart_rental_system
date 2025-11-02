import 'package:flutter/material.dart';
import 'glass_card.dart'; // 导入我们已有的毛玻璃卡片

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
          Icon(icon, color: Colors.white70, size: 14), // 图标更小
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12, // 字体更小
            ),
          ),
        ],
      ),
    );
  }
}


/// 房东仪表板上显示的房源卡片
class PropertyCard extends StatelessWidget {
  final Map<String, dynamic> propertyData;
  final String propertyId;
  final VoidCallback onTap; 

  const PropertyCard({
    super.key,
    required this.propertyData,
    required this.propertyId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 安全地从 Map 中提取数据，并提供默认值
    final String communityName = propertyData['communityName'] ?? 'Unknown Property';
    final String unit = propertyData['unitNumber'] ?? '';
    final String floor = propertyData['floor'] ?? '';
    final double price = (propertyData['price'] ?? 0.0).toDouble();
    final List<String> imageUrls = List<String>.from(propertyData['imageUrls'] ?? []);
    final String thumbnailUrl = imageUrls.isNotEmpty ? imageUrls[0] : ''; // 使用第一张图作为缩略图
    
    final int bedrooms = propertyData['bedrooms'] ?? 0;
    final int bathrooms = propertyData['bathrooms'] ?? 0;
    final int parking = propertyData['parking'] ?? 0;
    final String furnishing = propertyData['furnishing'] ?? 'N/A';
    final String size = propertyData['size_sqft'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // 卡片之间的间距
      child: GestureDetector(
        onTap: onTap, // 触发导航
        child: GlassCard( // 使用我们已有的毛玻璃卡片
          // ✅ 关键改动1: 限制卡片高度，并使用 Column + Row 结构
          // 我们给 GlassCard 内部的 Column 一个固定高度
          child: SizedBox( 
            height: 150, // ✅ 固定卡片高度为 150
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 缩略图 - 占比更大
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    width: 120, // ✅ 图片宽度增加
                    height: 120, // ✅ 图片高度增加 (使其保持正方形且更大)
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
                const SizedBox(width: 16),

                // 2. 中间信息（小区名, 楼层, 卧室/卫生间等）- 使用 Expanded 智能布局
                Expanded(
                  flex: 3, // ✅ 中间信息区占比
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 空间均匀分布
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            communityName, 
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1, // 限制行数，避免溢出
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Unit $unit, Floor $floor', 
                            style: const TextStyle(color: Colors.white70, fontSize: 13), // 字体稍小
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      
                      // 卧室, 卫生间, 停车场 (使用迷你标签)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (bedrooms > 0) _MiniInfoChip(icon: Icons.king_bed_outlined, label: '$bedrooms'),
                          if (bathrooms > 0) _MiniInfoChip(icon: Icons.bathtub_outlined, label: '$bathrooms'),
                          if (parking > 0) _MiniInfoChip(icon: Icons.local_parking_outlined, label: '$parking'),
                        ],
                      ),
                      // 装修情况和面积
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

                // 3. 右侧租金 - 占比更大
                Expanded(
                  flex: 1, // ✅ 价格区域占比
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 与其他内容对齐
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RM ${price.toStringAsFixed(0)}', 
                        style: const TextStyle(color: Color(0xFFFFA500), fontSize: 20, fontWeight: FontWeight.bold), 
                      ),
                      const Text(
                        '/Month',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}