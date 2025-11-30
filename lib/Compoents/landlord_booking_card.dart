import 'dart:io';
import 'dart:ui'; // ✅ 必须引入，用于 ImageFilter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 引入合同查看器 (用于 View Contract 按钮)
import '../Screens/final_contract_viewer_screen.dart';
// 引入房东签字页面
import '../Screens/landlord_sign_contract_screen.dart';
import 'contract_generator.dart';
import 'glass_card.dart'; 

class LandlordBookingCard extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String docId; 

  const LandlordBookingCard({
    super.key,
    required this.bookingData,
    required this.docId,
  });

  @override
  State<LandlordBookingCard> createState() => _LandlordBookingCardState();
}

class _LandlordBookingCardState extends State<LandlordBookingCard> {

  Future<String> _getTenantName(String tenantUid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
      return doc.exists ? (doc.data()!['name'] ?? 'Unknown Tenant') : 'Unknown Tenant';
    } catch (e) { return '...'; }
  }

  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown Property') : 'Unknown Property';
    } catch (e) { return '...'; }
  }

  // ✅ 通用状态更新 (已修复通知逻辑)
  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
          'status': newStatus,
          // 🔥 通知租客
          'isReadByTenant': false, 
      });
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated to $newStatus")));
    } catch (e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // 🔥 通用毛玻璃确认弹窗
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white70, size: 40),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF5350)]),
                            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(confirmText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 高级毛玻璃横幅构建器
  Widget _buildGlassBanner({
    required BuildContext context,
    required String text,
    required IconData icon,
    required Color color, 
    required VoidCallback onKeep,
    required VoidCallback onConfirm,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 1), 
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2), width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(icon, size: 12, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text, style: TextStyle(color: color.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: onKeep,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text("Keep", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.8), color],
                            begin: Alignment.topLeft, 
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                        ),
                        child: const Text("Confirm", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 修复：生成合同逻辑 (解决无限转圈问题)
  Future<void> _handleReleaseContract(BuildContext context) async {
    final String propertyId = widget.bookingData['propertyId'];
    final String tenantUid = widget.bookingData['tenantUid'];
    final String? landlordUid = widget.bookingData['landlordUid']; 
    
    final Timestamp? startDateTs = widget.bookingData['leaseStartDate'];
    final Timestamp? endDateTs = widget.bookingData['leaseEndDate'];

    if (startDateTs == null || endDateTs == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Lease dates missing!"), backgroundColor: Colors.red));
      return;
    }

    // 1. 显示 Loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white))
    );

    try {
      // 2. 获取数据
      final propertyDoc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      final propertyData = propertyDoc.data() as Map<String, dynamic>;
      
      String landlordName = "Landlord"; 
      if (landlordUid != null) {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(landlordUid).get();
          if (uDoc.exists) landlordName = uDoc.data()?['name'] ?? "Landlord";
      }

      final tenantDoc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
      final String tenantName = tenantDoc.data()?['name'] ?? "Tenant";

      final start = startDateTs.toDate();
      final end = endDateTs.toDate();
      final String startStr = DateFormat('yyyy-MM-dd').format(start);
      final String endStr = DateFormat('yyyy-MM-dd').format(end);
      final String paymentDay = "${start.day}"; 

      // 3. 生成 PDF
      final File generatedPdf = await ContractGenerator.generateAndSaveContract(
        landlordName: landlordName, 
        tenantName: tenantName, 
        propertyAddress: "${propertyData['unitNumber'] ?? ''}, ${propertyData['communityName'] ?? ''}", 
        rentAmount: (propertyData['price'] ?? 0).toString(),
        startDate: startStr, 
        endDate: endStr, 
        paymentDay: paymentDay, 
        language: 'en', // 默认英文
      );

      // 4. 上传
      final String fileName = 'contracts/initial_${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(generatedPdf);
      final String newContractUrl = await ref.getDownloadURL(); 

      // 5. 更新状态 + 通知租客
      await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
        'status': 'ready_to_sign', 
        'contractUrl': newContractUrl, 
        'contractReleasedAt': Timestamp.now(),
        'monthlyPaymentDay': paymentDay, 
        // 🔥🔥 关键：通知租客 🔥🔥
        'isReadByTenant': false, 
      });

      // 6. 成功 -> 关闭 Loading
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract Sent to Tenant!"), backgroundColor: Color(0xFF1D5DC7)),
        );
      }
    } catch (e) {
      // 🛑 失败 -> 关闭 Loading 并显示错误
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        print("Contract Error: $e"); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = widget.bookingData['status'] ?? 'pending';
    final Timestamp meetingTimestamp = widget.bookingData['meetingTime'];
    final String meetingPoint = widget.bookingData['meetingPoint'] ?? '';
    final String formattedTime = DateFormat('MM/dd HH:mm').format(meetingTimestamp.toDate()); 
    final String tenantUid = widget.bookingData['tenantUid'];
    final String propertyId = widget.bookingData['propertyId'];

    // 1. 获取撤销请求信息
    final String? deletionRequest = widget.bookingData['deletionRequest'];
    final String? requestedBy = widget.bookingData['deletionRequestedBy'];

    // 2. 判断横幅显示
    bool showIncomingRequest = (deletionRequest == 'pending' && requestedBy == 'tenant');
    bool showWaitingMessage = (deletionRequest == 'pending' && requestedBy == 'landlord');

    // 状态颜色逻辑
    Color statusColor = Colors.white70;
    String statusText = status.toUpperCase().replaceAll('_', ' ');
    
    if (status == 'pending') { statusColor = Colors.orangeAccent; }
    else if (status == 'approved') { statusColor = const Color(0xFF69F0AE); } 
    else if (status == 'application_pending') { statusColor = Colors.amber; statusText = "APP PENDING"; }
    else if (status == 'ready_to_sign') { statusColor = Colors.cyanAccent; }
    else if (status == 'tenant_signed') { statusColor = Colors.tealAccent; statusText = "ACTION REQUIRED"; }
    else if (status == 'awaiting_payment') { statusColor = const Color(0xFF80DEEA); } 

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0), 
      child: GlassCard(
        child: Column(
          children: [
            
            // ✅ 场景 A: 收到租客撤销请求 (红色横幅)
            if (showIncomingRequest)
              _buildGlassBanner(
                context: context,
                text: "Tenant requested cancel",
                icon: Icons.delete_forever,
                color: const Color(0xFFFF7043), // 醒目的深橙色
                onKeep: () async {
                   await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
                      'deletionRequest': FieldValue.delete(),
                      'deletionRequestedBy': FieldValue.delete(),
                      // 🔥 通知租客“我拒绝了撤销”
                      'isReadByTenant': false,
                   });
                },
                onConfirm: () async {
                   // 🔥 弹出毛玻璃确认框
                   final bool? confirm = await _showConfirmDialog(
                     title: "Approve Deletion?",
                     content: "This will permanently delete this booking for both you and the tenant.",
                     confirmText: "Delete",
                   );
                   // 🔥 二次确认后执行物理删除
                   if (confirm == true) {
                     await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).delete();
                   }
                }
              ),

            // ✅ 场景 B: 等待租客确认 (灰色提示)
            if (showWaitingMessage)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.03),
                   borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                   border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white30)),
                    const SizedBox(width: 8),
                    const Text(
                      "Waiting for tenant confirmation...",
                      style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

            // 卡片主体
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<String>(
                          future: _getPropertyName(propertyId),
                          builder: (context, snapshot) => Text(
                            snapshot.data ?? '...',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withOpacity(0.5), width: 0.5),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),

                  // 2. Info Row
                  Row(
                    children: [
                      _buildIconText(Icons.access_time, formattedTime),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FutureBuilder<String>(
                          future: _getTenantName(tenantUid),
                          builder: (context, snapshot) => _buildIconText(Icons.person, snapshot.data ?? '...'),
                        ),
                      ),
                    ],
                  ),
                  
                  if (meetingPoint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _buildIconText(Icons.location_on, meetingPoint),
                  ],

                  // 3. Application Note
                  if (status == 'application_pending') ...[
                     const SizedBox(height: 4),
                     Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(4),
                       decoration: BoxDecoration(
                         color: Colors.amber.withOpacity(0.05),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         "Note: ${widget.bookingData['applicationNote'] ?? 'No note'}", 
                         style: const TextStyle(color: Colors.white60, fontSize: 9, fontStyle: FontStyle.italic),
                         maxLines: 1, overflow: TextOverflow.ellipsis,
                       ),
                     ),
                  ],

                  // 4. Action Buttons
                  if (status == 'pending') ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _buildOutlineBtn("Reject", Colors.redAccent, () => _updateStatus(context, 'rejected'))),
                        const SizedBox(width: 6),
                        Expanded(child: _buildGradientBtn("Approve", const [Color(0xFF43A047), Color(0xFF66BB6A)], () => _updateStatus(context, 'approved'))),
                      ],
                    ),
                  ],

                  if (status == 'application_pending') ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(flex: 1, child: _buildOutlineBtn("Reject", Colors.redAccent, () => _updateStatus(context, 'rejected'))),
                        const SizedBox(width: 6),
                        Expanded(flex: 2, child: _buildGradientBtn("Approve Contract", const [Color(0xFF1D5DC7), Color(0xFF42A5F5)], () => _handleReleaseContract(context))),
                      ],
                    ),
                  ],

                  if (status == 'tenant_signed') ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: _buildGradientBtn("Counter Sign & Finalize", const [Color(0xFF00B09B), Color(0xFF96C93D)], () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => LandlordSignContractScreen(docId: widget.docId)));
                      }),
                    ),
                  ],
                  
                  if (status == 'awaiting_payment') ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: OutlinedButton(
                              onPressed: () {
                                 Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FinalContractViewerScreen(
                                      contractUrlZh: widget.bookingData['contractUrlZh'],
                                      contractUrlEn: widget.bookingData['contractUrlEn'],
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.5), width: 0.5),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text("View Contract", style: TextStyle(fontSize: 10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08), 
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_top, size: 10, color: Colors.white.withOpacity(0.4)),
                                const SizedBox(width: 4),
                                Text(
                                  "Waiting Payment", 
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w500)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 辅助组件 ---
  Widget _buildIconText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.white54),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildOutlineBtn(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 28, 
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5), width: 0.5),
          foregroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 10)),
      ),
    );
  }

  Widget _buildGradientBtn(String text, List<Color> colors, VoidCallback onTap) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(colors: colors),
        boxShadow: [BoxShadow(color: colors.last.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Center(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}