import 'dart:io';
import 'dart:ui'; // 虽然这里不再定义GlassCard，但为了防止其他UI依赖，保留引用
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:collection/collection.dart'; 

// ✅ 引入自定义组件 (注意路径拼写匹配你的文件夹 'Compoents')
import '../Compoents/add_property_widgets.dart'; 
import '../Compoents/panorama_widget.dart';     // 360 组件
import '../Compoents/contract_generator.dart';
import '../Compoents/glass_card.dart';          // 👈 必须引入这个，删除底部的本地定义

class AddPropertyScreen extends StatefulWidget {
  final String? propertyId; // 传入 ID 则为编辑模式

  const AddPropertyScreen({super.key, this.propertyId});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  // --- 核心状态变量 ---
  final _formKey = GlobalKey<FormState>();
  
  // 文本控制器
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sizeController = TextEditingController();
  final _floorController = TextEditingController();
  final _unitController = TextEditingController();
  
  // UI 状态
  bool _isLoading = false;
  bool _isCommunityListLoading = true;
  
  // 数据状态
  List<Map<String, dynamic>> _communityList = [];
  Map<String, dynamic>? _selectedCommunity;
  Map<String, dynamic> _existingPropertyData = {}; 
  
  // 房源字段
  List<XFile> _selectedImages = []; 
  
  // ✅ 360 全景图相关字段
  XFile? _selected360Image; 
  String? _existing360Url; 

  // 合同相关
  File? _selectedContract;
  String? _selectedContractName;
  ContractOption _contractOption = ContractOption.none;
  String _generatedContractLanguage = 'zh';
  
  // 其他属性
  DateTime? _selectedDate;
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _parking = 0;
  int _airConditioners = 0;
  
  String _selectedFurnishing = 'Unfurnished';
  final List<String> _furnishingOptions = ['Fully Furnished', 'Half Furnished', 'Unfurnished'];
  
  Set<String> _selectedFeatures = {};
  Set<String> _selectedFacilities = {};
  
  String _landlordName = "Loading...";

  bool get _isEditMode => widget.propertyId != null;

  final Map<String, IconData> _featureOptions = {
    'Air Conditioner': Icons.ac_unit, 'Refrigerator': Icons.kitchen,
    'Washing Machine': Icons.local_laundry_service, 'Wifi': Icons.wifi,
    'Balcony': Icons.balcony, 'Smart Lock': Icons.lock,
  };
  final Map<String, IconData> _facilityOptions = {
    '24-hour Security': Icons.security, 'Free Indoor Gym': Icons.fitness_center,
    'Free Outdoor Pool': Icons.pool, 'Parking Area': Icons.local_parking,
  };

