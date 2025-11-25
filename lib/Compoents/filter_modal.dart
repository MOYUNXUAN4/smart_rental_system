import 'package:flutter/material.dart';

class FilterModal extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final List<String> communityNames; // ✅ 关键：传入限定的小区名称列表

  const FilterModal({
    super.key,
    required this.currentFilters,
    required this.communityNames,
  });

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  String? _selectedLocation;
  RangeValues _priceRange = const RangeValues(0, 5000);
  int? _selectedBedrooms;
  String? _selectedFurnishing;

  @override
  void initState() {
    super.initState();
    // 初始化已有筛选状态
    _selectedLocation = widget.currentFilters['location'];
    if (widget.currentFilters['minPrice'] != null) {
      _priceRange = RangeValues(
        (widget.currentFilters['minPrice'] as num).toDouble(),
        (widget.currentFilters['maxPrice'] as num? ?? 5000).toDouble(),
      );
    }
    _selectedBedrooms = widget.currentFilters['bedrooms'];
    _selectedFurnishing = widget.currentFilters['furnishing'];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF295a68), // 与你的主题一致
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部把手
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filter Options", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  // ✅ 1. 位置筛选 (使用传入的限定小区列表)
                  _buildSectionTitle("Select Community"),
                  _buildGlassDropdown(
                    value: _selectedLocation,
                    hint: "Any Community",
                    items: widget.communityNames, // 👈 使用限定列表
                    onChanged: (val) => setState(() => _selectedLocation = val),
                  ),
                  const SizedBox(height: 24),

                  // 2. 价格范围
                  _buildSectionTitle("Price Range (RM)"),
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
                      thumbColor: const Color(0xFF1D5DC7),
                      overlayColor: const Color(0xFF1D5DC7).withOpacity(0.2),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                    ),
                    child: RangeSlider(
                      values: _priceRange,
                      min: 0, max: 10000, divisions: 100,
                      labels: RangeLabels("${_priceRange.start.round()}", "${_priceRange.end.round()}"),
                      onChanged: (val) => setState(() => _priceRange = val),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. 卧室数量
                  _buildSectionTitle("Min Bedrooms"),
                  Wrap(
                    spacing: 12,
                    children: [1, 2, 3, 4].map((num) {
                      final isSelected = _selectedBedrooms == num;
                      return ChoiceChip(
                        label: Text(num == 4 ? "4+" : "$num", style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1D5DC7),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        onSelected: (selected) => setState(() => _selectedBedrooms = selected ? num : null),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 4. 装修情况
                  _buildSectionTitle("Furnishing"),
                  _buildGlassDropdown(
                    value: _selectedFurnishing,
                    hint: "Any",
                    items: ['Fully Furnished', 'Half Furnished', 'Unfurnished'],
                    onChanged: (val) => setState(() => _selectedFurnishing = val),
                  ),
                ],
              ),
            ),
          ),

          // 底部按钮
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() { // 重置
                      _selectedLocation = null;
                      _priceRange = const RangeValues(0, 5000);
                      _selectedBedrooms = null;
                      _selectedFurnishing = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Reset"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'location': _selectedLocation,
                        'minPrice': _priceRange.start,
                        'maxPrice': _priceRange.end,
                        'bedrooms': _selectedBedrooms,
                        'furnishing': _selectedFurnishing,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D5DC7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Apply Filters"),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGlassDropdown({
    required String? value, required String hint, required List<String> items, required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white54)),
          dropdownColor: const Color(0xFF295a68),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          isExpanded: true,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}