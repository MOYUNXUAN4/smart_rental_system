import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ 引入房东签字页面
import '../Screens/landlord_sign_contract_screen.dart';
import 'contract_generator.dart';
import 'glass_card.dart'; 

class LandlordBookingCard extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final String docId; 

  const LandlordBookingCard({
    super.key,
    required this.bookingData,
    required this.docId,
  });

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

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': newStatus, 'isReadByTenant': false, 
    });
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated to $newStatus")));
  }

  // ✅ 完整的生成合同逻辑 (Approve & Contract)
  Future<void> _handleReleaseContract(BuildContext context) async {
    final String propertyId = bookingData['propertyId'];
    final String tenantUid = bookingData['tenantUid'];
    final String? landlordUid = bookingData['landlordUid']; 
    
    final Timestamp? startDateTs = bookingData['leaseStartDate'];
    final Timestamp? endDateTs = bookingData['leaseEndDate'];

    if (startDateTs == null || endDateTs == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Lease dates missing!")));
      return;
    }

    // 显示加载中
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white))
    );

    try {
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

      // 生成初始 PDF
      final File generatedPdf = await ContractGenerator.generateAndSaveContract(
        landlordName: landlordName, 
        tenantName: tenantName, 
        propertyAddress: "${propertyData['unitNumber'] ?? ''}, ${propertyData['communityName'] ?? ''}", 
        rentAmount: (propertyData['price'] ?? 0).toString(),
        startDate: startStr, 
        endDate: endStr, 
        paymentDay: paymentDay, 
        language: 'zh', 
      );

      final String fileName = 'contracts/initial_${docId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(generatedPdf);
      final String newContractUrl = await ref.getDownloadURL(); 

      // 更新状态为 ready_to_sign
      await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': 'ready_to_sign', 
        'contractUrl': newContractUrl, 
        'contractReleasedAt': Timestamp.now(),
        'monthlyPaymentDay': paymentDay, 
        'isReadByTenant': false, 
      });

      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract Sent to Tenant!"), backgroundColor: Color(0xFF1D5DC7)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = bookingData['status'] ?? 'pending';
    final Timestamp meetingTimestamp = bookingData['meetingTime'];
    final String meetingPoint = bookingData['meetingPoint'] ?? '';
    final String formattedTime = DateFormat('MM/dd HH:mm').format(meetingTimestamp.toDate()); 
    final String tenantUid = bookingData['tenantUid'];
    final String propertyId = bookingData['propertyId'];

    // 状态样式逻辑
    Color statusColor = Colors.white70;
    String statusText = status.toUpperCase().replaceAll('_', ' ');
    
    if (status == 'pending') { statusColor = Colors.orangeAccent; }
    else if (status == 'approved') { statusColor = const Color(0xFF69F0AE); } 
    else if (status == 'application_pending') { statusColor = Colors.amber; statusText = "APP PENDING"; }
    else if (status == 'ready_to_sign') { statusColor = Colors.cyanAccent; }
    else if (status == 'tenant_signed') { statusColor = Colors.tealAccent; statusText = "ACTION REQUIRED"; }
    else if (status == 'awaiting_payment') { statusColor = Colors.purpleAccent; } 

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0), 
      child: GlassCard(
        child: Padding(
          // ✅ 极度紧凑内部 Padding
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (房源名 + 状态)
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

              // 2. Info Row (时间 | 租客 | 地点)
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

              // 3. 特殊信息 (租期 / 备注)
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
                     "Note: ${bookingData['applicationNote'] ?? 'No note'}", 
                     style: const TextStyle(color: Colors.white60, fontSize: 9, fontStyle: FontStyle.italic),
                     maxLines: 1, overflow: TextOverflow.ellipsis,
                   ),
                 ),
              ],

              // 4. 操作按钮栏 (Action Bar)
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

              // ✅ 复签按钮 (Landlord Sign)
              if (status == 'tenant_signed') ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 28,
                  child: _buildGradientBtn("Counter Sign & Finalize", const [Color(0xFF00B09B), Color(0xFF96C93D)], () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LandlordSignContractScreen(docId: docId)));
                  }),
                ),
              ],
              
              if (status == 'awaiting_payment') ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text("Waiting for tenant payment...", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontStyle: FontStyle.italic)),
                ),
              ],
            ],
          ),
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
      height: 28, // 极低高度
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