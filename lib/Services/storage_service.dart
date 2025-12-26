// lib/Services/storage_service.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
// 1. 导入压缩和路径相关的库
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ✅ 导入 main.dart 以便使用 ConnectivityHelper
import 'package:smart_rental_system/main.dart'; 

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ----------------------------------------------------
  // 方法 1: 从相册选择一张图片
  // ----------------------------------------------------
  Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    return image;
  }

  // ----------------------------------------------------
  // 方法 2: 完整流程 (已加入网络检查和压缩)
  // ----------------------------------------------------
  Future<String?> uploadAvatarAndGetURL() async {
    // ✅ 新增：在执行任何上传操作前，先检查网络
    // 如果断网，ensureConnection 会自动弹出毛玻璃对话框并返回 false
    if (!await ConnectivityHelper.ensureConnection()) {
      return null; // 直接退出，不执行后续逻辑，防止报错
    }

    try {
      // 步骤 1: 获取 UID
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception("User didn't log in");
      }

      // 步骤 2: 选择图片
      final XFile? image = await pickImage();
      if (image == null) {
        print("user didn't pick any image");
        return null;
      }
      final File originalFile = File(image.path);

      // ---------------------------------
      // 步骤 3: 压缩图片
      // ---------------------------------
      print('-------------------------');
      print('压缩开始...');
      print('原始大小: ${await originalFile.length()} B');

      final tempDir = await getTemporaryDirectory();
      final targetPath =
          p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: 80,
      );

      if (compressedXFile == null) {
        throw Exception("图片压缩失败");
      }

      final File compressedFile = File(compressedXFile.path);

      print('压缩后大小: ${await compressedFile.length()} B');
      print('-------------------------');

      // 步骤 4: 准备上传路径
      final String fileName = '$uid.jpg';
      final Reference ref = _storage.ref().child('user_avatars').child(fileName);

      // 步骤 5: 执行上传 (使用压缩后的文件)
      print("uploading compressed picture...");
      final UploadTask uploadTask = ref.putFile(compressedFile);

      final TaskSnapshot snapshot = await uploadTask;

      // 步骤 6: 获取 URL
      final String downloadURL = await snapshot.ref.getDownloadURL();
      print("Successful! URL: $downloadURL");

      // 步骤 7: 更新 Firestore
      await _firestore.collection('users').doc(uid).update({
        'avatarUrl': downloadURL,
      });

      // 步骤 8: 返回 URL
      return downloadURL;
      
    } catch (e) {
      // ✅ 这里不再 throw error，而是打印并返回 null，
      // 因为 ConnectivityHelper 已经处理了用户侧的弹窗提示
      print("Upload Failed: $e");
      return null;
    }
  }
}