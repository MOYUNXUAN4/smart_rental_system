import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 导入服务与组件
import '../Services/favorite_service.dart';
import '../Compoents/property_card.dart';
import '../Compoents/glass_card.dart';
import 'package:smart_rental_system/Screens/property_detail_screen.dart';
import 'package:smart_rental_system/Screens/search_screen.dart';
import 'package:smart_rental_system/Screens/compare_screen.dart';


enum SortType { newest, priceLowToHigh, priceHighToLow }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoriteService _favoriteService = FavoriteService();
  SortType _currentSort = SortType.newest;
  
  List<DocumentSnapshot> _properties = [];
  bool _isLoading = true; 
  StreamSubscription? _subscription;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _setupDataListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupDataListener() {
    _subscription = _favoriteService.getFavoriteIdsStream().listen((ids) async {
      if (ids.isEmpty) {
        if (mounted) setState(() { _properties = []; _isLoading = false; });
        return;
      }
      try {
        final futures = ids.map((id) => 
          FirebaseFirestore.instance.collection('properties').doc(id).get()
        );
        final results = await Future.wait(futures);
        final validDocs = results.where((doc) => doc.exists).toList();
        _sortDocs(validDocs, ids);

        if (mounted) {
          setState(() {
            _properties = validDocs;
            _isLoading = false;
            _selectedIds.removeWhere((id) => !validDocs.any((doc) => doc.id == id));
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  void _sortDocs(List<DocumentSnapshot> docs, List<String> originalIds) {
    docs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final double priceA = (dataA['price'] ?? 0).toDouble();
      final double priceB = (dataB['price'] ?? 0).toDouble();

      switch (_currentSort) {
        case SortType.priceLowToHigh: return priceA.compareTo(priceB);
        case SortType.priceHighToLow: return priceB.compareTo(priceA);
        case SortType.newest: default:
          return originalIds.indexOf(a.id).compareTo(originalIds.indexOf(b.id));
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _handleItemTap(String id, bool isUnavailable) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          if (_selectedIds.length >= 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Compare up to 3 properties"), backgroundColor: Colors.orange),
            );
            return;
          }
          _selectedIds.add(id);
        }
      });
    } else {
      if (!isUnavailable) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PropertyDetailScreen(propertyId: id)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Property unavailable")));
      }
    }
  }

  void _navigateToCompare() {
    if (_selectedIds.length < 2) return;

    try {
      // 1. 安全地提取数据
      final selectedDocs = _properties.where((doc) => _selectedIds.contains(doc.id)).toList();
      
      // 2. 转换为纯 Map List，防止传递 DocumentSnapshot 导致的潜在序列化问题
      final List<Map<String, dynamic>> propertiesData = selectedDocs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        // 确保关键字段存在，防止下游崩溃
        data['price'] = data['price'] ?? 0;
        data['size_sqft'] = data['size_sqft'] ?? '0';
        data['bedrooms'] = data['bedrooms'] ?? 0;
        return data;
      }).toList();

      // 3. 跳转
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompareScreen(properties: propertiesData),
        ),
      );
    } catch (e) {
      print("Error navigating to compare: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error starting comparison")));
    }
  }

  void _showGlassSortMenu() {
    // ... (保持你原有的排序菜单代码)
  }

  // ✅ 简单的白色毛玻璃按钮 (AppBar)
  Widget _buildCompareToggleButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleSelectionMode,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isSelectionMode ? Icons.close : Icons.compare_arrows, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    _isSelectionMode ? "Cancel" : "Compare",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF153a44);
    const Color accentBlue = Color(0xFF1D5DC7);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isSelectionMode ? "Selected (${_selectedIds.length})" : "My Favorites", 
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_properties.isNotEmpty) _buildCompareToggleButton(),
          if (!_isSelectionMode) IconButton(icon: const Icon(Icons.sort, color: Colors.white), onPressed: _showGlassSortMenu),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [bgDark, Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_properties.isEmpty)
            _buildEmptyState() // 请确保你有这个方法
          else
            ListView.builder(
              padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 140),
              itemCount: _properties.length,
              itemBuilder: (context, index) {
                final doc = _properties[index];
                final data = doc.data() as Map<String, dynamic>;
                final bool isUnavailable = (data['status'] == 'rented');
                final bool isSelected = _selectedIds.contains(doc.id);

                return GestureDetector(
                  onTap: () => _handleItemTap(doc.id, isUnavailable),
                  // ✅ 使用新的清爽版发光容器
                  child: _GlowBorderContainer(
                    isSelected: _isSelectionMode && isSelected,
                    child: Stack(
                      children: [
                        IgnorePointer(
                          ignoring: true,
                          child: PropertyCard(
                            propertyData: data,
                            propertyId: doc.id,
                            showFavoriteButton: !_isSelectionMode,
                            // ✅ 关键：去掉卡片自带边距，让发光框紧贴
                            margin: EdgeInsets.zero, 
                            onTap: () {},
                          ),
                        ),
                        if (_isSelectionMode)
                          Positioned(
                            top: 10, right: 10,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: isSelected ? accentBlue : Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                            ),
                          ),
                        if (isUnavailable && !_isSelectionMode)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                              child: const Center(child: Text("RENTED OUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // ✅ 底部按钮：白色毛玻璃风格，纯净
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutBack,
            bottom: _isSelectionMode ? 110 : -100,
            left: 40, right: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), // 纯白半透明
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectedIds.length >= 2 ? _navigateToCompare : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.compare_arrows, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              _selectedIds.length < 2 ? "Select 2 to Start" : "Start Comparison (${_selectedIds.length})",
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildEmptyState() { return Container(); } // 你的空状态
}

// ✅ 全新设计的容器：只发光，不花哨
class _GlowBorderContainer extends StatelessWidget {
  final bool isSelected;
  final Widget child;

  const _GlowBorderContainer({required this.isSelected, required this.child});

  @override
  Widget build(BuildContext context) {
    // 1. 未选中：保持原有间距，无边框
    if (!isSelected) return Container(margin: const EdgeInsets.only(bottom: 16), child: child);

    // 2. 选中：淡蓝色发光边框，紧贴
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        // 必须匹配 PropertyCard 的圆角 (通常是 12 或 20)
        // 这里设为 20 加上边框宽度
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.cyanAccent, width: 2), // 简单的淡蓝色边
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.4), // 柔和的淡蓝光晕
            blurRadius: 12,
            spreadRadius: 1,
          )
        ],
      ),
      // ClipRRect 确保内容不溢出圆角
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}