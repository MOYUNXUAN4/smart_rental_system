// 在 lib/Compoents/ 目录下创建新文件 inbox_message_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart';

class InboxMessageCard extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const InboxMessageCard({super.key, required this.bookingData});

  @override
  State<InboxMessageCard> createState() => _InboxMessageCardState();
}

class _InboxMessageCardState extends State<InboxMessageCard> {
  // ▼▼▼ 【新】: 控制卡片是否展开 ▼▼▼
  bool _isExpanded = false;
  // ▲▲▲ 【新】 ▲▲▲

  // 辅助方法：根据 ID 获取名称
  Future<String> _getDocName(String collection, String docId, String fieldName) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
      return doc.exists ? (doc.data()![fieldName] ?? 'Unknown') : 'Error';
    } catch (e) {
      return 'Error';
    }
  }

  // 辅助方法：获取状态
  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.redAccent;
      case 'pending': return Colors.orangeAccent;
      default: return Colors.white70;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'pending': return Icons.hourglass_top;
      default: return Icons.info;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final String tenantUid = widget.bookingData['tenantUid'];
    // final String propertyId = widget.bookingData['propertyId']; // 不再需要
    final Timestamp meetingTimestamp = widget.bookingData['meetingTime'];
    final String meetingPoint = widget.bookingData['meetingPoint']; // Location
    final String status = widget.bookingData['status'] ?? 'unknown';
    final String formattedTime = DateFormat('dd/MM/yyyy, hh:mm a').format(meetingTimestamp.toDate());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        child: Column(
          children: [
            // 顶部：点击区域
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded; // 切换展开状态
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0), // 缩小顶部内边距
                child: Row(
                  children: [
                    // 状态图标
                    Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 28),
                    const SizedBox(width: 12),
                    
                    // 中间信息 (User, Time, Location)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. User
                          FutureBuilder<String>(
                            future: _getDocName('users', tenantUid, 'name'),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? 'Loading...',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          // 2. Time
                          Text(
                            formattedTime,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 折叠符号
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            
            // ▼▼▼ 【新】: 可折叠的动画区域 ▼▼▼
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: Container(
                // 仅在 _isExpanded 为 true 时才显示内容
                height: _isExpanded ? null : 0, 
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Colors.white30, height: 16),
                      // 3. Location (在折叠区域中)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              meetingPoint,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      // 你未来可以在这里添加更多详情...
                    ],
                  ),
                ),
              ),
            )
            // ▲▲▲ 【新】 ▲▲▲
          ],
        ),
      ),
    );
  }
}