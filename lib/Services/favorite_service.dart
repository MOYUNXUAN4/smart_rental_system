import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 获取当前用户 ID
  String? get _uid => _auth.currentUser?.uid;

  // 1. 切换收藏状态 (点一下加，再点一下删)
  Future<void> toggleFavorite(String propertyId) async {
    if (_uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(propertyId);

    final doc = await docRef.get();

    if (doc.exists) {
      // 如果已存在，则删除 (取消收藏)
      await docRef.delete();
    } else {
      // 如果不存在，则添加 (收藏)，存入添加时间以便排序
      await docRef.set({
        'addedAt': FieldValue.serverTimestamp(),
        'propertyId': propertyId,
      });
    }
  }

  // 2. 监听某个房源是否被收藏 (用于卡片上的星星状态)
  Stream<bool> isFavoriteStream(String propertyId) {
    if (_uid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(propertyId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // 3. 获取所有收藏的房源 ID 列表 (用于 FavoritesScreen)
  Stream<List<String>> getFavoriteIdsStream() {
    if (_uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true) // 按收藏时间排序
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}