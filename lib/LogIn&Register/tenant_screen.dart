import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Compoents/user_info_card.dart'; // 👈 导入卡片

class TenantScreen extends StatefulWidget {
  const TenantScreen({super.key});

  @override
  State<TenantScreen> createState() => _TenantScreenState();
}

class _TenantScreenState extends State<TenantScreen> {
  // 1. 【更改】把 'Future' 换成 'Stream'
  late Stream<DocumentSnapshot> _userStream; 
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      // 2. 【更改】从 .get() (获取一次) 换成 .snapshots() (持续监听)
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    } else {
      // 3. 【更改】Stream 的错误处理
      _userStream = Stream.error("User not logged in");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      // 4. 【更改】把 'FutureBuilder' 换成 'StreamBuilder'
      body: StreamBuilder<DocumentSnapshot>(
        // 5. 【更改】使用 _userStream
        stream: _userStream, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Error: Could not load user data."));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? 'No Name';
          final String phone = userData['phone'] ?? 'No Phone';
          
          // 6. 【新增】从数据库中提取 'avatarUrl'
          //    注意：我们使用 '??' 提供一个 null 默认值，以防字段不存在
          final String? avatarUrl = userData['avatarUrl'];

          return Column(
            children: [
              // 7. 【关键】把 avatarUrl 传递给 UserInfoCard
              UserInfoCard(
                name: name,
                phone: phone,
                avatarUrl: avatarUrl, // 👈 传递 URL
              ),
              
              // ... (剩余部分不变) ...
              const Expanded(
                child: Center(
                  child: Text(
                    'You have no rented properties yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}