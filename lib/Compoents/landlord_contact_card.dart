import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 确保您已添加此依赖
import 'glass_card.dart'; // 导入毛玻璃卡片

// 导入登录页面 (请确保路径正确)
import 'package:smart_rental_system/Screens/login_screen.dart';

class LandlordContactCard extends StatelessWidget {
  final String landlordUid;
  final String? currentUserId; 

  const LandlordContactCard({
    super.key,
    required this.landlordUid,
    required this.currentUserId, 
  });

  // (拨打电话函数保持不变)
  Future<void> _launchPhone(String phoneNumber, BuildContext context) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $phoneNumber')),
      );
    }
  }
  
  // (WhatsApp 跳转逻辑保持不变)
  Future<void> _launchWhatsApp(String phone, BuildContext context) async {
    // 移除 +、- 和空格
    String normalizedPhone = phone.replaceAll(RegExp(r'[\s-]+'), '');
    
    // 假设是马来西亚号码, 替换开头的 0
    if (normalizedPhone.startsWith('0')) {
      normalizedPhone = '60${normalizedPhone.substring(1)}';
    }
    // (如果需要，添加更多国家代码逻辑)
    
    final Uri url = Uri.parse("https://wa.me/$normalizedPhone");

    try {
      if (await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication)) {
        // 成功打开
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp. Is it installed?')),
        );
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    
    // (未登录时的 UI 保持不变)
    if (currentUserId == null) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Landlord Contact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.login, color: Colors.white70),
                label: const Text(
                  'Login to view contact', 
                  style: TextStyle(color: Colors.white70),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }
    
    // (已登录时的 StreamBuilder 逻辑保持不变)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(landlordUid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const GlassCard(child: Center(child: Text('Could not load landlord info.', style: TextStyle(color: Colors.white70))));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String name = data['name'] ?? 'Landlord';
        final String? phone = data['phone'];
        final String? avatarUrl = data['avatarUrl'];

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Landlord Contact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // ✅ 1. 【布局修改】: 减小间距
              const SizedBox(height: 16), 
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  // --- 左侧：头像和名字 ---
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        // ✅ 2. 头像更大
                        radius: 30, 
                        backgroundColor: Colors.white.withOpacity(0.1),
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? const Icon(Icons.person, color: Colors.white70, size: 30) // ✅ 图标更大
                            : null,
                      ),
                      // ✅ 2. 名字更大
                      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      // ✅ 3. 显示电话
                      subtitle: Text(
                        phone ?? 'No phone number',
                        style: const TextStyle(color: Colors.white70, fontSize: 14)
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12), // 间隔

                  // --- ✅ 4. 【布局修改】: 按钮水平排练且靠近 ---
                  Row(
                    mainAxisSize: MainAxisSize.min, // 占用最小空间
                    children: [
                      // Call Button
                      Material(
                        color: Colors.white.withOpacity(0.2),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          onPressed: (phone != null && phone.isNotEmpty) ? () => _launchPhone(phone, context) : null,
                          icon: const Icon(Icons.call_outlined, size: 22, color: Colors.white),
                          tooltip: 'Call',
                        ),
                      ),
                      const SizedBox(width: 8), // 按钮之间的间距
                      // WhatsApp Button
                      Material(
                        color: Colors.white.withOpacity(0.2),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          onPressed: (phone != null && phone.isNotEmpty) ? () => _launchWhatsApp(phone, context) : null,
                          icon: const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.white),
                          tooltip: 'WhatsApp',
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}