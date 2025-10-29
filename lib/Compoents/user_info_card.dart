import 'dart:ui'; // 1. 导入毛玻璃效果
import 'package:flutter/material.dart';
import '../Services/storage_service.dart'; 

// ... (StatefulWidget, State, 和 _storageService 保持不变) ...
class UserInfoCard extends StatefulWidget {
  final String name;
  final String phone;
  final String? avatarUrl;

  const UserInfoCard({
    super.key,
    required this.name,
    required this.phone,
    this.avatarUrl,
  });

  @override
  State<UserInfoCard> createState() => _UserInfoCardState();
}

class _UserInfoCardState extends State<UserInfoCard> {
  final StorageService _storageService = StorageService();
  bool _isUploading = false;

  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _isUploading = true;
    });

    try {
      await _storageService.uploadAvatarAndGetURL();
    } catch (e) {
      print("上传失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload Failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. 移除 Card, 替换为毛玻璃 UI
    return Padding(
      padding: const EdgeInsets.all(16.0), // 保持外边距
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20), // 圆角
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // 模糊效果
          child: Container(
            padding: const EdgeInsets.all(16.0), // 内部填充
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15), // 半透明白色
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)), // 细边框
            ),
            // 3. Row 内部的上传和文本逻辑保持不变
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight, 
                  children: [
                    // 4. 更新头像的背景和默认图标颜色
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white.withOpacity(0.1), // 更新背景
                      backgroundImage: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                          ? NetworkImage(widget.avatarUrl!)
                          : null,
                      child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white70, // 更新图标颜色
                            )
                          : null,
                    ),
                    _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white), // 更新加载圈颜色
                          )
                        : GestureDetector(
                            onTap: _pickAndUploadAvatar, 
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF1D5DC7), // 保持按钮颜色
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ],
                ),

                const SizedBox(width: 20), 

                // 5. 更新右侧文本和图标的颜色
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // 更新文本颜色
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.white70), // 更新图标颜色
                          const SizedBox(width: 8),
                          Text(
                            widget.phone,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70, // 更新文本颜色
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}