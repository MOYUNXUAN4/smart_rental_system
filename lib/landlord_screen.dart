import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. 导入我们新创建的服务
import 'storage_service.dart';

class LandlordScreen extends StatefulWidget {
  const LandlordScreen({Key? key}) : super(key: key);

  @override
  State<LandlordScreen> createState() => _LandlordScreenState();
}

class _LandlordScreenState extends State<LandlordScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final StorageService _storageService = StorageService(); // 2. 创建服务实例

  // 3. 我们不再用 Future，而是用 Stream 来实时监听
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      // 监听 'users' 集合中，当前用户ID的文档的 *快照* (snapshots)
      _userStream = FirebaseFirestore.instance.collection('users').doc(_uid!).snapshots();
    } else {
      // 理论上不会发生，因为 AuthGate 已经处理了
      _userStream = Stream.error("User not logged in");
    }
  }

  // 4. 头像上传的触发函数
  void _onAvatarTapped() async {
    // 显示加载中的转圈动画
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    // 调用服务执行选择、上传和数据库更新
    final String? newAvatarUrl = await _storageService.uploadAvatarAndGetURL();
    
    // 不管成功与否，上传完成后，关闭转圈动画
    if (mounted) {
      Navigator.of(context).pop(); 
    }
    
    if (newAvatarUrl == null && mounted) {
      // 如果上传失败或取消，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("头像上传失败或已取消")),
      );
    }
    // 如果上传成功，StreamBuilder 会自动监听到 'avatarUrl' 字段的变化并刷新UI
    // 我们不需要手动调用 setState
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
      // 5. 使用 StreamBuilder 实时监听数据
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          
          // 正在加载
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // 加载出错
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("错误：无法加载用户信息"));
          }

          // 6. 加载成功, 解析数据
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? '无姓名';
          final String phone = userData['phone'] ?? '无电话';
          
          // 7. 动态获取 avatarUrl (用 .containsKey 检查字段是否存在，避免出错)
          final String? avatarUrl = userData.containsKey('avatarUrl') 
                                    ? userData['avatarUrl'] 
                                    : null;

          return Column(
            children: [
              // 8. 构建我们自己的卡片 (不再需要 user_info_card.dart)
              Card(
                elevation: 4.0,
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // 9. 可点击的头像
                      GestureDetector(
                        onTap: _onAvatarTapped, // 点击时触发上传
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade300,
                          // 10. 检查 avatarUrl 是否存在
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl) // 如果存在，显示网络图片
                              : null,
                          child: avatarUrl == null
                              ? Icon( // 如果不存在，显示"添加"图标
                                  Icons.camera_alt,
                                  size: 30,
                                  color: Colors.grey.shade600,
                                )
                              : null,
                        ),
                      ),
                      
                      const SizedBox(width: 20),

                      // 右侧信息 (姓名和电话)
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
              
              // 您的房源列表 (目前为空)
              Expanded(
                child: Center(
                  child: Text(
                    '您还没有房源\n点击下方按钮添加',
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