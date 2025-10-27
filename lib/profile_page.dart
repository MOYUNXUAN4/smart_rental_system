// lib/profile_page.dart
// [已恢复：包含完整的上传和压缩功能]

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;
  // 获取当前用户ID (我们知道用户已登录，所以用 ! 断言)
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // --- 这是完整的上传功能 ---
  Future<void> _pickAndUploadImage() async {
    setState(() { _isLoading = true; });

    try {
      // --- 第 1 步：选择图片 ---
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        setState(() { _isLoading = false; });
        return; // 用户取消了选择
      }
      File originalFile = File(pickedFile.path);

      // --- 第 2 步：压缩图片 ---
      final File compressedFile = await _compressImage(originalFile);

      // --- 第 3 步：上传到 Firebase Storage ---
      final String downloadUrl = await _uploadToStorage(compressedFile);

      // --- 第 4 步：将 URL 保存到 Firestore ---
      await _saveUrlToFirestore(downloadUrl);

      // --- 第 5 步：成功后提示并返回 ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传成功!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // 自动返回上一页
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- 辅助函数：压缩 (包含日志) ---
  Future<File> _compressImage(File file) async {
    final dir = await Directory.systemTemp;
    final targetPath = '${dir.absolute.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final originalLength = await file.length();
    print("-------------------------");
    print("压缩开始...");
    print("原始大小: $originalLength B");

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85, // 压缩质量
      minWidth: 800, // 最小宽度
      minHeight: 800, // 最小高度
    );

    if (result == null) throw Exception('压缩失败');
    
    final compressedFile = File(result.path);
    final compressedLength = await compressedFile.length();

    print("压缩后大小: $compressedLength B");
    print("压缩成功! 路径: ${compressedFile.path}");
    print("-------------------------");
    
    return compressedFile;
  }

  // --- 辅助函数：上传 ---
  Future<String> _uploadToStorage(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    // 此时 user 肯定不为 null，但我们还是安全检查一下
    if (user == null) throw Exception('未登录，无法上传');
    
    final String userId = user.uid;
    final String filePath = 'user_avatars/$userId/avatar.jpg';

    final ref = FirebaseStorage.instance.ref(filePath);
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  // --- 辅助函数：保存 URL 到 Firestore ---
  Future<void> _saveUrlToFirestore(String url) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('未登录，无法保存URL');

    await FirebaseFirestore.instance
        .collection('users') 
        .doc(user.uid)        
        .set({ // 使用 .set 并合并
          'avatarUrl': url,
        }, SetOptions(merge: true)); // merge: true 会保留文档中的其他字段
  }

  // --- 完整的 Build 方法 (实时显示当前头像) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('上传头像')),
      // 使用 StreamBuilder 实时显示当前数据库中的头像
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_userId).snapshots(),
        builder: (context, snapshot) {
          
          String? currentAvatarUrl;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            currentAvatarUrl = data?['avatarUrl']; // 安全地获取 URL
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 显示当前的网络头像
                CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (currentAvatarUrl != null)
                      ? NetworkImage(currentAvatarUrl)
                      : null,
                  child: (currentAvatarUrl == null && !_isLoading)
                      ? Icon(Icons.person, size: 80, color: Colors.grey)
                      : null,
                ),
                SizedBox(height: 30),

                // 上传按钮
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton.icon(
                        icon: Icon(Icons.upload),
                        label: Text('选择并上传新头像'),
                        onPressed: _pickAndUploadImage,
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}