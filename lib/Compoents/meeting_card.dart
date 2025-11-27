import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 需要引入 Auth
import 'package:intl/intl.dart';
import 'glass_card.dart';

class NextMeetingCard extends StatelessWidget {
  // 使用 DocumentSnapshot 以便兼容 QueryDocumentSnapshot
  final DocumentSnapshot bookingDoc;

  const NextMeetingCard({super.key, required this.bookingDoc});

  // ✅ 智能获取“对方”的名字
  Future<String> _getCounterpartyName(Map<String, dynamic> data) async {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String tenantUid = data['tenantUid'];
    final String landlordUid = data['landlordUid'];

    String targetUid;
    
    // 如果我是租客，我要查房东的名字
    if (currentUid == tenantUid) {
      targetUid = landlordUid; 
    } 
    // 否则（我是房东），我要查租客的名字
    else {
      targetUid = tenantUid;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
      if (doc.exists) {
        // 假设 users 集合里有 'name' 字段
        return doc.data()!['name'] ?? 'Unknown User';
      }
      return 'Unknown User';
    } catch (e) {
      return 'Error';
    }
  }

  // ✅ 获取房产名称
  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown Property') : 'Unknown Property';
    } catch (e) {
      return 'Property Info Unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = bookingDoc.data() as Map<String, dynamic>;
    final Timestamp meetingTime = data['meetingTime'];
    final String meetingPoint = data['meetingPoint'] ?? 'No location';
    final String propertyId = data['propertyId'];
    
    // 时间格式化
    final DateTime date = meetingTime.toDate();
    final String day = DateFormat('d').format(date);      // e.g., "12"
    final String month = DateFormat('MMM').format(date);  // e.g., "NOV"
    final String time = DateFormat('h:mm a').format(date);// e.g., "2:30 PM"

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      
      // 外层容器：负责发光边框
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.4), // 半透明白边
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64B5F6).withOpacity(0.2), // 淡淡的蓝色光晕
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: GlassCard(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            // 内部微渐变，增加质感
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // --- 左侧：日历样式日期 ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Column(
                    children: [
                      Text(
                        day, 
                        style: const TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          height: 1.0,
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(
                        month.toUpperCase(), 
                        style: const TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.white70,
                          letterSpacing: 1.2
                        )
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // --- 右侧：详情信息 ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 顶部小标签
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "UPCOMING", 
                            style: TextStyle(
                              color: Colors.greenAccent, 
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              letterSpacing: 1.0
                            )
                          ),
                          // 显示具体时间
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text(
                              time,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // 2. 房产名称 (主标题)
                      FutureBuilder<String>(
                        future: _getPropertyName(propertyId),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Loading...',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.bold
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // 3. 对方名字 (User)
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FutureBuilder<String>(
                              future: _getCounterpartyName(data),
                              builder: (context, snapshot) {
                                return Text(
                                  "Meet: ${snapshot.data ?? '...'}", 
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // 4. 地点
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              meetingPoint, 
                              style: const TextStyle(color: Colors.white70, fontSize: 13), 
                              overflow: TextOverflow.ellipsis
                            )
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}