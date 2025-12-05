// lib/Screens/compare_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../Compoents/glass_card.dart';

class CompareScreen extends StatefulWidget {
  final List<Map<String, dynamic>> properties;

  const CompareScreen({super.key, required this.properties});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late double minPrice;
  late double maxSize;
  late int maxBedrooms;
  late int maxBathrooms;
  late int maxParking;
  late int bestFurnishScore;
  
  late Map<String, int> featureCounts;

  @override
  void initState() {
    super.initState();
    _calculateBestValues();
  }

  void _calculateBestValues() {
    if (widget.properties.isEmpty) return;

    try {
      minPrice = widget.properties
          .map((p) => (p['price'] ?? 0).toDouble())
          .cast<double>()
          .reduce((a, b) => min(a, b));

      maxSize = widget.properties
          .map((p) => double.tryParse(p['size_sqft']?.toString() ?? '0') ?? 0.0)
          .cast<double>()
          .reduce((a, b) => max(a, b));

      maxBedrooms = widget.properties
          .map((p) => (p['bedrooms'] ?? 0) as int)
          .cast<int>()
          .reduce((a, b) => max(a, b));

      maxBathrooms = widget.properties
          .map((p) => (p['bathrooms'] ?? 0) as int)
          .cast<int>()
          .reduce((a, b) => max(a, b));

      maxParking = widget.properties
          .map((p) => (p['parking'] ?? 0) as int)
          .cast<int>()
          .reduce((a, b) => max(a, b));

      bestFurnishScore = widget.properties
          .map((p) => _getFurnishingScore(p['furnishing'] ?? ''))
          .cast<int>()
          .reduce((a, b) => max(a, b));


      featureCounts = {};
      for (var p in widget.properties) {
        final List<String> feats = List<String>.from(p['features'] ?? []);
        for (var f in feats) {
          final key = f.trim(); 
          featureCounts[key] = (featureCounts[key] ?? 0) + 1;
        }
      }
    } catch (e) {
      print("Calculation error: $e");
    }
  }

  int _getFurnishingScore(String furnishing) {
    final s = furnishing.toLowerCase();
    if (s.contains('fully')) return 3;
    if (s.contains('half') || s.contains('partly')) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF153a44);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Comparison Result"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [bgDark, Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 50),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.properties.map((data) {
                    final double pPrice = (data['price'] ?? 0).toDouble();
                    final double pSize = double.tryParse(data['size_sqft']?.toString() ?? '0') ?? 0;
                    final int pBeds = data['bedrooms'] ?? 0;
                    final int pBaths = data['bathrooms'] ?? 0;
                    final int pPark = data['parking'] ?? 0;
                    final int pFurnishScore = _getFurnishingScore(data['furnishing'] ?? '');
                    final List<String> pFeatures = List<String>.from(data['features'] ?? []);

                    return _buildComparisonColumn(
                      context, 
                      data,
                      isBestPrice: pPrice == minPrice,
                      isBestSize: pSize == maxSize && pSize > 0,
                      isBestBed: pBeds == maxBedrooms,
                      isBestBath: pBaths == maxBathrooms,
                      isBestPark: pPark == maxParking,
                      isBestFurnish: pFurnishScore == bestFurnishScore,
                      features: pFeatures,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonColumn(
    BuildContext context, 
    Map<String, dynamic> data, {
    required bool isBestPrice,
    required bool isBestSize,
    required bool isBestBed,
    required bool isBestBath,
    required bool isBestPark,
    required bool isBestFurnish,
    required List<String> features,
  }) {
    final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
    final String image = imageUrls.isNotEmpty ? imageUrls[0] : '';
    final String title = data['communityName'] ?? 'Unknown';
    
    final double price = (data['price'] ?? 0).toDouble();
    final String size = data['size_sqft']?.toString() ?? '-';
    final int bedrooms = data['bedrooms'] ?? 0;
    final int bathrooms = data['bathrooms'] ?? 0;
    final int parking = data['parking'] ?? 0;
    final String furnishing = data['furnishing'] ?? '-';

    final double width = MediaQuery.of(context).size.width * 0.46;

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          // 头部图片
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    color: Colors.white10,
                    child: image.isNotEmpty
                        ? Image.network(image, fit: BoxFit.cover)
                        : const Icon(Icons.image, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSimpleCard(label: "Price/Mo", value: "RM ${price.toStringAsFixed(0)}", isWinner: isBestPrice, isPrice: true),
          _buildSimpleCard(label: "Size", value: "$size sqft", isWinner: isBestSize),
          _buildSimpleCard(label: "Bedrooms", value: "$bedrooms", isWinner: isBestBed),
          _buildSimpleCard(label: "Bathrooms", value: "$bathrooms", isWinner: isBestBath),
          _buildSimpleCard(label: "Parking", value: "$parking", isWinner: isBestPark),
          _buildSimpleCard(label: "Furnishing", value: furnishing, isWinner: isBestFurnish),

          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(" Features", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          if (features.isEmpty)
            const Text("-", style: TextStyle(color: Colors.white54))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: features.map((f) {
                // ✅ 独有 Feature 判断逻辑：
                // 如果该 Feature 出现的次数 < 房源总数，说明并不是每家都有，那么拥有的这家就是“独特优势”
                bool isUnique = (featureCounts[f.trim()] ?? 0) < widget.properties.length;
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnique ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: isUnique ? Colors.greenAccent : Colors.transparent, 
                      width: 1
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 11)),
                );
              }).toList(),
            )
        ],
      ),
    );
  }

  Widget _buildSimpleCard({required String label, required String value, required bool isWinner, bool isPrice = false}) {
    final Color winnerColor = Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: isWinner 
            ? Border.all(color: winnerColor, width: 1.5) 
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          if (isWinner)
            Icon(Icons.check_circle, color: winnerColor, size: 16),
        ],
      ),
    );
  }
}