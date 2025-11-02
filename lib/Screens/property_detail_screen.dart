import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 用于格式化日期
import 'package:smart_rental_system/screens/add_property_screen.dart'; // 导入编辑页面

// 1. 导入 Carousel Slider 和我们已有的组件
import 'package:carousel_slider/carousel_slider.dart'; 
import '../Compoents/glass_card.dart';
import '../Compoents/property_display_widgets.dart';
import '../Compoents/landlord_contact_card.dart';

// (谷歌地图导入保持为 TODO)
// import 'package:google_maps_flutter/google_maps_flutter.dart';

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId; 

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late Stream<DocumentSnapshot> _propertyStream;
  // (图片索引状态已移至 _ImageCarousel)

  @override
  void initState() {
    super.initState();
    _propertyStream = FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.propertyId)
        .snapshots();
  }

  // (打开全屏查看器的函数)
  void _openFullScreenImageViewer(List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
         actions: [
          // (编辑按钮)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                // 导航到 AddPropertyScreen 进行编辑
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPropertyScreen(propertyId: widget.propertyId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 渐变背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF153a44), Color(0xFF295a68),
                  Color(0xFF5d8fa0), Color(0xFF94bac4),
                ],
              ),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: _propertyStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text('Error: ${snapshot.error ?? "Property not found"}', style: const TextStyle(color: Colors.white70)));
              }

              final propertyData = snapshot.data!.data() as Map<String, dynamic>;
              
              // (安全地提取所有数据)
              final List<String> imageUrls = List<String>.from(propertyData['imageUrls'] ?? []);
              final String communityName = propertyData['communityName'] ?? 'N/A';
              final String unitNumber = propertyData['unitNumber'] ?? 'N/A';
              final String floor = propertyData['floor'] ?? 'N/A';
              final String address = "Unit $unitNumber, Floor $floor, $communityName"; 
              final String title = communityName; 
              final String landlordUid = propertyData['landlordUid'] ?? '';
              final double rent = (propertyData['price'] as num?)?.toDouble() ?? 0.0;
              final String description = propertyData['description'] ?? 'N/A';
              final int bedrooms = propertyData['bedrooms'] ?? 0;
              final int bathrooms = propertyData['bathrooms'] ?? 0;
              final int parking = propertyData['parking'] ?? 0;
              final int airConditioners = propertyData['airConditioners'] ?? 0;
              final String furnishing = propertyData['furnishing'] ?? 'N/A';
              final String size = propertyData['size_sqft'] ?? 'N/A';
              final List<String> facilities = List<String>.from(propertyData['facilities'] ?? []);
              final List<String> features = List<String>.from(propertyData['features'] ?? []);
              final Timestamp? availableDateTimestamp = propertyData['availableDate'];
              final String availableDate = availableDateTimestamp != null
                  ? DateFormat('yyyy-MM-dd').format(availableDateTimestamp.toDate())
                  : 'N/A';

              return SafeArea(
                bottom: false, 
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      // ✅ 1. 【新图片轮播】 (修复了闪屏)
                      if (imageUrls.isNotEmpty)
                        _ImageCarousel(
                          imageUrls: imageUrls,
                          onImageTap: (index) => _openFullScreenImageViewer(imageUrls, index),
                        )
                      else // 如果没有图片
                        Container(
                          height: MediaQuery.of(context).size.height * 0.3,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Center(
                            child: Icon(Icons.hide_image_outlined, color: Colors.white54, size: 50),
                          ),
                        ),
                      
                      // ✅ 2. 【新】房东联系卡片
                      if (landlordUid.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        LandlordContactCard(landlordUid: landlordUid),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // ✅ 3. 【新】主要信息显示 (使用 InfoChip)
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 8),
                             Text(address, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                             const SizedBox(height: 16),
                             Text(
                               'RM ${rent.toStringAsFixed(0)} / Month', 
                               style: const TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold)
                             ),
                             const SizedBox(height: 16),
                             Wrap(
                               spacing: 10, runSpacing: 10,
                               children: [
                                 if (bedrooms > 0) InfoChip(icon: Icons.king_bed_outlined, label: '$bedrooms Beds'),
                                 if (bathrooms > 0) InfoChip(icon: Icons.bathtub_outlined, label: '$bathrooms Baths'),
                                 if (parking > 0) InfoChip(icon: Icons.local_parking_outlined, label: '$parking Parking'),
                                 if (airConditioners > 0) InfoChip(icon: Icons.ac_unit, label: '$airConditioners AC'),
                                 if (size.isNotEmpty) InfoChip(icon: Icons.square_foot, label: '$size sqft'),
                               ],
                             ),
                             const Divider(color: Colors.white30, height: 32),
                             _buildDetailRow(Icons.chair, 'Furnishing', furnishing),
                             _buildDetailRow(Icons.calendar_today, 'Available Date', availableDate),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ 4. 【新】描述卡片
                       if (description.isNotEmpty) ...[
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Description'),
                              const SizedBox(height: 8),
                              Text(description, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // ✅ 5. 【新】特性/设施卡片 (使用 FeatureListItem)
                      if (features.isNotEmpty || facilities.isNotEmpty)
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (features.isNotEmpty) ...[
                                _buildSectionTitle('Property Features'),
                                const SizedBox(height: 12),
                                _buildFacilitiesGrid(features, isFeature: true),
                                if (facilities.isNotEmpty) const Divider(color: Colors.white30, height: 32),
                              ],
                              
                              if (facilities.isNotEmpty) ...[
                                _buildSectionTitle('Facilities'),
                                const SizedBox(height: 12),
                                _buildFacilitiesGrid(facilities, isFeature: false),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      
                      // ✅ 6. 谷歌地图 (占位符)
                      GlassCard(
                        child: Container(
                          height: 250,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias, 
                          child: const Center(
                            child: Text(
                              'Google Map (TODO: Add API Key)', 
                              style: TextStyle(color: Colors.white70)
                            )
                          ),
                          // child: GoogleMap( ... ),
                        ),
                      ),
                      const SizedBox(height: 100), // 底部填充
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // 底部浮动操作按钮 (联系房东)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement contact landlord functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact Landlord feature coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: const Text('Contact Landlord', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D5DC7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 辅助函数 (保持不变) ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesGrid(List<String> items, {bool isFeature = false}) {
    if (items.isEmpty) {
      return Text(isFeature ? "No features listed." : "No facilities listed.", style: const TextStyle(color: Colors.white70));
    }
    return Column( // 使用 Column 替代 Wrap，确保全宽
      children: items.map((item) {
        return FeatureListItem( // 使用我们导入的组件
          label: item,
          icon: isFeature ? _getFeatureIcon(item) : _getFacilityIcon(item),
        );
      }).toList(),
    );
  }

  // ✅ 7. 【已修复】: 替换了不存在的图标
  IconData _getFacilityIcon(String facility) {
    switch (facility.toLowerCase()) { 
      case '24-hour security': return Icons.security;
      case 'free indoor gym': return Icons.fitness_center;
      case 'free outdoor pool': return Icons.pool;
      case 'parking area': return Icons.local_parking;
      case 'playground': return Icons.child_friendly; 
      case 'garden': return Icons.eco;
      case 'elevator': return Icons.elevator;
      default: return Icons.check_circle_outline;
    }
  }

  // ✅ 8. 【已修复】: 为 Features 也提供图标 (已修复)
  IconData _getFeatureIcon(String feature) {
     switch (feature.toLowerCase()) {
      case 'balcony': return Icons.balcony;
      case 'air conditioner': return Icons.ac_unit;
      case 'water heater': return Icons.water_drop;
      case 'washing machine': return Icons.local_laundry_service;
      case 'refrigerator': return Icons.kitchen;
      case 'microwave': return Icons.microwave;
      case 'oven': return Icons.outdoor_grill; 
      case 'dishwasher': return Icons.wash; 
      case 'tv': return Icons.tv;
      case 'internet': return Icons.wifi;
      case 'study desk': return Icons.desk;
      case 'wardrobe': return Icons.checkroom; 
      default: return Icons.check_circle_outline;
    }
  }
}

// ===============================================================
// ✅ 9. 【新 Widget】: 独立的图片轮播器，用于解决闪屏问题
// ===============================================================
class _ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final Function(int) onImageTap;

  const _ImageCarousel({required this.imageUrls, required this.onImageTap});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _currentImageIndex = 0; // 这个 Widget 自己管理自己的状态

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CarouselSlider.builder(
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index, realIndex) {
              return GestureDetector( 
                onTap: () => widget.onImageTap(index), // 调用父级传递的回调
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
              );
            },
            options: CarouselOptions(
              // ✅ 10. 【已修改】: 缩小了图片占比
              height: MediaQuery.of(context).size.height * 0.3, // 30% 高度
              autoPlay: true,
              viewportFraction: 1.0,
              onPageChanged: (index, reason) {
                // 这里的 setState 只会重绘 _ImageCarousel
                setState(() {
                  _currentImageIndex = index; 
                });
              },
            ),
          ),
        ),
        // 小圆点指示器
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.imageUrls.asMap().entries.map((entry) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (Colors.white) // 使用白色作为指示器
                    .withOpacity(_currentImageIndex == entry.key ? 0.9 : 0.4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}


// ===============================================================
// 【全屏图片查看器】 (保持不变)
// ===============================================================
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8), 
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index; 
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer( 
              panEnabled: true, 
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain, 
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}