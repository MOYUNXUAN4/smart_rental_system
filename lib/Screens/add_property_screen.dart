import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

// ✅ 1. 【已修复】: 导入 'collection' 包以使用 'firstWhereOrNull'
import 'package:collection/collection.dart';

import '../Compoents/contract_generator.dart'; 

class AddPropertyScreen extends StatefulWidget {
  // ✅ 2. 接收可选的 propertyId
  final String? propertyId;

  const AddPropertyScreen({super.key, this.propertyId});

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
  
  // ✅ 3. 【修改】: 更改这两个状态的类型
  List<Map<String, dynamic>> _communityList = []; // 👈 不再是 List<String>
  Map<String, dynamic>? _selectedCommunity;      // 👈 不再是 String?
  bool _isCommunityListLoading = true;
  
  // ✅ 4. 添加 "编辑模式" 检查器和旧数据持有者
  bool get _isEditMode => widget.propertyId != null;
  Map<String, dynamic> _existingPropertyData = {}; // 用于存储旧数据 (例如图片URL)


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
    // ✅ 5. 在获取列表后，再尝试加载数据
    _fetchCommunities().then((_) {
      if (_isEditMode) {
        _loadPropertyData();
      }
    }); 
  }
  
  @override
  void dispose() {
    _floorController.dispose(); 
    _unitController.dispose(); 
    _priceController.dispose();
    _descriptionController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLandlordName() async { 
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

  // ✅ 6. 【修改】: _fetchCommunities 现在获取完整的文档数据
  Future<void> _fetchCommunities() async { 
    try {
      final snapshot = await FirebaseFirestore.instance.collection('communities').get();
      // 将每个文档的数据 (Map) 存储到列表中
      final communities = snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id; 
        return data;
      }).toList();
      
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

  // ✅ 7. 【新函数】: 加载已有房源数据 (已修复 Bug)
  Future<void> _loadPropertyData() async {
    if (!_isEditMode) return;
    setState(() => _isLoading = true); 
    try {
      final doc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId!)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        _existingPropertyData = data; 

        _priceController.text = (data['price'] ?? 0.0).toStringAsFixed(0);
        _descriptionController.text = data['description'] ?? '';
        _sizeController.text = data['size_sqft'] ?? '';
        _floorController.text = data['floor'] ?? '';
        _unitController.text = data['unitNumber'] ?? '';

        setState(() {
          if (_communityList.isNotEmpty) {
             // 👈 【已修复】: 使用 firstWhereOrNull 替代 firstWhere
             _selectedCommunity = _communityList.firstWhereOrNull( 
              (c) => c['name'] == data['communityName'],
            );
          }
          
          _bedrooms = data['bedrooms'] ?? 1;
          _bathrooms = data['bathrooms'] ?? 1;
          _parking = data['parking'] ?? 0;
          _airConditioners = data['airConditioners'] ?? 0;
          _selectedFurnishing = data['furnishing'] ?? 'Unfurnished';
          _selectedFeatures = Set<String>.from(data['features'] ?? []);
          _selectedFacilities = Set<String>.from(data['facilities'] ?? []);
          _selectedDate = (data['availableDate'] as Timestamp?)?.toDate();
        });
      }
    } catch (e) {
      print("Error loading property data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  Future<void> _pickImages() async { 
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1024);
    if (images.isNotEmpty) {
      setState(() { _selectedImages = images; });
    }
  }

  Future<void> _pickContract() async { 
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
  
  // ✅ 8. 【修改】: _generateContract 现在从 Map 中获取小区名
  Future<void> _generateContract() async { 
    if (_selectedCommunity == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a community first.'))); return;
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in required fields (Price, etc).'))); return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final String communityName = _selectedCommunity!['name'] as String;
      final String fullAddress = "${_unitController.text.trim()}, Floor ${_floorController.text.trim()}, $communityName";
      
      final File generatedFile = await ContractGenerator.generateAndSaveContract(
        landlordName: _landlordName, tenantName: "________________",
        propertyAddress: fullAddress, 
        rentAmount: _priceController.text.trim(),
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

  Future<void> _selectDate(BuildContext context) async { 
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
    }
  }

  // ✅ 9. 修改 _showConfirmDialog 以支持两种模式
  Future<void> _showConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEditMode ? "Confirm Changes" : "Confirm Upload"), 
        content: Text("Are you sure you want to ${_isEditMode ? 'save changes' : 'upload this property'}?"), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
        ],
      ),
    );
    if (confirmed == true) {
      // ✅ 10. 根据模式调用不同的保存函数
      if (_isEditMode) {
        await _updateProperty();
      } else {
        await _addProperty();
      }
    }
  }

  // ✅ 11. 将 _submitProperty 重命名为 _addProperty (用于添加新房源)
  Future<void> _addProperty() async { 
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

      final String communityName = _selectedCommunity!['name'] as String;
      final double latitude = (_selectedCommunity!['latitude'] as num?)?.toDouble() ?? 0.0;
      final double longitude = (_selectedCommunity!['longitude'] as num?)?.toDouble() ?? 0.0;

      await FirebaseFirestore.instance.collection('properties').add({
        'landlordUid': user.uid, 
        'communityName': communityName, 
        'latitude': latitude,           
        'longitude': longitude,         
        'floor': _floorController.text.trim(), 
        'unitNumber': _unitController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'description': _descriptionController.text.trim(), 
        'size_sqft': _sizeController.text.trim(),
        'bedrooms': _bedrooms, 'bathrooms': _bathrooms, 'parking': _parking,
        'airConditioners': _airConditioners, 'furnishing': _selectedFurnishing,
        'availableDate': Timestamp.fromDate(_selectedDate!),
        'features': _selectedFeatures.toList(), 
        'facilities': _selectedFacilities.toList(),
        'imageUrls': imageUrls, 'contractUrl': contractUrl, 'createdAt': Timestamp.now(),
      });

      if (mounted) {
        setState(() => _isLoading = false); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Property Added Successfully!')));
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      print("添加房产失败: $e");
      if (mounted) {
        setState(() => _isLoading = false); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to add property: $e')));
      }
    }
  }
  
  // ✅ 12. 【新函数】: 用于更新现有房源
  Future<void> _updateProperty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommunity == null) { /* ... */ }
    if (_selectedDate == null) { /* ... */ }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final String communityName = _selectedCommunity!['name'] as String;
      final double latitude = (_selectedCommunity!['latitude'] as num?)?.toDouble() ?? 0.0;
      final double longitude = (_selectedCommunity!['longitude'] as num?)?.toDouble() ?? 0.0;
      
      Map<String, dynamic> updateData = {
        'communityName': communityName, 
        'latitude': latitude,           
        'longitude': longitude,         
        'floor': _floorController.text.trim(), 
        'unitNumber': _unitController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'description': _descriptionController.text.trim(), 
        'size_sqft': _sizeController.text.trim(),
        'bedrooms': _bedrooms, 'bathrooms': _bathrooms, 'parking': _parking,
        'airConditioners': _airConditioners, 'furnishing': _selectedFurnishing,
        'availableDate': Timestamp.fromDate(_selectedDate!),
        'features': _selectedFeatures.toList(), 
        'facilities': _selectedFacilities.toList(),
      };

      if (_selectedImages.isNotEmpty) {
        final imageUrls = await _uploadImages(_selectedImages);
        updateData['imageUrls'] = imageUrls;
      }
      if (_selectedContract != null) {
        final contractUrl = await _uploadContract(_selectedContract!);
        updateData['contractUrl'] = contractUrl;
      }

      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId!)
          .update(updateData);

      if (mounted) {
        setState(() => _isLoading = false); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Property Updated Successfully!')));
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      print("更新房产失败: $e");
      if (mounted) {
        setState(() => _isLoading = false); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to update property: $e')));
      }
    }
  }

  // ✅ 13. 【新函数】: 删除房源
  Future<void> _deleteProperty() async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Property'),
          content: const Text('Are you sure you want to permanently delete this property? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton( 
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (didConfirm != true) return; 

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final storage = FirebaseStorage.instance;
      
      if (_existingPropertyData['contractUrl'] != null && _existingPropertyData['contractUrl'].isNotEmpty) {
        try {
          await storage.refFromURL(_existingPropertyData['contractUrl']).delete();
        } catch (e) {
          print("Note: Failed to delete old contract, it might not exist: $e");
        }
      }

      if (_existingPropertyData['imageUrls'] != null) {
        final List<String> oldUrls = List<String>.from(_existingPropertyData['imageUrls']);
        for (final url in oldUrls) {
          if (url.isNotEmpty) {
             try {
              await storage.refFromURL(url).delete();
            } catch (e) {
              print("Note: Failed to delete old image, it might not exist: $e");
            }
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId!)
          .delete();
          
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Property Deleted Successfully!')));
        Navigator.of(context).pop(); 
      }

    } catch (e) {
      print("删除房产失败: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to delete property: $e')));
      }
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
    final fileName = 'contracts/${DateTime.now().millisecondsSinceEpoch}_${_selectedContractName ?? "contract.pdf"}';
    final ref = storage.ref().child(fileName);
    await ref.putFile(contract);
    return await ref.getDownloadURL();
  }

  Future<void> _showNumberSliderDialog({ 
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

  // --- 11. 【UI 构建辅助函数】 ---
  // (这些都是您原来的 _build... 函数，现在已修复)

  Widget _buildGlassCard({required Widget child}) { 
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

  Widget _buildImagePicker() {
    final List<String> existingUrls = List<String>.from(_existingPropertyData['imageUrls'] ?? []);
    
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 150, 
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: (_selectedImages.isEmpty && existingUrls.isEmpty)
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 40),
                    const SizedBox(height: 8),
                    Text(_isEditMode ? 'Tap to add/replace pictures' : 'Add Pictures', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : _selectedImages.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.all(8.0), 
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, 
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0), 
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0), 
                        child: Image.file(
                          File(_selectedImages[index].path), 
                          fit: BoxFit.cover, width: 134, height: 134,
                        ),
                      ),
                    );
                  },
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0), 
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, 
                  itemCount: existingUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0), 
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0), 
                        child: Image.network( 
                          existingUrls[index], 
                          fit: BoxFit.cover, width: 134, height: 134,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildTextFormField({ 
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

  Widget _buildContractPicker() {
    final String? existingContractUrl = _existingPropertyData['contractUrl'];
    
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
          )
        else if (_isEditMode && existingContractUrl != null && existingContractUrl.isNotEmpty && _contractOption == ContractOption.none)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container( 
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Using existing contract',
                      style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildUploadUI() { 
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: GestureDetector(
        onTap: _pickContract, 
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: _isEditMode ? 'Upload Replacement PDF' : 'Contract (Optional PDF)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.description_outlined, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
          ),
          child: Text(
            _isEditMode ? 'Tap to replace existing PDF' : 'Tap to select PDF file', 
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildCommunityDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>( // 👈 【已修复】
      value: _selectedCommunity,
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
      dropdownColor: const Color(0xFF295a68), 
      style: const TextStyle(color: Colors.white, fontSize: 16),
      iconEnabledColor: Colors.white70,
      isExpanded: true,
      hint: Text(
        _isCommunityListLoading ? 'Loading communities...' : 'Select community', 
        style: const TextStyle(color: Colors.white70)
      ),
      validator: (value) => value == null ? 'Please select a community' : null,
      onChanged: _isCommunityListLoading ? null : (Map<String, dynamic>? newValue) { // 👈 【已修复】
        setState(() {
          _selectedCommunity = newValue;
        });
      },
      items: _communityList.map((Map<String, dynamic> community) { // 👈 【已修复】
        return DropdownMenuItem<Map<String, dynamic>>( // 👈 【已修复】
          value: community,
          child: Text(community['name'] as String? ?? 'Unnamed', overflow: TextOverflow.ellipsis), // 👈 【已修复】
        );
      }).toList(),
    );
  }
  
  Widget _buildGenerateUI() { 
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
  
  Widget _buildChoiceChip({ 
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

  Widget _buildDatePicker() => GestureDetector( 
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
        title: Text(_isEditMode ? 'Edit Property' : 'Add New Property', style: const TextStyle(color: Colors.white)),
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
                    
                    // 提交按钮
                    ElevatedButton( 
                      onPressed: _isLoading ? null : _showConfirmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5DC7),
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Text(_isEditMode ? 'Save Changes' : 'Add Property', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    
                    // 删除按钮
                    if (_isEditMode) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _deleteProperty, 
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Property'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[300], 
                          side: BorderSide(color: Colors.red[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],

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