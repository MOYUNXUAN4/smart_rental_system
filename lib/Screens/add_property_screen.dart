import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

import '../Compoents/contract_generator.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

enum ContractOption { none, upload, generate }

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  // (所有 Controller 和状态变量保持不变)
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sizeController = TextEditingController();
  final _floorController = TextEditingController();
  final _unitController = TextEditingController();
  bool _isLoading = false;
  List<XFile> _selectedImages = [];
  File? _selectedContract;
  String? _selectedContractName;
  DateTime? _selectedDate;
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _parking = 0;
  int _airConditioners = 0;
  String _selectedFurnishing = 'Unfurnished';
  Set<String> _selectedFeatures = {};
  Set<String> _selectedFacilities = {};
  ContractOption _contractOption = ContractOption.none;
  String _generatedContractLanguage = 'zh'; 
  String _landlordName = "Loading..."; 
  List<String> _communityList = [];
  String? _selectedCommunity;
  bool _isCommunityListLoading = true;
  final List<String> _furnishingOptions = [
    'Fully Furnished', 'Half Furnished', 'Unfurnished'
  ];
  final Map<String, IconData> _featureOptions = {
    'Air Conditioner': Icons.ac_unit, 'Refrigerator': Icons.kitchen,
    'Washing Machine': Icons.local_laundry_service, 'Wifi': Icons.wifi,
  };
  final Map<String, IconData> _facilityOptions = {
    '24-hour Security': Icons.security, 'Free Indoor Gym': Icons.fitness_center,
    'Free Outdoor Pool': Icons.pool, 'Parking Area': Icons.local_parking,
  };

  @override
  void initState() {
    super.initState();
    _fetchLandlordName(); 
    _fetchCommunities(); 
  }
  
  // (所有函数 _fetchLandlordName, _fetchCommunities, dispose, 
  // _pickImages, _pickContract, _generateContract, _selectDate, 
  // _showConfirmDialog, _submitProperty, _uploadImages, _uploadContract, 
  // _showNumberSliderDialog 保持不变)

  Future<void> _fetchLandlordName() async { /* (保持不变) */ 
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() => _landlordName = doc.data()?['name'] ?? 'Landlord');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _landlordName = 'Landlord');
    }
  }

  Future<void> _fetchCommunities() async { /* (保持不变) */ 
    try {
      final snapshot = await FirebaseFirestore.instance.collection('communities').get();
      final communities = snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      
      if (mounted) {
        setState(() {
          _communityList = communities;
          _isCommunityListLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching communities: $e");
      if (mounted) {
        setState(() => _isCommunityListLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load community list: $e')),
        );
      }
    }
  }

  @override
  void dispose() { /* (保持不变) */ 
    _floorController.dispose(); 
    _unitController.dispose(); 
    _priceController.dispose();
    _descriptionController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async { /* (保持不变) */ 
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1024);
    if (images.isNotEmpty) {
      setState(() { _selectedImages = images; });
    }
  }

  Future<void> _pickContract() async { /* (保持不变) */ 
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf']);

    if (result != null) {
      setState(() {
        _selectedContract = File(result.files.single.path!);
        _selectedContractName = result.files.single.name;
        _contractOption = ContractOption.upload;
      });
    }
  }
  
  Future<void> _generateContract() async { /* (保持不变) */ 
    if (_selectedCommunity == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a community first.'))); return;
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in required fields (Price, etc).'))); return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final String fullAddress = "${_unitController.text.trim()}, Floor ${_floorController.text.trim()}, $_selectedCommunity";
      final File generatedFile = await ContractGenerator.generateAndSaveContract(
        landlordName: _landlordName, tenantName: "________________",
        propertyAddress: fullAddress, rentAmount: _priceController.text.trim(),
        startDate: "____/____/____", endDate: "____/____/____",
        language: _generatedContractLanguage,
      );
      final result = await OpenFile.open(generatedFile.path);
      if (result.type != ResultType.done) throw Exception('Could not open file for review: ${result.message}');

      if (mounted) {
        final bool? didConfirm = await showDialog<bool>(
          context: context, barrierDismissible: false,
          builder: (BuildContext dialogContext) {
             return AlertDialog(
              title: const Text('Confirm Contract'),
              content: const Text('Do you want to use this generated contract for your property listing?'),
              actions: <Widget>[
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)),
                ElevatedButton(child: const Text('Confirm'), onPressed: () => Navigator.of(dialogContext).pop(true)),
              ],
            );
          }
        );
        if (didConfirm == true && mounted) {
          setState(() {
            _selectedContract = generatedFile;
            _selectedContractName = "Generated_Contract_${DateTime.now().millisecondsSinceEpoch}.pdf";
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Contract staged for upload: $_selectedContractName')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Contract generation failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async { /* (保持不变) */ 
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
    }
  }

  Future<void> _showConfirmDialog() async { /* (保持不变) */ 
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Upload"),
        content: const Text("Are you sure you want to upload this property?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
        ],
      ),
    );
    if (confirmed == true) await _submitProperty();
  }

  Future<void> _submitProperty() async { /* (保持不变) */ 
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommunity == null) { 
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a community.'))); return;
    }
    if (_selectedImages.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one property image.'))); return;
    }
    if (_selectedDate == null) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select the available date.'))); return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final imageUrls = await _uploadImages(_selectedImages);
      final contractUrl = _selectedContract != null ? await _uploadContract(_selectedContract!) : null;

      await FirebaseFirestore.instance.collection('properties').add({
        'landlordUid': user.uid, 'communityName': _selectedCommunity, 
        'floor': _floorController.text.trim(), 'unitNumber': _unitController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'description': _descriptionController.text.trim(), 'size_sqft': _sizeController.text.trim(),
        'bedrooms': _bedrooms, 'bathrooms': _bathrooms, 'parking': _parking,
        'airConditioners': _airConditioners, 'furnishing': _selectedFurnishing,
        'availableDate': Timestamp.fromDate(_selectedDate!),
        'features': _selectedFeatures.toList(), 'facilities': _selectedFacilities.toList(),
        'imageUrls': imageUrls, 'contractUrl': contractUrl, 'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Property Uploaded Successfully!')));
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      print("添加房产失败: $e");
      if (mounted) {
        // ✅ 错误提示现在会显示 Firebase 错误
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to add property: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async { /* (保持不变) */ 
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

  Future<String> _uploadContract(File contract) async { /* (保持不变) */ 
    final storage = FirebaseStorage.instance;
    final fileName = 'contracts/${DateTime.now().millisecondsSinceEpoch}_${_selectedContractName ?? "contract.pdf"}';
    final ref = storage.ref().child(fileName);
    await ref.putFile(contract);
    return await ref.getDownloadURL();
  }

  Future<void> _showNumberSliderDialog({ /* (保持不变) */ 
    required String title, required int currentValue, required Function(int) onConfirm,
  }) async {
    int tempValue = currentValue;
    await showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
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
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tempValue.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white, inactiveTrackColor: Colors.white38,
                          thumbColor: Colors.white, overlayColor: Colors.white.withOpacity(0.3),
                          valueIndicatorTextStyle: const TextStyle(color: Colors.white), trackHeight: 4,
                        ),
                        child: Slider(
                          value: tempValue.toDouble(),
                          min: 0, max: 10, divisions: 10,
                          label: tempValue.toString(),
                          onChanged: (v) { setStateDialog(() { tempValue = v.toInt(); }); },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D5DC7),
                              foregroundColor: Colors.white, 
                            ),
                            onPressed: () { onConfirm(tempValue); Navigator.of(context).pop(); },
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

  // --- UI 构建辅助 ---
  Widget _buildGlassCard({required Widget child}) { /* (保持不变) */ 
     return ClipRRect(
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
  }

  // ✅ 【关键修改】: 替换 _buildImagePicker
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 150, // 保持容器高度
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: _selectedImages.isEmpty
            // 1. 如果未选择，显示提示
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
            // 2. 如果已选择，显示水平滚动的图片列表
            : Padding(
                padding: const EdgeInsets.all(8.0), // 在列表周围添加一些内边距
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, // 水平滚动
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0), // 图片之间的间距
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0), // 图片圆角
                        child: Image.file(
                          File(_selectedImages[index].path), // 从 XFile 路径创建 File
                          fit: BoxFit.cover,
                          width: 134, // (150 高度 - 16 内边距)
                          height: 134,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildTextFormField({ /* (保持不变) */ 
    required TextEditingController controller, required String labelText, required IconData icon,
    String? Function(String?)? validator, TextInputType? keyboardType, int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller, validator: validator, keyboardType: keyboardType,
      maxLines: maxLines, style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText, labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true, fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
    );
  }

  Widget _buildCheckboxGrid({ /* (保持不变) */ 
    required String title,
    required Map<String, IconData> options,
    required Set<String> selectedOptions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Column(
          children: options.entries.map((entry) {
            final key = entry.key;
            final icon = entry.value;
            final isSelected = selectedOptions.contains(key);
            return Container(
              margin: const EdgeInsets.only(bottom: 8.0), 
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
                    setState(() { if (v == true) selectedOptions.add(key); else selectedOptions.remove(key); });
                  },
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF1D5DC7),
                ),
                onTap: () { setState(() { if (isSelected) selectedOptions.remove(key); else selectedOptions.add(key); }); }
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildContractPicker() { /* (保持不变) */ 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contract Option', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'Upload Existing', icon: Icons.upload_file,
                selected: _contractOption == ContractOption.upload,
                onSelected: (v) => setState(() {
                  _contractOption = ContractOption.upload;
                  _selectedContract = null; _selectedContractName = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildChoiceChip(
                label: 'Generate New', icon: Icons.auto_stories,
                selected: _contractOption == ContractOption.generate,
                onSelected: (v) => setState(() {
                  _contractOption = ContractOption.generate;
                  _selectedContract = null; _selectedContractName = null;
                }),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            children: [
              if (_contractOption == ContractOption.upload) _buildUploadUI(), 
              if (_contractOption == ContractOption.generate) _buildGenerateUI(), 
            ],
          )
        ),
        if (_selectedContract != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container( 
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3))
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedContractName ?? 'File Selected',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedContract = null;
                        _selectedContractName = null;
                      });
                    },
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildUploadUI() { /* (保持不变) */ 
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: GestureDetector(
        onTap: _pickContract, 
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Contract (Optional PDF)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.description_outlined, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
          ),
          child: Text('Tap to select PDF file', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      ),
    );
  }

  // lib/screens/add_property_screen.dart -> 确保粘贴在 _AddPropertyScreenState 类的 { ... } 内部

  // ✅ 9. 粘贴这个缺失的函数：小区下拉菜单
  Widget _buildCommunityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCommunity,
      // 样式
      decoration: InputDecoration(
        labelText: 'Community / Apartment',
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(_isCommunityListLoading ? Icons.hourglass_top : Icons.apartment, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
      // 菜单样式
      dropdownColor: const Color(0xFF295a68), 
      style: const TextStyle(color: Colors.white, fontSize: 16),
      iconEnabledColor: Colors.white70,
      isExpanded: true,
      // 提示
      hint: Text(
        _isCommunityListLoading ? 'Loading communities...' : 'Select community', 
        style: const TextStyle(color: Colors.white70)
      ),
      // 验证
      validator: (value) => value == null ? 'Please select a community' : null,
      // 逻辑
      onChanged: _isCommunityListLoading ? null : (String? newValue) {
        setState(() {
          _selectedCommunity = newValue;
        });
      },
      // 选项
      items: _communityList.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }

// ... (您其他的 _build... 函数 和 build 方法) ...
  
  Widget _buildGenerateUI() { /* (保持不变) */ 
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _generatedContractLanguage,
                  dropdownColor: const Color(0xFF295a68),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.language, color: Colors.white70),
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _generatedContractLanguage = val);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateContract,
              icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_stories, size: 18),
              label: Text(_isLoading ? 'Generating...' : 'Generate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D5DC7),
                foregroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(vertical: 16), 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChoiceChip({ /* (保持不变) */ 
    required String label,
    required IconData icon,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    final Color backgroundColor = selected 
        ? const Color(0xFF1D5DC7).withOpacity(0.5) 
        : Colors.white.withOpacity(0.2); 
    final Color contentColor = Colors.white; 
    final Border border = selected
        ? Border.all(color: Colors.white, width: 1.5) 
        : Border.all(color: Colors.white.withOpacity(0.3)); 

    return GestureDetector(
      onTap: () => onSelected(true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10), 
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), 
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
            decoration: BoxDecoration(
              color: backgroundColor, borderRadius: BorderRadius.circular(10),
              border: border, 
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(icon, color: contentColor, size: 20), 
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: contentColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() => GestureDetector( /* (保持不变) */ 
    onTap: () => _selectDate(context),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: 'Available Date',
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
      child: Text(
        _selectedDate == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(_selectedDate!),
        style: TextStyle(color: _selectedDate == null ? Colors.white70 : Colors.white, fontSize: 16),
      ),
    ),
  );

  Widget _buildNumericFeatureItem({ /* (保持不变) */ 
    required String label,
    required IconData icon,
    required int value,
    required Function(int) onConfirmed,
  }) {
    return GestureDetector(
      onTap: () {
        _showNumberSliderDialog(title: label, currentValue: value, onConfirm: onConfirmed);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
            Text(value.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildFurnishingSelector() { /* (保持不变) */ 
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

  // ---------------- 主界面 Build (布局重构) ----------------
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF153a44), Color(0xFF295a68),
                  Color(0xFF5d8fa0), Color(0xFF94bac4),
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
                    _buildImagePicker(),
                    const SizedBox(height: 16),
                    _buildGlassCard( // Main Info
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCommunityDropdown(), 
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextFormField(
                                  controller: _floorController, 
                                  labelText: 'Floor Level', 
                                  icon: Icons.stairs_outlined,
                                  keyboardType: TextInputType.text, 
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextFormField(
                                  controller: _unitController, 
                                  labelText: 'Unit / Room No.', 
                                  icon: Icons.meeting_room_outlined,
                                  keyboardType: TextInputType.text, 
                                  validator: (value) => (value == null || value.isEmpty) 
                                      ? 'Please enter unit' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                    
                    _buildGlassCard( // Property Features
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Property Features', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Column(
                            children: [
                              _buildNumericFeatureItem(label: 'Air Conditioner', icon: Icons.ac_unit, value: _airConditioners, onConfirmed: (v) => setState(() => _airConditioners = v)),
                              const SizedBox(height: 8),
                              _buildNumericFeatureItem(label: 'Bedroom', icon: Icons.king_bed_outlined, value: _bedrooms, onConfirmed: (v) => setState(() => _bedrooms = v)),
                              const SizedBox(height: 8),
                              _buildNumericFeatureItem(label: 'Bathroom', icon: Icons.bathtub_outlined, value: _bathrooms, onConfirmed: (v) => setState(() => _bathrooms = v)),
                              const SizedBox(height: 8),
                              _buildNumericFeatureItem(label: 'Car Park', icon: Icons.local_parking_outlined, value: _parking, onConfirmed: (v) => setState(() => _parking = v)),
                              const Divider(color: Colors.white30, height: 24), 
                              ..._featureOptions.entries.map((e) {
                                final key = e.key;
                                if (key.toLowerCase().contains('air')) { 
                                  return const SizedBox.shrink(); 
                                }
                                final isSelected = _selectedFeatures.contains(key);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    leading: Icon(e.value, color: Colors.white, size: 20),
                                    title: Text(key, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) _selectedFeatures.add(key);
                                          else _selectedFeatures.remove(key);
                                        });
                                      },
                                      activeColor: Colors.white,
                                      checkColor: const Color(0xFF1D5DC7),
                                    ),
                                    onTap: () { 
                                      setState(() {
                                        if (isSelected) _selectedFeatures.remove(key);
                                        else _selectedFeatures.add(key);
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildGlassCard( // Facilities
                      child: _buildCheckboxGrid(title: 'Facilities', options: _facilityOptions, selectedOptions: _selectedFacilities),
                    ),

                    const SizedBox(height: 16),
                    _buildGlassCard(child: _buildContractPicker()),
                    const SizedBox(height: 24),
                    ElevatedButton( // Submit Button
                      onPressed: _isLoading ? null : _showConfirmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5DC7),
                        foregroundColor: Colors.white, // ✅ 确保提交按钮文字也是白色
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