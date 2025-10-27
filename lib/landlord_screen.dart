// lib/landlord_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 1. 不再需要 StorageService
// import 'storage_service.dart'; 

// 2. 导入我们的头像上传页
import 'profile_page.dart'; 

class LandlordScreen extends StatefulWidget {
  const LandlordScreen({Key? key}) : super(key: key);

  @override
  State<LandlordScreen> createState() => _LandlordScreenState();
}

class _LandlordScreenState extends State<LandlordScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  
  // 3. 不再需要 StorageService 实例
  // final StorageService _storageService = StorageService(); 

  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid!).snapshots();
    } else {
      _userStream = Stream.error("User not logged in");
    }
  }

  // 4. 【关键修改】
  //   修改这个函数，让它只负责导航
  void _onAvatarTapped() {
    // 跳转到 ProfilePage
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Landlord Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      // 你的 StreamBuilder 写得非常好，完全不需要改动
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Error loading user data") );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? 'Unknown Name';
          final String phone = userData['phone'] ?? 'No Phone';
          final String? avatarUrl = userData.containsKey('avatarUrl') 
                                    ? userData['avatarUrl'] 
                                    : null;

          return Column(
            children: [
              Card(
                elevation: 4.0,
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // 5. 这个 GestureDetector 现在会触发导航
                      GestureDetector(
                        onTap: _onAvatarTapped, // 👈 逻辑已更新
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Icon(
                                  Icons.camera_alt,
                                  size: 30,
                                  color: Colors.grey.shade600,
                                )
                              : null,
                        ),
                      ),
                      
                      const SizedBox(width: 20),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(phone, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: Center(
                  child: Text(
                    'you have no properties yet.\nTap the + button to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 跳转到添加房源页面
        },
        child: Icon(Icons.add_home_work),
        tooltip: 'Add Property',
      ),
    );
  }
}