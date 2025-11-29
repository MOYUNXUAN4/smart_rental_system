import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'glass_card.dart'; // 确保此文件存在

class BookingNotificationCard extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool showActions; // 控制是否显示操作按钮

  const BookingNotificationCard({
    super.key,
    required this.bookingData,
    this.onApprove,
    this.onReject,
    this.showActions = false,
  });

  // 辅助：获取名称
  Future<String> _getDocName(String collection, String docId, String fieldName) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
      return doc.exists ? (doc.data()![fieldName] ?? 'Unknown') : '...';
    } catch (e) { return '...'; }
  }

  @override
  Widget build(BuildContext context) {
    final String tenantUid = bookingData['tenantUid'];
    final String propertyId = bookingData['propertyId'];
    final Timestamp meetingTimestamp = bookingData['meetingTime'];
    final String meetingPoint = bookingData['meetingPoint'];
    final String status = bookingData['status'] ?? 'unknown';
    final String formattedTime = DateFormat('MM/dd HH:mm').format(meetingTimestamp.toDate());

    // 🎨 状态颜色逻辑 (保持统一的高级感配色)
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info_outline;
    
    switch (status) {
      case 'pending':
        statusColor = Colors.orangeAccent; statusIcon = Icons.hourglass_top; break;
      case 'approved':
        statusColor = const Color(0xFF69F0AE); statusIcon = Icons.check_circle; break; // 清新绿
      case 'rejected':
        statusColor = Colors.redAccent; statusIcon = Icons.cancel; break;
      case 'application_pending':
        statusColor = Colors.amber; statusIcon = Icons.assignment; break;
      case 'ready_to_sign':
        statusColor = Colors.cyanAccent; statusIcon = Icons.edit_document; break;
      case 'tenant_signed':
        statusColor = Colors.tealAccent; statusIcon = Icons.edit; break;
      case 'awaiting_payment':
        statusColor = const Color(0xFF00BFA5); statusIcon = Icons.verified_user; break;
    }

    return Padding(
      // 外部间距极小
      padding: const EdgeInsets.only(bottom: 8.0), 
      child: GlassCard(
        child: Padding(
          // ✅✅✅ 内部极低 Padding，紧凑布局 ✅✅✅
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 顶部 Header (房产名 + 状态)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 房产名称
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _getDocName('properties', propertyId, 'communityName'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? '...',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 状态胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.5), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 6),

              // 2. 信息详情行 (时间 | 地点 | 租客)
              Row(
                children: [
                  // 时间
                  Icon(Icons.access_time, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(formattedTime, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  
                  const SizedBox(width: 12),
                  
                  // 租客名
                  Icon(Icons.person_outline, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _getDocName('users', tenantUid, 'name'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? '...',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // 地点单独一行，防止太长
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      meetingPoint,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // 3. 操作按钮区 (仅当 showActions=true 时显示)
              if (showActions) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    // 拒绝按钮 (Outline Red)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 28, // 极低高度
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1),
                            foregroundColor: Colors.redAccent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Reject', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // 批准按钮 (Gradient Green)
                    Expanded(
                      flex: 2, // 批准按钮宽一点，作为主要操作
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF43A047), Color(0xFF66BB6A)], // 清新自然绿
                          ),
                          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onApprove,
                            child: const Center(
                              child: Text("Approve Request", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}