// lib/storage_service.dart

import 'dart:io'; // 用于 File
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ----------------------------------------------------
  // 方法 1: 从相册选择一张图片
  // ----------------------------------------------------
  Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // 从相册 (gallery) 选择图片
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    return image;
  }

  // ----------------------------------------------------
  // 方法 2: 完整流程 - 选择、上传、更新数据库
  // ----------------------------------------------------
  Future<String?> uploadAvatarAndGetURL() async {
    try {
      // 步骤 1: 获取当前登录用户的 UID
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception("用户未登录");
      }

      // 步骤 2: 让用户从相册选择图片
      final XFile? image = await pickImage();
      if (image == null) {
        print("未选择图片");
        return null; // 用户取消了选择
      }

      // 步骤 3: 准备上传
      // 3.1 将 XFile 转换为 Dart 的 File
      final File file = File(image.path); 
      // 3.2 创建一个在 Firebase Storage 上的唯一文件路径
      // 我们把所有头像统一放到 'user_avatars/' 文件夹下
      // 并用用户的 UID 作为文件名，这样每个用户最多只有一个头像，方便覆盖更新
      final String fileName = '$uid.jpg'; 
      final Reference ref = _storage.ref().child('user_avatars').child(fileName);

      // 步骤 4: 执行上传
      print("正在上传图片...");
      final UploadTask uploadTask = ref.putFile(file);
      
      // 等待上传完成
      final TaskSnapshot snapshot = await uploadTask;

      // 步骤 5: 获取上传后的图片下载 URL
      final String downloadURL = await snapshot.ref.getDownloadURL();
      print("上传成功! URL: $downloadURL");

      // 步骤 6: (最关键!) 将这个 URL 更新到用户的 Firestore 文档中
      // 这样 App 里的其他地方才能读取到这个头像
      await _firestore.collection('users').doc(uid).update({
        'avatarUrl': downloadURL, // 我们在 'users' 文档中添加/更新 'avatarUrl' 字段
      });

      // 步骤 7: 将 URL 返回，以便 UI 可以立即使用
      return downloadURL;

    } catch (e) {
      print("上传头像失败: $e");
      return null;
    }
  }
}