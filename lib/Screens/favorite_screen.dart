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


// ✅ Import the new GlowingWrapper
import '../Compoents/glowing_wrapper.dart'; 


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
              const SnackBar(
                content: Text("You can compare up to 3 properties."),
                backgroundColor: Color(0xFF1D5DC7),
                duration: Duration(seconds: 1),
              ),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This property is no longer available.")));
      }
    }
  }

  void _navigateToCompare() {
    if (_selectedIds.length < 2) return;

    try {
      final selectedDocs = _properties.where((doc) => _selectedIds.contains(doc.id)).toList();
      
      final List<Map<String, dynamic>> propertiesData = selectedDocs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        // Ensure keys exist to prevent crashes
        data['price'] = data['price'] ?? 0;
        data['size_sqft'] = data['size_sqft'] ?? '0';
        data['bedrooms'] = data['bedrooms'] ?? 0;
        data['bathrooms'] = data['bathrooms'] ?? 0;
        data['parking'] = data['parking'] ?? 0;
        data['furnishing'] = data['furnishing'] ?? 'N/A';
        data['features'] = data['features'] ?? [];
        data['communityName'] = data['communityName'] ?? 'Unknown';
        data['imageUrls'] = data['imageUrls'];
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
                  child: Text("Sort By", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(color: Colors.white24),
                _buildSortOption("Date Added (Newest)", SortType.newest),
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
          _sortDocs(_properties, _properties.map((e) => e.id).toList());
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
    const Color glowColor = Color(0xFF00E5FF); 

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? "Selected (${_selectedIds.length})" : "My Favorites",
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_properties.isNotEmpty) _buildCompareToggleButton(),
          if (!_isSelectionMode && _properties.isNotEmpty)
            IconButton(icon: const Icon(Icons.sort, color: Colors.white), onPressed: _showGlassSortMenu),
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
            _buildEmptyState()
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
                  
                  // ✅ 关键修改：使用 GlowingWrapper 包裹
                  child: GlowingWrapper(
                    isSelected: _isSelectionMode && isSelected,
                    child: Stack(
                      children: [
                        IgnorePointer(
                          ignoring: true,
                          child: PropertyCard(
                            propertyData: data,
                            propertyId: doc.id,
                            showFavoriteButton: !_isSelectionMode,
                            margin: EdgeInsets.zero, // Needed to fit inside the wrapper perfectly
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
                                color: isSelected ? glowColor : Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: isSelected 
                                  ? const Icon(Icons.check, size: 18, color: Colors.black87) 
                                  : null,
                            ),
                          ),
                        if (isUnavailable && !_isSelectionMode)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                              child: const Center(child: Text("RENTED OUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // 底部按钮：白色毛玻璃风格
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
                              _selectedIds.length < 2 
                                  ? "Select 2 to Start" 
                                  : "Start Comparison (${_selectedIds.length})",
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
              const Text("Save properties you like here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text("Start Exploring"),
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