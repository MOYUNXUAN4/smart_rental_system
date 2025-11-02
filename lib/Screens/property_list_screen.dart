import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_rental_system/Compoents/property_card.dart';
import 'package:smart_rental_system/screens/property_detail_screen.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  // ✅ 1. 创建一个 Stream 来获取 *所有* 房源
  late Stream<QuerySnapshot> _propertiesStream;

  @override
  void initState() {
    super.initState();
    _propertiesStream = FirebaseFirestore.instance
        .collection('properties')
        // .orderBy('createdAt', descending: true) // (可选) 按创建时间排序
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // 2. 使用 StreamBuilder 来构建列表
    return StreamBuilder<QuerySnapshot>(
      stream: _propertiesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          print("Error loading properties: ${snapshot.error}");
          return const Center(child: Text("Error loading properties", style: TextStyle(color: Colors.white70)));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No properties available right now.',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          );
        }
        
        // 3. 使用 ListView 显示 PropertyCard
        final properties = snapshot.data!.docs;
        
        return ListView.builder(
          // (使用 padding 确保列表不会被 AppBar 或底边栏遮挡)
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 100), 
          itemCount: properties.length,
          itemBuilder: (context, index) {
            final doc = properties[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return PropertyCard(
              propertyData: data,
              propertyId: doc.id,
              onTap: () {
                // ✅ 4. 点击卡片导航到 *详情页* (PropertyDetailScreen)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PropertyDetailScreen(
                      propertyId: doc.id, // 传递房源 ID
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}