import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 用于打开 WhatsApp
import 'glass_card.dart'; // 👈 重用我们的毛玻璃卡片

class LandlordContactCard extends StatelessWidget {
  final String landlordUid;

  const LandlordContactCard({
    super.key,
    required this.landlordUid,
  });

  // 启动 WhatsApp 的函数
  Future<void> _launchWhatsApp(String phone, BuildContext context) async {
    // 假设电话号码是马来西亚格式，需要 '6' 开头
    String formattedPhone = phone.replaceAll(RegExp(r'\D'), ''); // 移除所有非数字
    if (!formattedPhone.startsWith('6')) {
       formattedPhone = '6$formattedPhone'; // 确保有国家码
    }
    
    final Uri whatsappUrl = Uri.parse('https://wa.me/$formattedPhone');
    
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $whatsappUrl';
      }
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to open WhatsApp: $e')),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 FutureBuilder 自动获取房东信息
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(landlordUid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const GlassCard(
            child: Center(child: Text("Failed to load landlord info", style: TextStyle(color: Colors.white70))),
          );
        }

        // 成功获取数据
        final landlordData = snapshot.data!.data() as Map<String, dynamic>;
        final String name = landlordData['name'] ?? 'Landlord';
        final String phone = landlordData['phone'] ?? '';
        final String? avatarUrl = landlordData['avatarUrl'];

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LANDLORD',
                style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Icon(Icons.person, size: 30, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (phone.isNotEmpty) // 仅在有电话时显示
                          Text(
                            phone,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                  // WhatsApp 按钮
                  if (phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.greenAccent, size: 28),
                      onPressed: () => _launchWhatsApp(phone, context),
                      tooltip: 'Contact via WhatsApp',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}