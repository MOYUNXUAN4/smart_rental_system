// 文件位置: lib/Components/panorama_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panorama_viewer/panorama_viewer.dart'; // 必须引用这个包

class PanoramaUploadCard extends StatelessWidget {
  final XFile? selectedFile;      // 用户刚从相册选的图
  final String? existingUrl;      // 编辑模式下，已有的网络图 URL
  final VoidCallback onTap;       // 点击卡片的操作 (去选图)
  final VoidCallback onClear;     // 点击删除按钮的操作

  const PanoramaUploadCard({
    super.key,
    this.selectedFile,
    this.existingUrl,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // 判断当前是否已经有图片 (本地 或者 网络)
    final bool hasImage = selectedFile != null || (existingUrl != null && existingUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 标题栏 ---
        const Row(
          children: [
            Icon(Icons.vrpano, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              '360° Virtual View', 
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            SizedBox(width: 8),
            Text('(Optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),

        // --- 卡片主体 ---
        GestureDetector(
          onTap: onTap, // 点击整个区域都可以选图
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: hasImage ? Colors.cyanAccent.withOpacity(0.5) : Colors.white.withOpacity(0.2),
                width: hasImage ? 1.5 : 1.0,
              ),
            ),
            child: !hasImage
                ? _buildEmptyState()          // 如果没图，显示上传提示
                : _buildPreviewState(context), // 如果有图，显示预览
          ),
        ),
      ],
    );
  }

  // --- 状态 1: 空状态 (提示用户上传) ---
  Widget _buildEmptyState() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: Colors.white54, size: 32),
        SizedBox(height: 8),
        Text(
          'Upload Panorama Photo', 
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)
        ),
        SizedBox(height: 4),
        Text(
          'Tip: Use "Panorama" mode in your camera', 
          style: TextStyle(color: Colors.white30, fontSize: 11)
        ),
      ],
    );
  }

  // --- 状态 2: 预览状态 (显示缩略图 + 按钮) ---
  Widget _buildPreviewState(BuildContext context) {
    // 确定图片来源 (本地文件 还是 网络URL)
    ImageProvider imageProvider;
    if (selectedFile != null) {
      imageProvider = FileImage(File(selectedFile!.path));
    } else {
      imageProvider = NetworkImage(existingUrl!);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层图片 (带圆角)
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image(image: imageProvider, fit: BoxFit.cover),
        ),
        
        // 2. 黑色遮罩 (让图标更清晰)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.black.withOpacity(0.3),
          ),
        ),

        // 3. 中间的大图标
        const Center(
          child: Icon(Icons.threesixty, color: Colors.white, size: 48),
        ),
        // lib/Components/panorama_widget.dart 的第 116 行左右

        // 4. 右下角的预览按钮
        Positioned(
          bottom: 10,
          right: 10,
          child: ElevatedButton.icon(
            onPressed: () => _showFullPanorama(context, imageProvider),
            icon: const Icon(Icons.remove_red_eye, size: 16),
            label: const Text('Preview 360'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 5,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),

        // 5. 右上角的删除按钮
        Positioned(
          top: 5,
          right: 5,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            radius: 16,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: onClear,
            ),
          ),
        )
      ],
    );
  }

  // --- 功能: 弹窗显示全景图 ---
  void _showFullPanorama(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16), // 弹窗边距
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              // 全景查看器
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 500, // 弹窗高度
                  width: double.infinity,
                  child: PanoramaViewer(
                    child: Image(image: imageProvider),
                  ),
                ),
              ),
              // 关闭按钮
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}