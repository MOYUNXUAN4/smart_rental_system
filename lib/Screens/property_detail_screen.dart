// lib/screens/property_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ✅ 1. 导入 Carousel Slider
import 'package:carousel_slider/carousel_slider.dart'; 

// 导入我们新建的可重用组件
import '../Compoents/glass_card.dart';
import '../Compoents/property_display_widgets.dart';
import '../Compoents/landlord_contact_card.dart';

// (谷歌地图导入保持为 TODO)
// import 'package:google_maps_flutter/google_maps_flutter.dart';

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId; 

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late Stream<DocumentSnapshot> _propertyStream;

  // ✅ 2. 为图片轮播添加状态变量
  int _currentImageIndex = 0; 

  // ✅ (额外改进) 完善图标映射
  // (请确保这里的 Key 与您 AddPropertyScreen 中的 _featureOptions Key 完全一致)
  final Map<String, IconData> _featureIconMap = {
    'Refrigerator': Icons.kitchen,
    'Washing Machine': Icons.local_laundry_service,
    'Wifi': Icons.wifi,
    // (您可以从 add_property_screen.dart 复制所有非数字项到这里)
  };
  // (请确保这里的 Key 与您 AddPropertyScreen 中的 _facilityOptions Key 完全一致)
  final Map<String, IconData> _facilityIconMap = {
    '24-hour Security': Icons.security,
    'Free Indoor Gym': Icons.fitness_center,
    'Free Outdoor Pool': Icons.pool,
    'Parking Area': Icons.local_parking,
  };


  @override
  void initState() {
    super.initState();
    _propertyStream = FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.propertyId)
        .snapshots(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                return const Center(child: Text("Property not found.", style: TextStyle(color: Colors.white70)));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              
              // (安全地提取所有数据)
              final String communityName = data['communityName'] ?? 'Unknown Community';
              final String unitNumber = data['unitNumber'] ?? 'N/A';
              final String floor = data['floor'] ?? 'N/A';
              final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
              final String landlordUid = data['landlordUid'] ?? '';
              final double price = (data['price'] ?? 0.0).toDouble();
              final String size = data['size_sqft'] ?? 'N/A';
              final String furnishing = data['furnishing'] ?? 'N/A';
              final int bedrooms = data['bedrooms'] ?? 0;
              final int bathrooms = data['bathrooms'] ?? 0;
              final int parking = data['parking'] ?? 0;
              final int airConditioners = data['airConditioners'] ?? 0;
              final String description = data['description'] ?? 'No description provided.';
              final Timestamp availableTimestamp = data['availableDate'] ?? Timestamp.now();
              final String availableDate = DateFormat('dd/MM/yyyy').format(availableTimestamp.toDate());
              final List<String> features = List<String>.from(data['features'] ?? []);
              final List<String> facilities = List<String>.from(data['facilities'] ?? []);

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      // ✅ 3. 【新】房产图片轮播
                      if (imageUrls.isNotEmpty)
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: CarouselSlider.builder(
                                itemCount: imageUrls.length,
                                itemBuilder: (context, index, realIndex) {
                                  return Image.network(
                                    imageUrls[index],
                                    fit: BoxFit.cover,
                                    width: MediaQuery.of(context).size.width, // 占满宽度
                                    // 加载时的占位符
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white70,
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    // 加载失败的占位符
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.white.withOpacity(0.1),
                                        child: const Center(
                                          child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 40),
                                        ),
                                      );
                                    },
                                  );
                                },
                                options: CarouselOptions(
                                  height: 200, // 固定高度
                                  autoPlay: true, // 自动播放
                                  viewportFraction: 1.0, // 一次只显示一张
                                  onPageChanged: (index, reason) {
                                    setState(() {
                                      _currentImageIndex = index; // 更新小圆点
                                    });
                                  },
                                ),
                              ),
                            ),
                            // 小圆点指示器
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: imageUrls.asMap().entries.map((entry) {
                                return Container(
                                  width: 8.0,
                                  height: 8.0,
                                  margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(_currentImageIndex == entry.key ? 0.9 : 0.4),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        )
                      else // 如果没有图片，显示占位符
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Center(
                            child: Icon(Icons.hide_image_outlined, color: Colors.white54, size: 50),
                          ),
                        ),
                      
                      // 房东联系卡片
                      if (landlordUid.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        LandlordContactCard(landlordUid: landlordUid),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // 主要信息显示
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(communityName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 8),
                             Text('Unit $unitNumber, Floor $floor', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                             const SizedBox(height: 16),
                             Text(
                               'RM ${price.toStringAsFixed(0)} / Month', 
                               style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
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
                             Text(furnishing, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 4),
                             Text('Available from: $availableDate', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 描述卡片
                       if (description.isNotEmpty) ...[
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Description', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(description, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // 特性和设施 (Features & Facilities)
                      if (features.isNotEmpty || facilities.isNotEmpty)
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (features.isNotEmpty) ...[
                                const Text('Features', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                ...features.map((label) => FeatureListItem(
                                  // ✅ (额外改进) 使用 _getIconForFeature
                                  icon: _getIconForFeature(label), 
                                  label: label
                                )).toList(),
                                if (facilities.isNotEmpty) const Divider(color: Colors.white30, height: 32),
                              ],
                              
                              if (facilities.isNotEmpty) ...[
                                const Text('Facilities', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                ...facilities.map((label) => FeatureListItem(
                                  // ✅ (额外改进) 使用 _getIconForFacility
                                  icon: _getIconForFacility(label), 
                                  label: label
                                )).toList(),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      
                      // 谷歌地图 (占位符)
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
                      
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 辅助函数 (用于匹配图标) ---

  IconData _getIconForFeature(String label) {
    // ✅ (额外改进) 匹配 'Air Conditioner' (来自 add_property_screen)
    if (label == 'Air Conditioner') return Icons.ac_unit; 
    return _featureIconMap[label] ?? Icons.check; // 默认图标
  }
  
  IconData _getIconForFacility(String label) {
    return _facilityIconMap[label] ?? Icons.check; // 默认图标
  }
}