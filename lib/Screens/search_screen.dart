// lib/Screens/search_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 导入你的组件
import '../Compoents/glass_card.dart';
// 导入列表页 (用于跳转显示结果)
import 'property_list_screen.dart'; 

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // --- 状态变量 ---
  
  // 所有的房源数据 (缓存用于本地筛选)
  List<DocumentSnapshot> _allProperties = [];
  // 筛选后的结果
  List<DocumentSnapshot> _filteredProperties = [];
  // 所有社区的名字 (用于搜索框联想)
  List<String> _communityNames = [];
  
  bool _isLoading = true;

  // --- 筛选条件 ---
  String _currentSearchText = ""; // 搜索框文字
  RangeValues _priceRange = const RangeValues(0, 5000); // 价格范围
  int _minBedrooms = 1; // 最小卧室数
  String? _selectedFurnishing; // 装修情况
  final Set<String> _selectedFeatures = {}; // 选中的特征
  final Set<String> _selectedFacilities = {}; // 选中的设施

  // --- 选项配置 (图标映射) ---
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
    _fetchData();
  }

  // 1. 初始化数据：获取所有房源和所有社区名
  Future<void> _fetchData() async {
    try {
      // 获取社区列表 (用于自动补全)
      final communitySnapshot = await FirebaseFirestore.instance.collection('communities').get();
      final communities = communitySnapshot.docs
          .map((doc) => doc.data()['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // 获取所有房源 (用于本地筛选)
      final propertySnapshot = await FirebaseFirestore.instance.collection('properties').get();

      if (mounted) {
        setState(() {
          _communityNames = communities;
          _allProperties = propertySnapshot.docs;
          _isLoading = false;
          _applyFilters(); // 数据加载完后，立即执行一次默认筛选
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 核心筛选逻辑
  void _applyFilters() {
    final query = _currentSearchText.toLowerCase();

    final results = _allProperties.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // A. 关键字匹配 (匹配小区名)
      final communityName = (data['communityName'] ?? '').toString();
      if (query.isNotEmpty && !communityName.toLowerCase().contains(query)) {
        return false;
      }

      // B. 价格范围
      final price = (data['price'] ?? 0).toDouble();
      if (price < _priceRange.start || price > _priceRange.end) return false;

      // C. 卧室数量 (大于等于)
      final bedrooms = data['bedrooms'] ?? 0;
      if (bedrooms < _minBedrooms) return false;

      // D. 装修情况 (如果选了，必须完全匹配)
      if (_selectedFurnishing != null && data['furnishing'] != _selectedFurnishing) return false;

      // E. 特征 (必须包含所有选中的特征)
      final features = List<String>.from(data['features'] ?? []);
      if (!_selectedFeatures.every((f) => features.contains(f))) return false;

      // F. 设施 (必须包含所有选中的设施)
      final facilities = List<String>.from(data['facilities'] ?? []);
      if (!_selectedFacilities.every((f) => facilities.contains(f))) return false;

      return true;
    }).toList();

    setState(() {
      _filteredProperties = results;
    });
  }

  // 3. 跳转到列表页显示结果
  void _navigateToResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyListScreen(
          preFilteredDocs: _filteredProperties, // 把筛选好的数据传给列表页
        ),
      ),
    );
  }

  // --- UI 构建 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false, // 防止键盘顶起布局
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Search & Filter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景渐变
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. 顶部：自动补全搜索框
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildAutocompleteSearchBar(),
                ),

                // 2. 中间：可滚动的筛选表单
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // 底部留白给按钮
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        // --- Price Range ---
                        _buildSectionLabel("Price Range (RM)"),
                        GlassCard(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("RM ${_priceRange.start.round()}", style: const TextStyle(color: Colors.white)),
                                  Text("RM ${_priceRange.end.round()}", style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFF1D5DC7),
                                  overlayColor: const Color(0xFF1D5DC7).withOpacity(0.2),
                                  valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                                ),
                                child: RangeSlider(
                                  values: _priceRange,
                                  min: 0,
                                  max: 5000,
                                  divisions: 50, // 每次移动 100 RM
                                  labels: RangeLabels("${_priceRange.start.round()}", "${_priceRange.end.round()}"),
                                  onChanged: (val) {
                                    setState(() => _priceRange = val);
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Bedrooms & Furnishing (两列布局) ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel("Min Bedrooms"),
                                  GlassCard(
                                    child: _buildCounter(), // 自定义计数器组件
                                  ),
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
                        const SizedBox(height: 20),

                        // --- Property Features ---
                        _buildSectionLabel("Features"),
                        GlassCard(
                          child: Column(
                            children: _featureOptions.keys.map((key) {
                              return _buildCheckboxItem(
                                label: key, 
                                icon: _featureOptions[key]!,
                                selectedSet: _selectedFeatures
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Facilities ---
                        _buildSectionLabel("Facilities"),
                        GlassCard(
                          child: Column(
                            children: _facilityOptions.keys.map((key) {
                              return _buildCheckboxItem(
                                label: key, 
                                icon: _facilityOptions[key]!,
                                selectedSet: _selectedFacilities
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. 底部：悬浮跳转按钮
          Positioned(
            left: 20, right: 20, bottom: 20,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _navigateToResults,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D5DC7), // 你的主题蓝
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 8,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    "Show ${_filteredProperties.length} Properties", 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 组件构建函数 ---

  // ✅ 1. 修复后的自动补全搜索框 (解决了 setState 异常)
  Widget _buildAutocompleteSearchBar() {
    return LayoutBuilder(builder: (context, constraints) {
      return RawAutocomplete<String>(
        // 1. optionsBuilder 只负责返回过滤后的数据，不更新状态
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') {
            return const Iterable<String>.empty();
          }
          return _communityNames.where((String option) {
            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
          });
        },
        
        // 2. 选中时更新状态
        onSelected: (String selection) {
          setState(() {
            _currentSearchText = selection;
            _applyFilters();
          });
        },

        // 3. 输入框构建
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          // 确保 Controller 的文本与状态同步
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
                    // 4. 打字时更新状态
                    onChanged: (val) {
                      setState(() {
                        _currentSearchText = val;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                if (_currentSearchText.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      textEditingController.clear();
                      setState(() {
                        _currentSearchText = "";
                        _applyFilters();
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white70),
                  )
              ],
            ),
          );
        },

        // 下拉列表样式
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
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Text(
                          option,
                          style: const TextStyle(color: Colors.white),
                        ),
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

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  // 卧室计数器
  Widget _buildCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            if (_minBedrooms > 0) {
              setState(() => _minBedrooms--);
              _applyFilters();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.remove, color: Colors.white, size: 20),
          ),
        ),
        Text(
          "$_minBedrooms+", 
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        GestureDetector(
          onTap: () {
            if (_minBedrooms < 6) {
              setState(() => _minBedrooms++);
              _applyFilters();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  // 下拉菜单
  Widget _buildDropdown({
    required String? value, 
    required String hint, 
    required List<String> items, 
    required Function(String?) onChanged
  }) {
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

  // Checkbox 列表项
  Widget _buildCheckboxItem({
    required String label, 
    required IconData icon, 
    required Set<String> selectedSet
  }) {
    final isSelected = selectedSet.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) selectedSet.remove(label);
          else selectedSet.add(label);
        });
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // 选中变蓝，未选中保持透明
          color: isSelected ? const Color(0xFF1D5DC7).withOpacity(0.8) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4DA3FF) : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
            if (isSelected) 
              const Icon(Icons.check_circle, color: Colors.white, size: 18)
            else
              const Icon(Icons.circle_outlined, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }
}