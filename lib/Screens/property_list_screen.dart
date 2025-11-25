import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_rental_system/Compoents/property_card.dart';
import 'package:smart_rental_system/screens/property_detail_screen.dart';

class PropertyListScreen extends StatefulWidget {
  // ✅ 1. 新增参数：用于接收从 SearchScreen 传过来的筛选结果
  final List<DocumentSnapshot>? preFilteredDocs;

  const PropertyListScreen({super.key, this.preFilteredDocs});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  late Stream<QuerySnapshot> _propertiesStream;

  @override
  void initState() {
    super.initState();
    // 只有在没有预筛选数据时，才需要初始化 Stream
    if (widget.preFilteredDocs == null) {
      _propertiesStream = FirebaseFirestore.instance
          .collection('properties')
          .orderBy('createdAt', descending: true) 
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ✅ 场景 1: 显示筛选结果 (从 SearchScreen 跳转过来)
    // ============================================================
    if (widget.preFilteredDocs != null) {
      return Scaffold(
        extendBodyBehindAppBar: true, // 让背景延伸到 AppBar 后面
        appBar: AppBar(
          title: Text("Filtered Results (${widget.preFilteredDocs!.length})"),
          backgroundColor: Colors.transparent, // 透明 AppBar
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        body: Stack(
          children: [
            // 1. 必须补上背景渐变 (因为它是独立页面，没有 HomeScreen 的背景)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
                ),
              ),
            ),
            // 2. 显示筛选后的列表
            ListView.builder(
              // 这里不需要 top: 100，因为有 AppBar 了，给一点正常间距即可
              padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 20),
              itemCount: widget.preFilteredDocs!.length,
              itemBuilder: (context, index) {
                final doc = widget.preFilteredDocs![index];
                return PropertyCard(
                  propertyData: doc.data() as Map<String, dynamic>,
                  propertyId: doc.id,
                  onTap: () => _navigateToDetail(doc.id),
                );
              },
            ),
          ],
        ),
      );
    }

    // ============================================================
    // ✅ 场景 2: 默认显示 (作为 HomeScreen 的 Tab) - 保持你原有的逻辑
    // ============================================================
    return StreamBuilder<QuerySnapshot>(
      stream: _propertiesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
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
        
        final properties = snapshot.data!.docs;
        
        return ListView.builder(
          // 保持你原有的 Padding，适应 HomeScreen 的布局
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 100), 
          itemCount: properties.length,
          itemBuilder: (context, index) {
            final doc = properties[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return PropertyCard(
              propertyData: data,
              propertyId: doc.id,
              onTap: () => _navigateToDetail(doc.id),
            );
          },
        );
      },
    );
  }

  // 辅助函数：跳转详情页
  void _navigateToDetail(String propertyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailScreen(propertyId: propertyId),
      ),
    );
  }
}