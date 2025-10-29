import 'dart:ui'; // 用于毛玻璃效果
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  // 1. 表单 Key 和 Controller
  final _formKey = GlobalKey<FormState>();
  final _propertyNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();

  // 2. 状态
  bool _isLoading = false;

  @override
  void dispose() {
    _propertyNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // 3. 提交逻辑 (目前为空)
  Future<void> _submitProperty() async {
    // 验证表单
    if (!_formKey.currentState!.validate()) {
      return; // 如果表单无效，则不继续
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // --- TODO: 在这里添加 Firebase 上传逻辑 ---
      // 1. 上传图片到 Firebase Storage (我们稍后添加)
      // 2. 获取图片 URLs
      // 3. 将房产数据 (和图片 URLs) 保存到 Firestore
      
      print("房产名称: ${_propertyNameController.text}");
      print("价格: ${_priceController.text}");
      
      // 模拟网络延迟
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property Added Successfully!')),
        );
        Navigator.of(context).pop(); // 成功后返回上一页
      }

    } catch (e) {
      print("添加房产失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add property: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4. 使用与 Landlord/Tenant 屏幕相同的 UI 风格
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
          // 背景渐变
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

          // 5. 表单内容
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- TODO: 添加图片选择器 ---
                    // (暂时留空)

                    // 6. 毛玻璃卡片容器
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTextFormField(
                                controller: _propertyNameController,
                                labelText: 'Property Name',
                                icon: Icons.home_work,
                                validator: (value) => (value == null || value.isEmpty) 
                                    ? 'Please enter a name' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                controller: _addressController,
                                labelText: 'Address',
                                icon: Icons.location_on,
                                validator: (value) => (value == null || value.isEmpty) 
                                    ? 'Please enter an address' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                controller: _priceController,
                                labelText: 'Price (RM per Month)',
                                icon: Icons.attach_money,
                                keyboardType: TextInputType.number,
                                validator: (value) => (value == null || value.isEmpty) 
                                    ? 'Please enter a price' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                controller: _descriptionController,
                                labelText: 'Description (e.g., 3 Rooms, 2 Baths)',
                                icon: Icons.description,
                                maxLines: 3,
                                validator: (value) => (value == null || value.isEmpty) 
                                    ? 'Please enter a description' : null,
                              ),
                              const SizedBox(height: 24),
                              
                              // 7. 提交按钮
                              ElevatedButton(
                                onPressed: _isLoading ? null : _submitProperty,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D5DC7),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Text(
                                      'Add Property',
                                      style: TextStyle(color: Colors.white, fontSize: 16),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 辅助 Widget：创建统一样式的输入框
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
        labelStyle: TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}