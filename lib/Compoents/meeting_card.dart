// 在 lib/Compoents/ 目录下
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart';

class NextMeetingCard extends StatelessWidget {
  // 接收完整的预约文档
  final QueryDocumentSnapshot bookingDoc;

  const NextMeetingCard({super.key, required this.bookingDoc});

  // 辅助方法：根据 ID 获取租客名称
  Future<String> _getTenantName(String tenantUid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
      return doc.exists ? (doc.data()!['name'] ?? 'Unknown Tenant') : 'Unknown Tenant';
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = bookingDoc.data() as Map<String, dynamic>;
    final String tenantUid = data['tenantUid'];
    final String meetingPoint = data['meetingPoint']; // 这就是 Location
    final Timestamp meetingTimestamp = data['meetingTime'];
    
    // 格式化日期和时间
    final String formattedDate = DateFormat('EEE, MMM d').format(meetingTimestamp.toDate()); // "Fri, Nov 7"
    final String formattedTime = DateFormat('hh:mm a').format(meetingTimestamp.toDate()); // "02:30 PM"

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      
      // ▼▼▼ 【UI 优化】: 添加一个带边框和光晕的 Container ▼▼▼
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // 必须和 GlassCard 的圆角一致
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.7), // 明亮的边框
            width: 1.5,
          ),
          boxShadow: [ // 添加一层微妙的光晕
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: GlassCard( // 👈 你的原始卡片现在被包裹在里面
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Next Viewing Appointment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Divider(color: Colors.white30, height: 16),
              
              // Meeting User (使用 FutureBuilder)
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  const Text("Meeting User: ", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  FutureBuilder<String>(
                    future: _getTenantName(tenantUid),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Loading...',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Meeting Time
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  const Text("Meeting Time: ", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text(
                    "$formattedDate at $formattedTime",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Meeting Location
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  const Text("Location: ", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Expanded(
                    child: Text(
                      meetingPoint,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      // ▲▲▲ 【UI 优化结束】 ▲▲▲
    );
  }
}