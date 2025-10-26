import 'package:flutter/material.dart';
class UserInfoCard extends StatelessWidget {
  final String name;
  final String phone;
  final String? avatarUrl; // 设为可选，以便未来使用

  const UserInfoCard({
    super.key,
    required this.name,
    required this.phone,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 左侧：圆形头像
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.grey.shade300,
              // TODO: 稍后我们将用 NetworkImage(avatarUrl) 替换
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(width: 20), // 中间间距

            // 右侧：姓名和电话
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
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
                        phone,
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