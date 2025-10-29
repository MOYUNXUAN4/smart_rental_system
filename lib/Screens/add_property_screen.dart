import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _propertyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sizeController = TextEditingController();

  bool _isLoading = false;
  List<XFile> _selectedImages = [];
  File? _selectedContract;
  String? _selectedContractName;
  DateTime? _selectedDate;

  // 数字类（将通过弹窗滑条设置）
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _parking = 0;
  int _airConditioners = 0;

  String _selectedFurnishing = 'Unfurnished';
  Set<String> _selectedFeatures = {};
  Set<String> _selectedFacilities = {};

  final List<String> _furnishingOptions = [
    'Fully Furnished',
    'Half Furnished',
    'Unfurnished'
  ];

  final Map<String, IconData> _featureOptions = {
    'Air Conditioner': Icons.ac_unit,
    'Refrigerator': Icons.kitchen,
    'Washing Machine': Icons.local_laundry_service,
    'Wifi': Icons.wifi,
    // 其它 feature（非数字类）...
  };

  final Map<String, IconData> _facilityOptions = {
    '24-hour Security': Icons.security,
    'Free Indoor Gym': Icons.fitness_center,
    'Free Outdoor Pool': Icons.pool,
    'Parking Area': Icons.local_parking,
    // 其它 facility...
  };

  @override
  void dispose() {
    _propertyNameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  // ---------------- 图片 / 合同 选择 ----------------
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images;
      });
    }
  }

  Future<void> _pickContract() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedContract = File(result.files.single.path!);
        _selectedContractName = result.files.single.name;
      });
    }
  }

  // ---------------- 日期选择 ----------------
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ---------------- 上传 / Firestore ----------------
  Future<void> _showConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Upload"),
        content: const Text("Are you sure you want to upload this property?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitProperty();
    }
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one property image.')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the available date.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 上传图片和合同
      final imageUrls = await _uploadImages(_selectedImages);
      final contractUrl = _selectedContract != null
          ? await _uploadContract(_selectedContract!)
          : null;

      // 保存到 Firestore（使用新的数值字段）
      await FirebaseFirestore.instance.collection('properties').add({
        'landlordUid': user.uid,
        'propertyName': _propertyNameController.text.trim(),
        'address': _addressController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'description': _descriptionController.text.trim(),
        'size_sqft': _sizeController.text.trim(),
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'parking': _parking,
        'airConditioners': _airConditioners,
        'furnishing': _selectedFurnishing,
        'availableDate': Timestamp.fromDate(_selectedDate!),
        'features': _selectedFeatures.toList(),
        'facilities': _selectedFacilities.toList(),
        'imageUrls': imageUrls,
        'contractUrl': contractUrl,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Property Uploaded Successfully!')),
        );
      }
    } catch (e) {
      print("添加房产失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to add property: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final storage = FirebaseStorage.instance;
    List<String> urls = [];
    for (final img in images) {
      final file = File(img.path);
      final fileName = 'property_images/${DateTime.now().millisecondsSinceEpoch}_${img.name}';
      final ref = storage.ref().child(fileName);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<String> _uploadContract(File contract) async {
    final storage = FirebaseStorage.instance;
    final fileName =
        'contracts/${DateTime.now().millisecondsSinceEpoch}_${_selectedContractName ?? "contract.pdf"}';
    final ref = storage.ref().child(fileName);
    await ref.putFile(contract);
    return await ref.getDownloadURL();
  }

  // ---------------- 弹窗式滑条（Material3 风格 + 毛玻璃背景） ----------------
  // title: 要设置的字段名；currentValue: 当前值；onConfirm: 设置回父状态
  Future<void> _showNumberSliderDialog({
    required String title,
    required int currentValue,
    required Function(int) onConfirm,
  }) async {
    int tempValue = currentValue;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // 使用 StatefulBuilder 以便在 dialog 内部实时更新值
        return StatefulBuilder(builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 标题
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      // 实时数值显示
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tempValue.toString(),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Slider（0-10，整数）
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white38,
                          thumbColor: const Color(0xFF1D5DC7),
                          overlayColor: Colors.white24,
                          valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: tempValue.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: tempValue.toString(),
                          onChanged: (v) {
                            setStateDialog(() {
                              tempValue = v.toInt();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D5DC7)),
                            onPressed: () {
                              onConfirm(tempValue);
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ---------------- UI 构建辅助 ----------------

  // 毛玻璃卡片（保留你的样式）
  Widget _buildGlassCard({required Widget child}) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: child,
          ),
        ),
      );

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: _selectedImages.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 40),
                    SizedBox(height: 8),
                    Text('Add Pictures', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : Center(child: Text('${_selectedImages.length} images selected', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  // 原来顶部的 count selectors 已移至 property features（按你要求）
  // 仍保留一个更紧凑的输入区域（名称、地址、描述、日期、价格、size）
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // 改造的 Checkbox Grid：图标在文字左边，checkbox 在右边
  Widget _buildCheckboxGrid({
    required String title,
    required Map<String, IconData> options,
    required Set<String> selectedOptions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: options.entries.map((entry) {
            final key = entry.key;
            final icon = entry.value;
            final isSelected = selectedOptions.contains(key);

            // 如果是 Air Conditioner（或其他数字类），我们保持它作为普通可勾选项（同时上面我们已提供专属滑条）
            return SizedBox(
              width: MediaQuery.of(context).size.width * 0.44,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(icon, color: Colors.white, size: 20),
                  title: Text(key, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) selectedOptions.add(key);
                        else selectedOptions.remove(key);
                      });
                    },
                    activeColor: Colors.white,
                    checkColor: const Color(0xFF1D5DC7),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Contract picker （保留）
  Widget _buildContractPicker() => GestureDetector(
        onTap: _pickContract,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Contract (Optional PDF)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.description_outlined, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(
            _selectedContractName ?? 'Upload Contract PDF',
            style: TextStyle(
                color: _selectedContractName == null ? Colors.white70 : Colors.white,
                fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

  // 日期选择器（保留）
  Widget _buildDatePicker() => GestureDetector(
        onTap: () => _selectDate(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Available Date',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(
            _selectedDate == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(_selectedDate!),
            style: TextStyle(color: _selectedDate == null ? Colors.white70 : Colors.white, fontSize: 16),
          ),
        ),
      );

  // Build numeric feature item (点击弹窗滑条)
  Widget _buildNumericFeatureItem({
    required String label,
    required IconData icon,
    required int value,
    required Function(int) onConfirmed,
  }) {
    return GestureDetector(
      onTap: () {
        _showNumberSliderDialog(title: label, currentValue: value, onConfirm: onConfirmed);
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.44,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
              Text(value.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  // Furnishing Selector 改为 Dropdown（你要求）
  Widget _buildFurnishingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Furnishing Status', style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButton<String>(
            value: _selectedFurnishing,
            dropdownColor: const Color(0xFF295a68),
            isExpanded: true,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white),
            items: _furnishingOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedFurnishing = val);
            },
          ),
        ),
      ],
    );
  }

  // ---------------- 主界面 Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Add New Property', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 原始背景渐变（你提供的）
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF153a44),
                  Color(0xFF295a68),
                  Color(0xFF5d8fa0),
                  Color(0xFF94bac4),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 图片选择
                    _buildImagePicker(),
                    const SizedBox(height: 16),

                    // 主要信息卡片（保留毛玻璃样式）
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextFormField(controller: _propertyNameController, labelText: 'Property Name', icon: Icons.home_work_outlined),
                          const SizedBox(height: 16),
                          _buildTextFormField(controller: _addressController, labelText: 'Address', icon: Icons.location_on_outlined),
                          const SizedBox(height: 16),

                          // 原来的 bedrooms/bathrooms/parking 已移至 Property Features（按你要求）
                          _buildFurnishingSelector(),
                          const SizedBox(height: 16),

                          _buildTextFormField(controller: _descriptionController, labelText: 'More Description', icon: Icons.description_outlined, maxLines: 3),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(child: _buildDatePicker()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextFormField(controller: _priceController, labelText: 'Price(RM)', icon: Icons.attach_money, keyboardType: TextInputType.number)),
                            ],
                          ),

                          const SizedBox(height: 12),
                          _buildTextFormField(controller: _sizeController, labelText: 'Size (sqft)', icon: Icons.square_foot, keyboardType: TextInputType.number),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Property Features 卡片（数字项改为弹窗滑条，图标在左）
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Property Features', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // 数字类项（点开弹窗滑条）
                              _buildNumericFeatureItem(label: 'Air Conditioner', icon: Icons.ac_unit, value: _airConditioners, onConfirmed: (v) => setState(() => _airConditioners = v)),
                              _buildNumericFeatureItem(label: 'Bedroom', icon: Icons.king_bed_outlined, value: _bedrooms, onConfirmed: (v) => setState(() => _bedrooms = v)),
                              _buildNumericFeatureItem(label: 'Bathroom', icon: Icons.bathtub_outlined, value: _bathrooms, onConfirmed: (v) => setState(() => _bathrooms = v)),
                              _buildNumericFeatureItem(label: 'Car Park', icon: Icons.local_parking_outlined, value: _parking, onConfirmed: (v) => setState(() => _parking = v)),

                              // 其他可勾选的 features（icon 在左，checkbox 在右）
                              // 我把原 featureOptions 保留为勾选列表（不含数字类）
                              // 若你希望把 AC 从这里移除，也可删除对应 entry
                              ..._featureOptions.entries.map((e) {
                                final key = e.key;
                                // 跳过数字类在这里重复显示（Air Conditioner 已做为数字）
                                if (key.toLowerCase().contains('air')) {
                                  return const SizedBox.shrink();
                                }
                                return SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      leading: Icon(e.value, color: Colors.white, size: 20),
                                      title: Text(key, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      trailing: Checkbox(
                                        value: _selectedFeatures.contains(key),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) _selectedFeatures.add(key);
                                            else _selectedFeatures.remove(key);
                                          });
                                        },
                                        activeColor: Colors.white,
                                        checkColor: const Color(0xFF1D5DC7),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Facilities 卡片（图标左侧）
                    _buildGlassCard(
                      child: _buildCheckboxGrid(title: 'Facilities', options: _facilityOptions, selectedOptions: _selectedFacilities),
                    ),

                    const SizedBox(height: 16),

                    // Contract 上传卡片
                    _buildGlassCard(child: _buildContractPicker()),

                    const SizedBox(height: 24),

                    // 提交按钮（弹出确认对话框 -> 上传）
                    ElevatedButton(
                      onPressed: _isLoading ? null : _showConfirmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5DC7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('Add Property', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
