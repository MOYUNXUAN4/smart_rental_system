// lib/storage_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// 1. 导入压缩和路径相关的库
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  // 注意：这里是普通的空格
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
  // 方法 2: 完整流程 (已加入压缩)
  // ----------------------------------------------------
  Future<String?> uploadAvatarAndGetURL() async {
    try {
      // 步骤 1: 获取 UID (不变)
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception("User didn't log in");
      }

      // 步骤 2: 选择图片 (不变)
      final XFile? image = await pickImage();
      if (image == null) {
        print("user didn't pick any image");
        return null;
      }
      final File originalFile = File(image.path); // 这是原始文件

      // ---------------------------------
      // 步骤 3: 【新增】压缩图片
      // ---------------------------------
      print('-------------------------');
      print('压缩开始...');
      print('原始大小: ${await originalFile.length()} B');

      // 3.1 获取一个临时目录来存放压缩后的文件
      final tempDir = await getTemporaryDirectory();
      // 3.2 定义压缩后的文件路径
      final targetPath =
          p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

      // 3.3 执行压缩
      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path, // 原始路径
        targetPath, // 目标路径
        quality: 80, // 压缩质量 (0-100)，80 是个不错的起点
      );

      if (compressedXFile == null) {
        throw Exception("图片压缩失败");
      }

      // 3.4 【关键】获取压缩后的 File 对象
      final File compressedFile = File(compressedXFile.path);

      print('压缩后大小: ${await compressedFile.length()} B');
      print('压缩成功! 路径: ${compressedFile.path}');
      print('-------------------------');

      // 步骤 4: 准备上传 (路径不变)
      final String fileName = '$uid.jpg';
      final Reference ref = _storage.ref().child('user_avatars').child(fileName);

      // 步骤 5: 执行上传 【注意：这里用的是 compressedFile】
      print("uploading compressed picture...");
      final UploadTask uploadTask = ref.putFile(compressedFile); // 👈 使用压缩后的文件

      final TaskSnapshot snapshot = await uploadTask;

      // 步骤 6: 获取 URL (不变)
      final String downloadURL = await snapshot.ref.getDownloadURL();
      print("Sucessful! URL: $downloadURL");

      // 步骤 7: 更新 Firestore (不变)
      await _firestore.collection('users').doc(uid).update({
        'avatarUrl': downloadURL,
      });

      // 步骤 8: 返回 URL (不变)
      return downloadURL;
      
    } catch (e) {
      print("Upload Failed $e");
      return null;
    }
  }
}