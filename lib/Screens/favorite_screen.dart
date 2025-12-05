import 'dart:async';
import 'dart:ui'; // 必须导入这个以使用 ImageFilter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_rental_system/Screens/search_screen.dart';

// 确保导入你原本的组件路径
import '../Compoents/glass_card.dart';
import '../Compoents/property_card.dart';
import '../Services/favorite_service.dart';
import 'compare_screen.dart';
import 'property_detail_screen.dart';

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

  // 选择模式状态
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
        // get all property documents in parallel
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
          // 保持加入收藏的顺序 (原本的ID列表顺序)
          return originalIds.indexOf(a.id).compareTo(originalIds.indexOf(b.id));
      }
    });
  }

  // --- 交互逻辑 ---

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _handleItemTap(String id) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
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
          _selectedIds.add(id);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PropertyDetailScreen(propertyId: id)),
      );
    }
  }

  void _handleRemoveFavorite(String id) {
    _favoriteService.toggleFavorite(id);
  }

  void _navigateToCompare() {
    if (_selectedIds.length < 2) return;

    try {
      final selectedDocs = _properties.where((doc) => _selectedIds.contains(doc.id)).toList();
      
      // 转换数据格式适配 CompareScreen
      final List<Map<String, dynamic>> propertiesData = selectedDocs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // 确保ID存在
        return data;
      }).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompareScreen(properties: propertiesData),
        ),
      );
    } catch (e) {
      print("Error navigating: $e");
    }
  }

  // --- 排序菜单 ---
  void _showGlassSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                  child: Text("Sort Favorites By", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(color: Colors.white24),
                _buildSortOption("Date Added (Default)", SortType.newest),
                _buildSortOption("Price (Low to High)", SortType.priceLowToHigh),
                _buildSortOption("Price (High to Low)", SortType.priceHighToLow),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, SortType type) {
    final bool isSelected = _currentSort == type;
    return InkWell(
      onTap: () {
        setState(() {
          _currentSort = type;
           List<String> currentIds = _properties.map((e) => e.id).toList();
           _sortDocs(_properties, currentIds);
        });
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFF1D5DC7) : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF1D5DC7), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF153a44);
    const Color accentBlue = Color(0xFF1D5DC7);
    const Color glowColor = Color(0xFF00E5FF);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
  
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

          // 2. 主体内容
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_properties.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              padding: const EdgeInsets.only(top: 130, left: 20, right: 20, bottom: 200),
              itemCount: _properties.length,
              itemBuilder: (context, index) {
                final doc = _properties[index];
                final data = doc.data() as Map<String, dynamic>;
                final bool isUnavailable = (data['status'] == 'rented');
                final bool isSelected = _selectedIds.contains(doc.id);

                return GestureDetector(
                  onTap: () => _handleItemTap(doc.id),
                  child: AnimatedScale(
                    scale: isSelected && _isSelectionMode ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        // 选中时发光边框
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
                          IgnorePointer(
                            // 列表接管点击事件，禁用卡片内部点击
                            ignoring: true, 
                            child: PropertyCard(
                              propertyData: data,
                              propertyId: doc.id,
                              showFavoriteButton: false, // 禁用卡片自带的收藏按钮，我们在外层覆盖一个
                              margin: EdgeInsets.zero,
                              heroTagPrefix: 'fav_list',
                              onTap: () {},
                            ),
                          ),

                          // 蒙版: 已出租
                          if (isUnavailable && !_isSelectionMode)
                             Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                                child: const Center(child: Text("RENTED OUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ),
                            ),

                          // 选中模式下的打钩图标
                          if (_isSelectionMode)
                            Positioned(
                              top: 10,
                              right: 10,
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
                          
                          // 非选中模式下的删除收藏按钮 (右上角)
                          if (!_isSelectionMode)
                            Positioned(
                              top: 10, right: 10,
                              child: GestureDetector(
                                onTap: () => _handleRemoveFavorite(doc.id),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  // 实心星星表示已收藏，点击取消
                                  child: const Icon(Icons.star, color: Colors.amber, size: 24),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // 3. 顶部悬浮毛玻璃 Header
          _buildFloatingHeader(accentBlue),

          // 4. 底部“Start Comparison”悬浮按钮
          if (_isSelectionMode)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              bottom: _selectedIds.length >= 2
                  ? (20 + bottomSafe)
                  : -160,
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

  // --- 组件构建方法 ---

  Widget _buildFloatingHeader(Color accentBlue) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    // 返回按钮 (如果是在Tab里可能不需要，如果是独立页面则需要)
                    // GestureDetector(
                    //   onTap: () => Navigator.pop(context),
                    //   child: const Icon(Icons.arrow_back, color: Colors.white),
                    // ),
                    // const SizedBox(width: 12),
                    
                    Expanded(
                      child: Text(
                        _isSelectionMode
                            ? "Selected (${_selectedIds.length})"
                            : "My Favorites",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 排序按钮 (仅在非选择模式显示)
                    if (!_isSelectionMode && _properties.isNotEmpty)
                      GestureDetector(
                        onTap: _showGlassSortMenu,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sort, color: Colors.white, size: 20),
                        ),
                      ),

                    // 对比/取消按钮
                    if (_properties.isNotEmpty)
                      GestureDetector(
                        onTap: _toggleSelectionMode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isSelectionMode
                                ? Colors.white.withOpacity(0.2)
                                : accentBlue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isSelectionMode ? "Cancel" : "Compare",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildGlassFloatingButton(Color accentBlue) {
    bool enabled = _selectedIds.length >= 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withOpacity(0.17),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentBlue.withOpacity(0.35),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Material(
             color: Colors.transparent,
             child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: enabled ? _navigateToCompare : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.compare_arrows, color: enabled ? Colors.white : Colors.white54, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      "Start Comparison (${_selectedIds.length})",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: enabled ? Colors.white : Colors.white54),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 80, color: Colors.white.withOpacity(0.5)),
              const SizedBox(height: 24),
              const Text("No Favorites Yet", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text("Properties you save will appear here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text("Go Explore"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D5DC7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
