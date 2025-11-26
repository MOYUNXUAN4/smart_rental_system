import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 请确保这些路径与你项目实际路径一致
import 'package:smart_rental_system/Compoents/property_card.dart';
import 'package:smart_rental_system/Screens/compare_screen.dart';
import 'package:smart_rental_system/Screens/search_screen.dart';
import 'package:smart_rental_system/screens/property_detail_screen.dart';

class PropertyListScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? preFilteredData;

  const PropertyListScreen({super.key, this.preFilteredData});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  late Stream<QuerySnapshot> _propertiesStream;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<Map<String, dynamic>> _currentDisplayData = [];

  @override
  void initState() {
    super.initState();
    if (widget.preFilteredData == null) {
      _propertiesStream = FirebaseFirestore.instance
          .collection('properties')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _goToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  void _handleItemTap(String propertyId) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedIds.contains(propertyId)) {
          _selectedIds.remove(propertyId);
        } else {
          if (_selectedIds.length >= 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Compare up to 3 properties"),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          _selectedIds.add(propertyId);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PropertyDetailScreen(propertyId: propertyId),
        ),
      );
    }
  }

  void _navigateToCompare() {
    if (_selectedIds.length < 2) return;

    final selectedDocs = _currentDisplayData
        .where((data) => _selectedIds.contains(data['id']))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompareScreen(properties: selectedDocs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF153a44);
    const Color accentBlue = Color(0xFF1D5DC7);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 背景渐变
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgDark,
                  Color(0xFF295a68),
                  Color(0xFF5d8fa0),
                  Color(0xFF94bac4),
                ],
              ),
            ),
          ),

          // 列表
          if (widget.preFilteredData != null)
            _buildListView(widget.preFilteredData!)
          else
            StreamBuilder<QuerySnapshot>(
              stream: _propertiesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No properties found.",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                final List<Map<String, dynamic>> dataList =
                    snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }).toList();

                return _buildListView(dataList);
              },
            ),

          // 头部毛玻璃栏
          _buildFloatingHeader(accentBlue),

          // ⭐⭐⭐ 毛玻璃“Start Comparison”悬浮按钮 ⭐⭐⭐
          if (_isSelectionMode)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              bottom: _selectedIds.length >= 2 ? (20 + bottomSafe) : -160,
              left: 30,
              right: 30,
              child: AnimatedScale(
                scale: _selectedIds.length >= 2 ? 1 : 0.7,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                child: _buildGlassFloatingButton(accentBlue),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------- 毛玻璃悬浮按钮 ----------------------
  Widget _buildGlassFloatingButton(Color accentBlue) {
    bool enabled = _selectedIds.length >= 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withOpacity(0.17),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentBlue.withOpacity(0.35),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: GestureDetector(
            onTap: enabled ? _navigateToCompare : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.compare_arrows,
                  color: enabled ? Colors.white : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  "Start Comparison (${_selectedIds.length})",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: enabled ? Colors.white : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------- 列表 ----------------------
  Widget _buildListView(List<Map<String, dynamic>> dataList) {
    _currentDisplayData = dataList;

    const Color glowColor = Color(0xFF00E5FF);

    return ListView.builder(
      padding:
          const EdgeInsets.only(top: 130, left: 20, right: 20, bottom: 200),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final data = dataList[index];
        final String docId = data['id'];
        final bool isSelected = _selectedIds.contains(docId);

        // ✅ 修正点1：移除了外层的 GestureDetector
        return AnimatedScale(
          scale: isSelected && _isSelectionMode ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: _isSelectionMode && isSelected
                  ? Border.all(color: glowColor, width: 2)
                  : null,
              boxShadow: _isSelectionMode && isSelected
                  ? [
                      BoxShadow(
                        color: glowColor.withOpacity(0.45),
                        blurRadius: 15,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                // ✅ 修正点2：移除了 IgnorePointer，直接使用 PropertyCard
                PropertyCard(
                  propertyData: data,
                  propertyId: docId,
                  heroTagPrefix: widget.preFilteredData != null
                      ? 'search_result'
                      : 'list_mode',
                  margin: EdgeInsets.zero,
                  
                  // ✅ 修正点3：将点击逻辑传入 Card 内部处理
                  onTap: () => _handleItemTap(docId),
                  
                  // ✅ 修正点4：选择模式下隐藏收藏按钮，避免重叠
                  showFavoriteButton: !_isSelectionMode,
                ),

                // 选择模式下的打钩图标
                if (_isSelectionMode)
                  Positioned(
                    top: 10,
                    right: 10,
                    // 使用 IgnorePointer 确保即便点到这个图标，也会穿透到底下 Card 的 onTap
                    child: IgnorePointer(
                      ignoring: true, 
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? glowColor
                              : Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.black87)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------- 顶部毛玻璃栏 ----------------------
  Widget _buildFloatingHeader(Color accentBlue) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.preFilteredData != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white),
                        ),
                      ),

                    Expanded(
                      child: Text(
                        _isSelectionMode
                            ? "Select (${_selectedIds.length})"
                            : (widget.preFilteredData != null
                                ? "Results"
                                : "Property List"),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (!_isSelectionMode)
                      GestureDetector(
                        onTap: _goToSearch,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search,
                              color: Colors.white, size: 20),
                        ),
                      ),

                    const SizedBox(width: 12),

                    GestureDetector(
                      onTap: _toggleSelectionMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isSelectionMode
                              ? Colors.white.withOpacity(0.2)
                              : accentBlue.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isSelectionMode ? "Cancel" : "Compare",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}