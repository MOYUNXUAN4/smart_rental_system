import 'package:flutter/material.dart';
import '../Services/storage_service.dart'; // 👈 1. 导入你的 StorageService

// 2. 将 'StatelessWidget' 转换为 'StatefulWidget'
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

// 3. 创建对应的 'State' 类
class _UserInfoCardState extends State<UserInfoCard> {
  // 4. 实例化你的 Service
  final StorageService _storageService = StorageService();
  
  // 5. 创建一个状态来跟踪上传进度
  bool _isUploading = false;

  // 6. 创建一个函数来处理“选择并上传”
  Future<void> _pickAndUploadAvatar() async {
    // 6.1 开始上传，更新UI
    setState(() {
      _isUploading = true;
    });

    try {
      // 6.2 调用 Service
      // Service 内部会处理：选图、压缩、上传、更新Firestore
      await _storageService.uploadAvatarAndGetURL();
      
      // 注意：我们不需要在这里手动更新 URL，
      // 因为下一步 StreamBuilder 会自动监听到 Firestore 的变化并刷新 UI！

    } catch (e) {
      // 6.3 处理错误
      print("上传失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload Failed: $e")),
        );
      }
    } finally {
      // 6.4 无论成功与否，都结束上传状态
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 7. 【重要】使用 Stack 来叠加“头像”和“上传按钮”
            Stack(
              alignment: Alignment.bottomRight, // 让按钮在右下角
              children: [
                // 7.1 这是你的头像
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey.shade300,
                  // 7.2 智能显示头像：
                  // 如果 avatarUrl 存在，就显示网络图片
                  backgroundImage: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                      ? NetworkImage(widget.avatarUrl!)
                      : null,
                  // 如果 avatarUrl 不存在，就显示默认图标
                  child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey.shade600,
                        )
                      : null, // 有头像时，child 必须为 null
                ),

                // 7.3 这是“加载”或“上传”按钮
                _isUploading
                    // 7.4 如果正在上传，显示加载圈
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    // 7.5 如果未上传，显示“编辑”按钮
                    : GestureDetector(
                        onTap: _pickAndUploadAvatar, // 👈 绑定上传函数
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ],
            ),

            const SizedBox(width: 20), // 中间间距

            // 8. 右侧：姓名和电话 (这部分你的代码不用变)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        widget.phone,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
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
    );
  }
}