// ignore_for_file: unused_import

import 'dart:ui'; 
import 'package:flutter/material.dart';
import '../Services/storage_service.dart'; 

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class UserInfoCard extends StatefulWidget {
  final String name;
  final String phone;
  final String? avatarUrl;
  final int pendingBookingCount; 
  final VoidCallback? onNotificationTap; 

  const UserInfoCard({
    super.key,
    required this.name,
    required this.phone,
    this.avatarUrl,
    required this.pendingBookingCount, 
    this.onNotificationTap,
  });

  @override
  State<UserInfoCard> createState() => _UserInfoCardState();
}

class _UserInfoCardState extends State<UserInfoCard> {
  final StorageService _storageService = StorageService();
  bool _isUploading = false;

  // ( _pickAndUploadAvatar 方法保持不变 )
  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _isUploading = true;
    });
    try {
      final String? newUrl = await _storageService.uploadAvatarAndGetURL();
      if (newUrl != null && mounted) {
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
                    // ( CircleAvatar 保持不变 )
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white.withOpacity(0.1), 
                      backgroundImage: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                          ? NetworkImage(widget.avatarUrl!)
                          : null,
                      child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white70, 
                            )
                          : null,
                    ),
                    // ( _isUploading 逻辑保持不变 )
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
                      // ▼▼▼ 修改点 1：移除这里的 Badge ▼▼▼
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
                      // ▲▲▲ 修改结束 ▲▲▲

                      const SizedBox(height: 8),
                      // ( 电话号码 Row 保持不变 )
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

                // ▼▼▼ 修改点 2：在 Row 的末尾添加新的通知图标 ▼▼▼
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onNotificationTap, // 触发点击回调
                  child: Badge(
                    // 仅当数量 > 0 时才显示角标
                    isLabelVisible: widget.pendingBookingCount > 0, 
                    // 角标显示的内容
                    label: Text(
                      widget.pendingBookingCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: Colors.redAccent,
                    // 始终显示的子图标
                    child: Icon(
                      Icons.notifications_outlined, // 始终显示铃铛图标
                      color: Colors.white.withOpacity(0.9),
                      size: 30,
                    ),
                  ),
                ),
                // ▲▲▲ 修改结束 ▲▲▲
              ],
            ),
          ),
        ),
      ),
    );
  }
}