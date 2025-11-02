// ignore_for_file: unused_import

import 'dart:ui'; 
import 'package:flutter/material.dart';
import '../Services/storage_service.dart'; 
// ✅ 1. 导入 cloud_firestore 和 firebase_auth (用于更新)
// （虽然 storage_service 做了，但最佳实践是在调用处也获取引用）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


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

  // ✅ 2. 【已修改】 _pickAndUploadAvatar
  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // 步骤 1: 调用 Service 上传并获取新的 URL
      // (您的 storage_service 已经正确地在内部更新了 Firestore)
      final String? newUrl = await _storageService.uploadAvatarAndGetURL();
      
      // 步骤 2: 【关键修复】如果成功，清除本地的图片缓存
      if (newUrl != null && mounted) {
        // 这会强制 Image.network 在下次构建时重新下载图片
        await NetworkImage(newUrl).evict(); 
        print("Image cache evicted for: $newUrl");
      }

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
    // (build 方法保持不变)
    return Padding(
      padding: const EdgeInsets.all(16.0), 
      child: ClipRRect(
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
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight, 
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white.withOpacity(0.1), 
                      backgroundImage: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                          ? NetworkImage(widget.avatarUrl!) // 👈 StreamBuilder 重建时会触发这个
                          : null,
                      child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white70, 
                            )
                          : null,
                    ),
                    _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white), 
                          )
                        : GestureDetector(
                            onTap: _pickAndUploadAvatar, 
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF1D5DC7), 
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, 
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.white70), 
                          const SizedBox(width: 8),
                          Text(
                            widget.phone,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70, 
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