  // --- 初始化与销毁 ---
  @override
  void initState() {
    super.initState();
    _fetchLandlordName();
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

  // --- 数据获取逻辑 ---

  Future<void> _fetchLandlordName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() => _landlordName = doc.data()?['name'] ?? 'Landlord');
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchCommunities() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('communities').get();
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
      if (mounted) {
        setState(() => _isCommunityListLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load communities: $e')));
      }
    }
  }

  Future<void> _loadPropertyData() async {
    if (!_isEditMode) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(widget.propertyId!).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        _existingPropertyData = data;

        _priceController.text = (data['price'] ?? 0.0).toStringAsFixed(0);
        _descriptionController.text = data['description'] ?? '';
        _sizeController.text = data['size_sqft'] ?? '';
        _floorController.text = data['floor'] ?? '';
        _unitController.text = data['unitNumber'] ?? '';

        setState(() {
          // 回填社区
          if (_communityList.isNotEmpty) {
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
          
          // 回填 360 图片
          if (data['360ImageUrl'] != null) {
            _existing360Url = data['360ImageUrl'];
          }
        });
      }
    } catch (e) {
      print("Error loading property: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 图片与文件选择 ---

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1024);
    if (images.isNotEmpty) {
      setState(() { _selectedImages = images; });
    }
  }

  // ✅ 360 图片选择 (支持拍照和相册)
  Future<void> _pick360Image() async {
    final ImagePicker picker = ImagePicker();

    // 弹出底部菜单
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF295a68),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              
              // 选项 1: 拍照
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Please switch to "Panorama" mode manually', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  _processImagePick(picker, ImageSource.camera);
                },
              ),
              
              // 选项 2: 相册
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  _processImagePick(picker, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // 辅助选图处理
  Future<void> _processImagePick(ImagePicker picker, ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📸 Opening Camera... Use Panorama mode!'), duration: Duration(seconds: 3)),
        );
      }
      final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selected360Image = image;
        });
      }
    } catch (e) {
      print("Error picking 360 image: $e");
    }
  }

  Future<void> _pickContract() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      setState(() {
        _selectedContract = File(result.files.single.path!);
        _selectedContractName = result.files.single.name;
        _contractOption = ContractOption.upload;
      });
    }
  }

  Future<void> _generateContract() async {
    if (_selectedCommunity == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a community first.'))); return;
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in required fields first.'))); return;
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
      
      await OpenFile.open(generatedFile.path);

      if (mounted) {
        final bool? didConfirm = await showDialog<bool>(
          context: context, barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Contract'),
            content: const Text('Use this generated contract?'),
            actions: [
              TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx, false)),
              ElevatedButton(child: const Text('Confirm'), onPressed: () => Navigator.pop(ctx, true)),
            ],
          )
        );
        if (didConfirm == true && mounted) {
          setState(() {
            _selectedContract = generatedFile;
            _selectedContractName = "Generated_Contract_${DateTime.now().millisecondsSinceEpoch}.pdf";
          });
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generation failed: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- 提交/更新/删除逻辑 ---

  Future<void> _showConfirmDialog() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommunity == null || _selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check Community and Date fields.'))); return;
    }
    // 检查是否有图
    bool hasImages = _selectedImages.isNotEmpty;
    if (_isEditMode && (_existingPropertyData['imageUrls'] as List?)?.isNotEmpty == true) {
      hasImages = true; 
    }
    if (!hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one property image.'))); return;
    }

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
      _isEditMode ? await _updateProperty() : await _addProperty();
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final storage = FirebaseStorage.instance;
    List<String> urls = [];
    for (final img in images) {
      final fileName = 'property_images/${DateTime.now().millisecondsSinceEpoch}_${img.name}';
      final ref = storage.ref().child(fileName);
      await ref.putFile(File(img.path));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<String> _uploadContract(File contract) async {
    final fileName = 'contracts/${DateTime.now().millisecondsSinceEpoch}_${_selectedContractName ?? "contract.pdf"}';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    await ref.putFile(contract);
    return await ref.getDownloadURL();
  }

  Future<void> _addProperty() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 上传各种文件
      final imageUrls = await _uploadImages(_selectedImages);
      final contractUrl = _selectedContract != null ? await _uploadContract(_selectedContract!) : null;
      
      String? url360;
      if (_selected360Image != null) {
        final ref = FirebaseStorage.instance.ref().child('properties_360/${DateTime.now().millisecondsSinceEpoch}_pano.jpg');
        await ref.putFile(File(_selected360Image!.path));
        url360 = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('properties').add({
        'landlordUid': user.uid,
        'communityName': _selectedCommunity!['name'],
        'latitude': (_selectedCommunity!['latitude'] as num?)?.toDouble() ?? 0.0,
        'longitude': (_selectedCommunity!['longitude'] as num?)?.toDouble() ?? 0.0,
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
        'imageUrls': imageUrls,
        'contractUrl': contractUrl,
        '360ImageUrl': url360, 
        'createdAt': Timestamp.now(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Property Added Successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProperty() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> updateData = {
        'communityName': _selectedCommunity!['name'],
        'latitude': (_selectedCommunity!['latitude'] as num?)?.toDouble() ?? 0.0,
        'longitude': (_selectedCommunity!['longitude'] as num?)?.toDouble() ?? 0.0,
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
        updateData['imageUrls'] = await _uploadImages(_selectedImages);
      }
      if (_selectedContract != null) {
        updateData['contractUrl'] = await _uploadContract(_selectedContract!);
      }
      
      // 更新 360 图片
      if (_selected360Image != null) {
        final ref = FirebaseStorage.instance.ref().child('properties_360/${DateTime.now().millisecondsSinceEpoch}_pano.jpg');
        await ref.putFile(File(_selected360Image!.path));
        updateData['360ImageUrl'] = await ref.getDownloadURL();
      } else if (_existing360Url == null) {
        updateData['360ImageUrl'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance.collection('properties').doc(widget.propertyId!).update(updateData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Property Updated!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProperty() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property'),
        content: const Text('Permanently delete this property? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      )
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    
    try {
      final storage = FirebaseStorage.instance;
      // 删旧文件
      if (_existingPropertyData['contractUrl'] != null) {
        try { await storage.refFromURL(_existingPropertyData['contractUrl']).delete(); } catch (_) {}
      }
      if (_existingPropertyData['imageUrls'] != null) {
        for (final url in List<String>.from(_existingPropertyData['imageUrls'])) {
          try { await storage.refFromURL(url).delete(); } catch (_) {}
        }
      }
      if (_existingPropertyData['360ImageUrl'] != null) {
        try { await storage.refFromURL(_existingPropertyData['360ImageUrl']).delete(); } catch (_) {}
      }
      
      await FirebaseFirestore.instance.collection('properties').doc(widget.propertyId!).delete();
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property Deleted.')));
        Navigator.pop(context);
      }
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }
  
  // 弹出的滑块数字选择器
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
            insetPadding: const EdgeInsets.all(24),
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
                      Text(tempValue.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                      Slider(
                        value: tempValue.toDouble(), min: 0, max: 10, divisions: 10,
                        activeColor: Colors.white, inactiveColor: Colors.white30,
                        onChanged: (v) { setStateDialog(() { tempValue = v.toInt(); }); },
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
                        ElevatedButton(
                           onPressed: () { onConfirm(tempValue); Navigator.pop(context); },
                           style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D5DC7)),
                           child: const Text('OK', style: TextStyle(color: Colors.white)),
                        ),
                      ])
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

  // 本地图片区域
  Widget _buildImageSection() {
    final List<String> existingUrls = List<String>.from(_existingPropertyData['imageUrls'] ?? []);
    bool showExisting = _selectedImages.isEmpty && existingUrls.isNotEmpty;
    
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: (!showExisting && _selectedImages.isEmpty)
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 40),
                const SizedBox(height: 8),
                Text(_isEditMode ? 'Tap to change pictures' : 'Add Pictures', style: const TextStyle(color: Colors.white70)),
              ]))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: showExisting ? existingUrls.length : _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: showExisting
                      ? Image.network(existingUrls[index], fit: BoxFit.cover, width: 134, height: 134)
                      : Image.file(File(_selectedImages[index].path), fit: BoxFit.cover, width: 134, height: 134),
                  ),
                );
              },
            ),
      ),
    );
  }

  // --- Build 方法 (核心) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text(_isEditMode ? 'Edit Property' : 'Add New Property', style: const TextStyle(color: Colors.white)),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. 普通图片
                    _buildImageSection(),
                    const SizedBox(height: 16),

                    // ✅ 2. 360 全景图 (集成组件)
                    PanoramaUploadCard(
                      selectedFile: _selected360Image,
                      existingUrl: _existing360Url,
                      onTap: _pick360Image,
                      onClear: () {
                        setState(() {
                          _selected360Image = null;
                          _existing360Url = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 3. 主要信息
                    GlassCard(
                      child: MainInfoForm(
                        communityList: _communityList.map((e) => e['name'] as String).toList(),
                        selectedCommunity: _selectedCommunity?['name'],
                        isCommunityListLoading: _isCommunityListLoading,
                        floorController: _floorController,
                        unitController: _unitController,
                        descriptionController: _descriptionController,
                        priceController: _priceController,
                        sizeController: _sizeController,
                        selectedDate: _selectedDate,
                        selectedFurnishing: _selectedFurnishing,
                        furnishingOptions: _furnishingOptions,
                        onCommunityChanged: (val) {
                           setState(() {
                             _selectedCommunity = _communityList.firstWhereOrNull((c) => c['name'] == val);
                           });
                        },
                        onFurnishingChanged: (v) => setState(() => _selectedFurnishing = v!),
                        onDateTap: () async {
                           final picked = await showDatePicker(
                             context: context, initialDate: _selectedDate ?? DateTime.now(),
                             firstDate: DateTime.now(), lastDate: DateTime(2101));
                           if(picked != null) setState(() => _selectedDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 4. 特性
                    GlassCard(
                      child: PropertyFeaturesForm(
                        airConditioners: _airConditioners,
                        bedrooms: _bedrooms,
                        bathrooms: _bathrooms,
                        parking: _parking,
                        featureOptions: _featureOptions,
                        selectedFeatures: _selectedFeatures,
                        onShowSlider: (title, val, cb) => _showNumberSliderDialog(title: title, currentValue: val, onConfirm: cb),
                        onToggleFeature: (key) => setState(() {
                           if(_selectedFeatures.contains(key)) _selectedFeatures.remove(key);
                           else _selectedFeatures.add(key);
                        }),
                        onUpdateAirConditioners: (v) => setState(() => _airConditioners = v),
                        onUpdateBedrooms: (v) => setState(() => _bedrooms = v),
                        onUpdateBathrooms: (v) => setState(() => _bathrooms = v),
                        onUpdateParking: (v) => setState(() => _parking = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 5. 设施
                    GlassCard(
                      child: FacilitiesForm(
                        facilityOptions: _facilityOptions,
                        selectedFacilities: _selectedFacilities,
                        onToggle: (key) => setState(() {
                           if(_selectedFacilities.contains(key)) _selectedFacilities.remove(key);
                           else _selectedFacilities.add(key);
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 6. 合同
                    GlassCard(
                      child: ContractPicker(
                        isLoading: _isLoading,
                        contractOption: _contractOption,
                        selectedContract: _selectedContract,
                        selectedContractName: _selectedContractName ?? 
                          (_isEditMode && _existingPropertyData['contractUrl'] != null ? "Existing Contract on File" : null),
                        generatedContractLanguage: _generatedContractLanguage,
                        onOptionSelected: (opt) => setState(() => _contractOption = opt),
                        onLanguageChanged: (l) => setState(() => _generatedContractLanguage = l!),
                        onPickContract: _pickContract,
                        onGenerateContract: _generateContract,
                        onClearContract: () => setState(() {
                           _selectedContract = null;
                           _selectedContractName = null;
                           _contractOption = ContractOption.none;
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 提交按钮
                    ElevatedButton(
                      onPressed: _isLoading ? null : _showConfirmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5DC7),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(height:20, width:20, child: CircularProgressIndicator(color: Colors.white))
                        : Text(_isEditMode ? 'Save Changes' : 'Post Property', style: const TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    
                    // 删除按钮 (仅编辑模式)
                    if(_isEditMode) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _deleteProperty,
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        label: const Text('Delete Property', style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      )
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