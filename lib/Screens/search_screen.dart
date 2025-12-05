import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 导入组件 (请确保路径正确)
import '../Compoents/glass_card.dart';
import 'property_list_screen.dart'; 

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  // --- 动画控制器 ---
  late AnimationController _entryController;
  
  // --- 数据源 ---
  List<DocumentSnapshot> _allProperties = [];
  List<DocumentSnapshot> _filteredProperties = [];
  List<String> _communityNames = [];
  bool _isLoading = true;

  // --- 筛选状态 ---
  String _currentSearchText = ""; 
  RangeValues _priceRange = const RangeValues(0, 5000); 
  int _minBedrooms = 1; 
  String? _selectedFurnishing; 
  final Set<String> _selectedFeatures = {}; 
  final Set<String> _selectedFacilities = {};

  // --- 动态直方图数据 ---
  List<double> _priceDistribution = []; 

  // --- 静态配置 ---
  final Map<String, IconData> _featureOptions = {
    'Air Conditioner': Icons.ac_unit, 
    'Refrigerator': Icons.kitchen,
    'Washing Machine': Icons.local_laundry_service, 
    'Wifi': Icons.wifi,
  };
  final Map<String, IconData> _facilityOptions = {
    '24-hour Security': Icons.security, 
    'Free Indoor Gym': Icons.fitness_center,
    'Free Outdoor Pool': Icons.pool, 
    'Parking Area': Icons.local_parking,
  };

  @override
  void initState() {
    super.initState();
    
    // 1. 初始化动画控制器 (总时长 800ms)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 2. 开始获取数据
    _fetchData();
    
    // 3. 启动动画
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final communitySnapshot = await FirebaseFirestore.instance.collection('communities').get();
      final communities = communitySnapshot.docs
          .map((doc) => doc.data()['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final propertySnapshot = await FirebaseFirestore.instance.collection('properties').get();

      if (mounted) {
        setState(() {
          _communityNames = communities;
          _allProperties = propertySnapshot.docs;
          _isLoading = false;
          
          _calculatePriceDistribution();
          _applyFilters(); 
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculatePriceDistribution() {
    const int bucketCount = 10; 
    const double maxPriceLimit = 5000.0;
    final double bucketSize = maxPriceLimit / bucketCount; 
    
    if (_allProperties.isEmpty) {
      setState(() {
        _priceDistribution = List.filled(bucketCount, 0.05);
      });
      return;
    }

    List<int> counts = List.filled(bucketCount, 0);

    for (var doc in _allProperties) {
      final data = doc.data() as Map<String, dynamic>;
      double price = (data['price'] ?? 0).toDouble();

      if (price >= maxPriceLimit) {
        counts[bucketCount - 1]++;
      } else {
        int index = (price / bucketSize).floor();
        if (index < 0) index = 0;
        if (index >= bucketCount) index = bucketCount - 1;
        counts[index]++;
      }
    }

    int maxCount = counts.reduce(max);
    
    setState(() {
      if (maxCount == 0) {
        _priceDistribution = List.filled(bucketCount, 0.02); 
      } else {
        _priceDistribution = counts.map((c) => c == 0 ? 0.05 : (c / maxCount)).toList();
      }
    });
  }

  void _applyFilters() {
    final query = _currentSearchText.toLowerCase();

    final results = _allProperties.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // 逻辑保持不变
      final communityName = (data['communityName'] ?? '').toString();
      if (query.isNotEmpty && !communityName.toLowerCase().contains(query)) return false;

      final price = (data['price'] ?? 0).toDouble();
      if (price < _priceRange.start || price > _priceRange.end) return false;

      final bedrooms = data['bedrooms'] ?? 0;
      if (bedrooms < _minBedrooms) return false;

      if (_selectedFurnishing != null && data['furnishing'] != _selectedFurnishing) return false;

      final features = List<String>.from(data['features'] ?? []);
      if (!_selectedFeatures.every((f) => features.contains(f))) return false;

      final facilities = List<String>.from(data['facilities'] ?? []);
      if (!_selectedFacilities.every((f) => facilities.contains(f))) return false;

      return true;
    }).toList();

    setState(() {
      _filteredProperties = results;
    });
  }

 void _navigateToResults() {
    // ✅ 1. 数据清洗：转换为纯 Map，防止模拟器崩溃
    final List<Map<String, dynamic>> cleanData = _filteredProperties.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // 务必把 ID 塞进去，PropertyListScreen 需要它
      
      return {
        'id': doc.id,
        'price': data['price'] ?? 0,
        'size_sqft': data['size_sqft'] ?? '0',
        'bedrooms': data['bedrooms'] ?? 0,
        'bathrooms': data['bathrooms'] ?? 0,
        'parking': data['parking'] ?? 0,
        'furnishing': data['furnishing'] ?? 'N/A',
        'communityName': data['communityName'] ?? 'Unknown',
        'imageUrls': data['imageUrls'],
        'features': data['features'] ?? [],
        'facilities': data['facilities'] ?? [],
        'description': data['description'] ?? '',
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyListScreen(
          // ✅ 2. 修复参数名：使用 preFilteredData
          preFilteredData: cleanData, 
        ),
      ),
    );
  }

  // ==========================================================================
  // 动画辅助函数：生成带延迟的滑入效果
  // ==========================================================================
  Widget _buildAnimatedSection({required int index, required Widget child}) {
    // 假设页面最多有 8-10 个板块，每个板块延迟 0.1 (10%) 的时间开始
    final double begin = (index * 0.1).clamp(0.0, 0.8);
    final double end = (begin + 0.4).clamp(0.2, 1.0);

    final Animation<double> fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Interval(begin, end, curve: Curves.easeOut)),
    );

    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2), // 从下方 20% 处开始
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Interval(begin, end, curve: Curves.easeOutCubic)),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }

  // ==========================================================================
  // UI 构建
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    const Color accentBlue = Color(0xFF1D5DC7);
    const Color bgDark = Color(0xFF153a44);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Search & Filter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [bgDark, Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. 顶部搜索框 (Index 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildAnimatedSection(
                    index: 0, 
                    child: _buildAutocompleteSearchBar()
                  ),
                ),

                // 3. 滚动区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Price (Index 1) ---
                        _buildAnimatedSection(
                          index: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel("Price Range (RM)"),
                              GlassCard(
                                child: Column(
                                  children: [
                                    _buildPriceHistogram(),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("RM ${_priceRange.start.round()}", style: const TextStyle(color: Colors.white70)),
                                        Text("RM ${_priceRange.end.round()}", style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: accentBlue,
                                        overlayColor: accentBlue.withOpacity(0.2),
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                      ),
                                      child: RangeSlider(
                                        values: _priceRange,
                                        min: 0, max: 5000, divisions: 50,
                                        onChanged: (val) {
                                          setState(() => _priceRange = val);
                                          // 这里不重新触发 entry 动画，因为 controller 没动
                                        },
                                        onChangeEnd: (val) => _applyFilters(), // 优化：松手才筛选
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Bedrooms & Furnishing (Index 2) ---
                        _buildAnimatedSection(
                          index: 2,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionLabel("Min Bedrooms"),
                                    _buildBedroomSegmentedControl(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionLabel("Furnishing"),
                                    GlassCard(
                                      child: _buildDropdown(
                                        value: _selectedFurnishing,
                                        hint: "Any",
                                        items: ['Fully Furnished', 'Half Furnished', 'Unfurnished'],
                                        onChanged: (val) {
                                          setState(() => _selectedFurnishing = val);
                                          _applyFilters();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Features (Index 3) ---
                        _buildAnimatedSection(
                          index: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel("Property Features"),
                              _buildVisualGrid(options: _featureOptions, selectedSet: _selectedFeatures),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Facilities (Index 4) ---
                        _buildAnimatedSection(
                          index: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel("Facilities"),
                              _buildVisualGrid(options: _facilityOptions, selectedSet: _selectedFacilities),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. 底部按钮 (独立的 SlideUp 动画)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
                CurvedAnimation(parent: _entryController, curve: const Interval(0.5, 1.0, curve: Curves.elasticOut))
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, bgDark.withOpacity(0.8), bgDark],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _navigateToResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 10,
                    shadowColor: accentBlue.withOpacity(0.5),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Show ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          // 数字滚动效果
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child));
                            },
                            child: Text(
                              "${_filteredProperties.length}",
                              key: ValueKey<int>(_filteredProperties.length),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Text(" Properties", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 组件部分 (保持不变，逻辑已修复)
  // ==========================================================================

  Widget _buildAutocompleteSearchBar() {
    return LayoutBuilder(builder: (context, constraints) {
      return RawAutocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') return const Iterable<String>.empty();
          return _communityNames.where((String option) {
            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
          });
        },
        onSelected: (String selection) {
          setState(() {
            _currentSearchText = selection;
            _applyFilters();
          });
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          if (textEditingController.text != _currentSearchText) {
            textEditingController.text = _currentSearchText;
            textEditingController.selection = TextSelection.collapsed(offset: _currentSearchText.length);
          }
          return GlassCard(
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Search community...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    onChanged: (val) => setState(() { _currentSearchText = val; _applyFilters(); }),
                  ),
                ),
                if (_currentSearchText.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      textEditingController.clear();
                      setState(() { _currentSearchText = ""; _applyFilters(); });
                    },
                    child: const Icon(Icons.close, color: Colors.white70),
                  )
              ],
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              color: const Color(0xFF295a68),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Text(option, style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // Price Histogram
  Widget _buildPriceHistogram() {
    const int bucketCount = 10;
    const double maxPrice = 5000.0;
    final double bucketSize = maxPrice / bucketCount;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _priceDistribution.isEmpty 
          ? [] 
          : _priceDistribution.asMap().entries.map((entry) {
            int index = entry.key;
            double heightPct = entry.value;
            double barStartPrice = index * bucketSize;
            double barEndPrice = (index + 1) * bucketSize;
            bool isHighlighted = barEndPrice > _priceRange.start && barStartPrice < _priceRange.end;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: heightPct),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Container(
                      height: 40 * value, 
                      decoration: BoxDecoration(
                        color: isHighlighted 
                            ? const Color(0xFF1D5DC7) 
                            : Colors.white.withOpacity(0.3), 
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }
                ),
              ),
            );
          }).toList(),
      ),
    );
  }

  Widget _buildBedroomSegmentedControl() {
    return GlassCard(
      child: Row(
        children: [1, 2, 3, 4].map((num) {
          final isSelected = _minBedrooms == num;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _minBedrooms = num);
                _applyFilters();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1D5DC7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    num == 4 ? "4+" : "$num",
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVisualGrid({required Map<String, IconData> options, required Set<String> selectedSet}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final key = options.keys.elementAt(index);
        final icon = options[key]!;
        final isSelected = selectedSet.contains(key);

        return BouncingButton( // 👈 使用回弹按钮
          onTap: () {
            setState(() {
              if (isSelected) selectedSet.remove(key); else selectedSet.add(key);
            });
            _applyFilters();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected 
                ? const LinearGradient(colors: [Color(0xFF1D5DC7), Color(0xFF4DA3FF)], begin: Alignment.topLeft, end: Alignment.bottomRight) 
                : LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF1D5DC7).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key, 
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 12, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown({required String? value, required String hint, required List<String> items, required Function(String?) onChanged}) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        dropdownColor: const Color(0xFF295a68),
        style: const TextStyle(color: Colors.white),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
        isExpanded: true,
        isDense: true,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

// --- 辅助组件：Bouncing Button ---
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncingButton({super.key, required this.child, required this.onTap});

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // 快速回弹
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}